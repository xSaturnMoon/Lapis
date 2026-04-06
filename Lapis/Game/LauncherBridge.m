#import "LauncherBridge.h"
#import <dlfcn.h>
#import <UIKit/UIKit.h>

// ─────────────────────────────────────────────
// JNI / JLI type definitions (no SDK headers needed)
// ─────────────────────────────────────────────
typedef int           jint;
typedef unsigned char jboolean;
typedef void*         jobject;
typedef void*         jclass;
typedef void*         jmethodID;
typedef void*         jobjectArray;
typedef void*         jstring;

#define JNI_TRUE  1
#define JNI_FALSE 0
#define JNI_VERSION_1_8 0x00010008
#define JNI_OK 0

typedef struct {
    char *optionString;
    void *extraInfo;
} JavaVMOption;

typedef struct {
    jint         version;
    jint         nOptions;
    JavaVMOption *options;
    jboolean     ignoreUnrecognized;
} JavaVMInitArgs;

typedef void* JavaVM;
typedef void* JNIEnv;

typedef jint (*JNI_CreateJavaVM_t)(JavaVM**, void**, void*);

// ─────────────────────────────────────────────
// JNI function table slot indices (JNI spec, 0-based)
// ─────────────────────────────────────────────
#define SLOT_FindClass               6
#define SLOT_ExceptionDescribe       30
#define SLOT_NewStringUTF            167
#define SLOT_NewObjectArray          172
#define SLOT_SetObjectArrayElement   179
#define SLOT_GetStaticMethodID       113
#define SLOT_CallStaticVoidMethodA   141
#define SLOT_ExceptionCheck          228

// Extract a function pointer from the JNIEnv vtable by slot index.
// JNIEnv is void** (pointer to array of void*).
static void* jniSlot(JNIEnv env, int index) {
    void **table = *(void***)env;
    return table[index];
}

typedef jclass        (*FindClass_t)              (JNIEnv, const char*);
typedef void          (*ExceptionDescribe_t)       (JNIEnv);
typedef jboolean      (*ExceptionCheck_t)          (JNIEnv);
typedef jstring       (*NewStringUTF_t)            (JNIEnv, const char*);
typedef jobjectArray  (*NewObjectArray_t)           (JNIEnv, jint, jclass, jobject);
typedef void          (*SetObjectArrayElement_t)   (JNIEnv, jobjectArray, jint, jobject);
typedef jmethodID     (*GetStaticMethodID_t)       (JNIEnv, jclass, const char*, const char*);
typedef void          (*CallStaticVoidMethodA_t)   (JNIEnv, jclass, jmethodID, void*);

// jvalue union (8 bytes per JNI spec)
typedef union { jobject l; jint i; } jvalue;

// ─────────────────────────────────────────────
// Logging
// ─────────────────────────────────────────────
static NSString *launchLogPath = nil;

static void appendLog(NSString *message) {
    if (!launchLogPath) {
        NSString *docs = [NSSearchPathForDirectoriesInDomains(
            NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        launchLogPath = [docs stringByAppendingPathComponent:@"Lapis/launch.log"];
    }
    [[NSFileManager defaultManager]
        createDirectoryAtPath:[launchLogPath stringByDeletingLastPathComponent]
        withIntermediateDirectories:YES attributes:nil error:nil];

    NSString *ts = [NSDateFormatter
        localizedStringFromDate:[NSDate date]
        dateStyle:NSDateFormatterNoStyle
        timeStyle:NSDateFormatterMediumStyle];
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", ts, message];

    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:launchLogPath];
    if (fh) {
        [fh seekToEndOfFile];
        [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [fh closeFile];
    } else {
        [line writeToFile:launchLogPath atomically:YES
               encoding:NSUTF8StringEncoding error:nil];
    }
    NSLog(@"[LauncherBridge] %@", message);
}

// ─────────────────────────────────────────────
@implementation LauncherBridge

+ (void)launchWithArgs:(NSArray<NSString *> *)args
            completion:(void (^)(int))completion {

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        appendLog(@"══════════ LAPIS LAUNCH START ══════════");

        // ──────────────────────────────────────
        // FIX BUG #3 — unica fonte di verità per
        // JAVA_HOME: usa quello già settato da
        // GameLauncher.swift; fallback solo se assente.
        // ──────────────────────────────────────
        const char *javaHomeCStr = getenv("JAVA_HOME");
        if (!javaHomeCStr) {
            NSString *fb = [[[NSBundle mainBundle] bundlePath]
                stringByAppendingPathComponent:@"java_runtimes/java-17-openjdk"];
            setenv("JAVA_HOME", [fb UTF8String], 1);
            javaHomeCStr = getenv("JAVA_HOME");
            appendLog([NSString stringWithFormat:
                @"JAVA_HOME assente, uso fallback bundle: %s", javaHomeCStr]);
        }
        NSString *jrePath = [NSString stringWithUTF8String:javaHomeCStr];
        appendLog([NSString stringWithFormat:@"JAVA_HOME → %@", jrePath]);

        // ──────────────────────────────────────
        // FIX BUG #1 PARTE 1 — carica libjli
        // ──────────────────────────────────────
        NSString *libjliPath = [jrePath stringByAppendingPathComponent:@"lib/libjli.dylib"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:libjliPath]) {
            // Java 8 mette libjli in lib/jli/
            libjliPath = [jrePath stringByAppendingPathComponent:@"lib/jli/libjli.dylib"];
        }
        appendLog([NSString stringWithFormat:@"dlopen libjli: %@", libjliPath]);

        void *libjli = dlopen([libjliPath UTF8String], RTLD_NOW | RTLD_GLOBAL);
        if (!libjli) {
            appendLog([NSString stringWithFormat:
                @"FATAL: dlopen libjli fallito — %s", dlerror()]);
            if (completion) completion(-1);
            return;
        }
        appendLog(@"libjli caricato ✓");

        JNI_CreateJavaVM_t createVM =
            (JNI_CreateJavaVM_t)dlsym(libjli, "JNI_CreateJavaVM");
        if (!createVM) {
            appendLog(@"FATAL: simbolo JNI_CreateJavaVM non trovato in libjli");
            if (completion) completion(-2);
            return;
        }
        appendLog(@"JNI_CreateJavaVM risolto ✓");

        // ──────────────────────────────────────
        // FIX BUG #2 — converti args Swift in
        // JavaVMOption[] + lista argomenti MC.
        //
        // Layout atteso da GameLauncher.swift:
        //   args[0]   = "java"            (ignorato)
        //   args[1..] = opzioni JVM       (-Xmx, -D*, --add-*)
        //   "-cp" <classpath>             (→ -Djava.class.path=)
        //   <mainClass>                   (primo arg non-flag)
        //   args restanti = argomenti MC  (--username ecc.)
        // ──────────────────────────────────────
        NSMutableArray<NSString*> *jvmOpts = [NSMutableArray array];
        NSMutableArray<NSString*> *mcArgs  = [NSMutableArray array];
        NSString *mainClass = @"net.minecraft.client.main.Main";
        BOOL foundMain = NO;

        for (NSUInteger i = 1; i < args.count; i++) {
            NSString *arg = args[i];

            if (foundMain) {
                [mcArgs addObject:arg];
                continue;
            }

            if ([arg isEqualToString:@"-cp"] || [arg isEqualToString:@"-classpath"]) {
                if (i + 1 < args.count) {
                    i++;
                    [jvmOpts addObject:
                        [NSString stringWithFormat:@"-Djava.class.path=%@", args[i]]];
                }
            } else if ([arg hasPrefix:@"-"]) {
                [jvmOpts addObject:arg];
            } else {
                mainClass = arg;   // primo token non-flag = classe principale
                foundMain = YES;
            }
        }

        appendLog([NSString stringWithFormat:
            @"JVM options: %lu | Main: %@ | MC args: %lu",
            (unsigned long)jvmOpts.count,
            mainClass,
            (unsigned long)mcArgs.count]);

        // ──────────────────────────────────────
        // FIX BUG #1 PARTE 2 — crea la JVM
        // ──────────────────────────────────────
        NSUInteger optCount = jvmOpts.count;
        JavaVMOption *vmOptions = (JavaVMOption *)calloc(optCount, sizeof(JavaVMOption));
        for (NSUInteger i = 0; i < optCount; i++) {
            vmOptions[i].optionString = (char *)[jvmOpts[i] UTF8String];
            vmOptions[i].extraInfo    = NULL;
        }

        JavaVMInitArgs vmInitArgs;
        vmInitArgs.version            = JNI_VERSION_1_8;
        vmInitArgs.nOptions           = (jint)optCount;
        vmInitArgs.options            = vmOptions;
        vmInitArgs.ignoreUnrecognized = JNI_TRUE;

        JavaVM  jvm = NULL;
        JNIEnv  env = NULL;
        jint    rc  = createVM(&jvm, (void**)&env, &vmInitArgs);
        free(vmOptions);

        if (rc != JNI_OK) {
            appendLog([NSString stringWithFormat:
                @"FATAL: JNI_CreateJavaVM ha restituito %d. "
                @"Controlla -Xmx, classpath e opzioni JVM nei log sopra.", rc]);
            if (completion) completion(-3);
            return;
        }
        appendLog(@"JVM creata con successo ✓");

        // ──────────────────────────────────────
        // FIX BUG #1 PARTE 3 — invoca Main Java
        // tramite JNI (FindClass → GetStaticMethodID
        // → NewObjectArray → CallStaticVoidMethodA)
        // ──────────────────────────────────────
        FindClass_t             FindClass_fn              = (FindClass_t)             jniSlot(env, SLOT_FindClass);
        ExceptionDescribe_t     ExceptionDescribe_fn      = (ExceptionDescribe_t)     jniSlot(env, SLOT_ExceptionDescribe);
        ExceptionCheck_t        ExceptionCheck_fn         = (ExceptionCheck_t)        jniSlot(env, SLOT_ExceptionCheck);
        GetStaticMethodID_t     GetStaticMethodID_fn      = (GetStaticMethodID_t)     jniSlot(env, SLOT_GetStaticMethodID);
        NewStringUTF_t          NewStringUTF_fn           = (NewStringUTF_t)          jniSlot(env, SLOT_NewStringUTF);
        NewObjectArray_t        NewObjectArray_fn         = (NewObjectArray_t)        jniSlot(env, SLOT_NewObjectArray);
        SetObjectArrayElement_t SetObjectArrayElement_fn  = (SetObjectArrayElement_t) jniSlot(env, SLOT_SetObjectArrayElement);
        CallStaticVoidMethodA_t CallStaticVoidMethodA_fn  = (CallStaticVoidMethodA_t) jniSlot(env, SLOT_CallStaticVoidMethodA);

        // "net.minecraft.client.main.Main" → "net/minecraft/client/main/Main"
        NSString *mainClassJNI = [mainClass stringByReplacingOccurrencesOfString:@"." withString:@"/"];
        appendLog([NSString stringWithFormat:@"FindClass: %@", mainClassJNI]);

        jclass mainCls = FindClass_fn(env, [mainClassJNI UTF8String]);
        if (!mainCls || ExceptionCheck_fn(env)) {
            appendLog([NSString stringWithFormat:
                @"FATAL: FindClass('%@') fallita. "
                @"Il classpath non contiene il JAR di Minecraft o le librerie richieste.", mainClassJNI]);
            ExceptionDescribe_fn(env);
            if (completion) completion(-4);
            return;
        }

        jmethodID mainMethodID = GetStaticMethodID_fn(env, mainCls, "main", "([Ljava/lang/String;)V");
        if (!mainMethodID || ExceptionCheck_fn(env)) {
            appendLog(@"FATAL: GetStaticMethodID per main([String)V fallita.");
            ExceptionDescribe_fn(env);
            if (completion) completion(-5);
            return;
        }

        // Costruisci String[] per gli argomenti Minecraft
        jclass   stringCls = FindClass_fn(env, "java/lang/String");
        jobjectArray jArgArray = NewObjectArray_fn(env, (jint)mcArgs.count, stringCls, NULL);
        for (NSUInteger i = 0; i < mcArgs.count; i++) {
            jstring jStr = NewStringUTF_fn(env, [mcArgs[i] UTF8String]);
            SetObjectArrayElement_fn(env, jArgArray, (jint)i, jStr);
        }

        appendLog(@"Invocazione Main Java... il gioco parte ora.");

        // Chiama Main.main(String[]) — blocca finché Minecraft non esce
        jvalue jvArgs[1];
        jvArgs[0].l = jArgArray;
        CallStaticVoidMethodA_fn(env, mainCls, mainMethodID, jvArgs);

        if (ExceptionCheck_fn(env)) {
            appendLog(@"ERRORE: eccezione Java non gestita in Main:");
            ExceptionDescribe_fn(env);
            if (completion) completion(-6);
            return;
        }

        appendLog(@"Minecraft terminato normalmente ✓");
        if (completion) completion(0);
    });
}

@end
