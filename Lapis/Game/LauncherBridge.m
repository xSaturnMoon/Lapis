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
        NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        launchLogPath = [docs stringByAppendingPathComponent:@"Lapis/launch.log"];
    }
    [[NSFileManager defaultManager] createDirectoryAtPath:[launchLogPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *ts = [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle];
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", ts, message];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:launchLogPath];
    if (fh) {
        [fh seekToEndOfFile];
        [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [fh synchronizeFile]; // FIX: Forza la scrittura immediata sul disco prima del crash
        [fh closeFile];
    } else {
        [line writeToFile:launchLogPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    NSLog(@"[LauncherBridge] %@", message);
}

@implementation LauncherBridge

+ (void)launchWithArgs:(NSArray<NSString *> *)args completion:(void (^)(int))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        appendLog(@"══════════ DEEP IGNITION START ══════════");

        // 1. Resolve JAVA_HOME
        const char *jhEnv = getenv("JAVA_HOME");
        NSString *jrePath = jhEnv ? [NSString stringWithUTF8String:jhEnv] : [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"java_runtimes/java-17-openjdk"];
        appendLog([NSString stringWithFormat:@"JRE: %@", jrePath]);

        // 2. FORCED LOAD: libjvm.dylib (Il cuore del motore)
        // libjli.dylib carica libjvm internamente, ma noi lo facciamo prima per vedere l'errore.
        NSString *libjvmPath = [jrePath stringByAppendingPathComponent:@"lib/server/libjvm.dylib"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:libjvmPath]) {
            libjvmPath = [jrePath stringByAppendingPathComponent:@"lib/libjvm.dylib"]; // Fallback legacy
        }
        
        appendLog([NSString stringWithFormat:@"Forcing dlopen libjvm: %@", libjvmPath]);
        void *libjvm = dlopen([libjvmPath UTF8String], RTLD_NOW | RTLD_GLOBAL);
        if (!libjvm) {
            appendLog([NSString stringWithFormat:@"CRITICAL Error loading libjvm: %s", dlerror()]);
            if (completion) completion(-10); return;
        }
        appendLog(@"libjvm.dylib CARICATO ✓ (Il motore è in memoria)");

        // 3. Load libjli.dylib (L'accenditore)
        NSString *libjliPath = [jrePath stringByAppendingPathComponent:@"lib/libjli.dylib"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:libjliPath]) libjliPath = [jrePath stringByAppendingPathComponent:@"lib/jli/libjli.dylib"];
        
        appendLog([NSString stringWithFormat:@"dlopen libjli: %@", libjliPath]);
        void *libjli = dlopen([libjliPath UTF8String], RTLD_NOW | RTLD_GLOBAL);
        if (!libjli) {
            appendLog([NSString stringWithFormat:@"FATAL dlopen jli: %s", dlerror()]);
            if (completion) completion(-1); return;
        }

        JNI_CreateJavaVM_t createVM = (JNI_CreateJavaVM_t)dlsym(libjli, "JNI_CreateJavaVM");
        if (!createVM) {
            appendLog(@"FATAL: JNI_CreateJavaVM not found in jli.");
            if (completion) completion(-2); return;
        }

        // 4. Parse Arguments
        NSMutableArray<NSString*> *jvmOpts = [NSMutableArray array];
        NSMutableArray<NSString*> *mcArgs  = [NSMutableArray array];
        NSString *mainClass = @"net.minecraft.client.main.Main";
        BOOL foundMain = NO;

        for (NSUInteger i = 1; i < args.count; i++) {
            NSString *arg = args[i];
            if (foundMain) { [mcArgs addObject:arg]; continue; }
            if ([arg isEqualToString:@"-cp"] || [arg isEqualToString:@"-classpath"]) {
                if (i + 1 < args.count) {
                    i++;
                    NSString *cpPath = args[i];
                    [jvmOpts addObject:[NSString stringWithFormat:@"-Djava.class.path=%@", cpPath]];
                }
            } else if ([arg hasPrefix:@"-"]) {
                [jvmOpts addObject:arg];
            } else {
                mainClass = arg; foundMain = YES;
            }
        }

        // DIAGNOSTICA: Forza modalità interpretata IN CIMA alla lista
        [jvmOpts insertObject:@"-Xint" atIndex:0]; 
        [jvmOpts insertObject:@"-Xms64M" atIndex:1];

        // 5. Create Java VM (POINT OF NO RETURN)
        NSUInteger optCount = jvmOpts.count;
        JavaVMOption *vmOptions = (JavaVMOption *)calloc(optCount, sizeof(JavaVMOption));
        
        appendLog(@"[DIAGNOSTIC] Preparazione opzioni JVM...");
        for (NSUInteger i = 0; i < optCount; i++) {
            NSString *opt = jvmOpts[i];
            vmOptions[i].optionString = (char *)[opt UTF8String];
            vmOptions[i].extraInfo    = NULL;
            
            // Abbreviato per evitare crash da stringhe enormi (es. classpath) nel logger
            if (opt.length > 200) {
                appendLog([NSString stringWithFormat:@"JVM Option [%lu]: (Lunga %lu chars) %@...", 
                           (unsigned long)i, (unsigned long)opt.length, [opt substringToIndex:150]]);
            } else {
                appendLog([NSString stringWithFormat:@"JVM Option [%lu]: %@", (unsigned long)i, opt]);
            }
        }

        JavaVMInitArgs vmInitArgs;
        memset(&vmInitArgs, 0, sizeof(vmInitArgs)); // FIX: Pulizia memoria fondamentale per ARM64
        vmInitArgs.version = JNI_VERSION_1_8;
        vmInitArgs.nOptions = (jint)optCount;
        vmInitArgs.options = vmOptions;
        vmInitArgs.ignoreUnrecognized = JNI_TRUE;

        JavaVM  jvm = NULL;
        JNIEnv  env = NULL;
        appendLog(@"[DIAGNOSTIC] Avvio in modalità -Xint (Safe Mode)...");
        appendLog(@"CALIAMO JNI_CreateJavaVM...");
        
        jint rc = createVM(&jvm, (void**)&env, &vmInitArgs);
        
        // Non liberare vmOptions prima di aver finito con la JVM se necessario, ma qui va bene
        free(vmOptions);

        if (rc != JNI_OK) {
            appendLog([NSString stringWithFormat:@"FATAL: JNI_CreateJavaVM fallito con codice: %d", (int)rc]);
            if (completion) completion(-3); return;
        }
        appendLog(@"JVM CREATA CON SUCCESSO ✓");

        // 6. Invocazione Class Main
        FindClass_t FindClass_fn = (FindClass_t)jniSlot(env, SLOT_FindClass);
        GetStaticMethodID_t GetStaticMethodID_fn = (GetStaticMethodID_t)jniSlot(env, SLOT_GetStaticMethodID);
        NewStringUTF_t NewStringUTF_fn = (NewStringUTF_t)jniSlot(env, SLOT_NewStringUTF);
        NewObjectArray_t NewObjectArray_fn = (NewObjectArray_t)jniSlot(env, SLOT_NewObjectArray);
        SetObjectArrayElement_t SetObjectArrayElement_fn = (SetObjectArrayElement_t)jniSlot(env, SLOT_SetObjectArrayElement);
        CallStaticVoidMethodA_t CallStaticVoidMethodA_fn = (CallStaticVoidMethodA_t)jniSlot(env, SLOT_CallStaticVoidMethodA);
        ExceptionCheck_t ExceptionCheck_fn = (ExceptionCheck_t)jniSlot(env, SLOT_ExceptionCheck);
        ExceptionDescribe_t ExceptionDescribe_fn = (ExceptionDescribe_t)jniSlot(env, SLOT_ExceptionDescribe);

        NSString *mainClassJNI = [mainClass stringByReplacingOccurrencesOfString:@"." withString:@"/"];
        jclass mainCls = FindClass_fn(env, [mainClassJNI UTF8String]);
        if (!mainCls || ExceptionCheck_fn(env)) {
            appendLog(@"FATAL: Main class not found.");
            if (completion) completion(-4); return;
        }

        jmethodID mid = GetStaticMethodID_fn(env, mainCls, "main", "([Ljava/lang/String;)V");
        jclass stringCls = FindClass_fn(env, "java/lang/String");
        jobjectArray jArgs = NewObjectArray_fn(env, (jint)mcArgs.count, stringCls, NULL);
        for (NSUInteger i = 0; i < mcArgs.count; i++) {
            SetObjectArrayElement_fn(env, jArgs, (jint)i, NewStringUTF_fn(env, [mcArgs[i] UTF8String]));
        }

        appendLog(@"AVVIO MINECRAFT...");
        jvalue jvArgs[1]; jvArgs[0].l = jArgs;
        CallStaticVoidMethodA_fn(env, mainCls, mid, jvArgs);

        if (ExceptionCheck_fn(env)) {
            appendLog(@"Eccezione rilevata in Java:");
            ExceptionDescribe_fn(env);
        }

        appendLog(@"Minecraft terminato.");
        if (completion) completion(0);
    });
}

@end
