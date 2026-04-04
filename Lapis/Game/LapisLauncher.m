// LapisLauncher.m — JVM launcher for Lapis
// Adapted from PojavLauncher's JavaLauncher.m
// https://github.com/PojavLauncherTeam/PojavLauncher_iOS

#import "LapisLauncher.h"
#import "dyld_bypass.h"
#import "fishhook.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <dlfcn.h>
#include <signal.h>
#include <string.h>
#include <pthread.h>
#import <objc/runtime.h>

// ============================================================
// MARK: - AppKit/UIKit Dual Guard
// Blinda in maniera assoluta sia i bypass C che quelli ObjC.
// Minecraft nativo Mac (libglfw) proverà a fregarci in due modi.
// ============================================================

// Livello 1: Objective-C Swizzling (Blocca [UIApplication init])
@interface UIApplication (LapisGuardObjC)
- (id)lapis_init;
@end

@implementation UIApplication (LapisGuardObjC)
- (id)lapis_init {
    @try {
        if ([UIApplication sharedApplication] != nil) {
            NSLog(@"[Lapis:Guard] Blocked duplicate ObjC [[UIApplication alloc] init] from libglfw!");
            return [UIApplication sharedApplication];
        }
    } @catch (...) {}
    return [self lapis_init];
}
@end

static void installObjCGuard(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLog(@"[Lapis:Guard] Installing swizzle on -[UIApplication init]");
        Method orig = class_getInstanceMethod([UIApplication class], @selector(init));
        Method swizzle = class_getInstanceMethod([UIApplication class], @selector(lapis_init));
        method_exchangeImplementations(orig, swizzle);
        
        // Blindaggio aggiuntivo su NSApplication (MacOS) per impedire a libglfw di avviare AppKit!
        Class nsAppClass = NSClassFromString(@"NSApplication");
        if (nsAppClass) {
            NSLog(@"[Lapis:Guard] Installing swizzle on +[NSApplication sharedApplication]");
            Method origNsApp = class_getClassMethod(nsAppClass, NSSelectorFromString(@"sharedApplication"));
            Method swizzleNsApp = class_getClassMethod([UIApplication class], NSSelectorFromString(@"sharedApplication"));
            if (origNsApp && swizzleNsApp) {
                method_exchangeImplementations(origNsApp, swizzleNsApp);
            }
        }
    });
}

// Livello 2: C Function Hook via fishhook (Blocca UIApplicationMain e NSApplicationLoad)

typedef int (*UIApplicationMain_t)(int argc, char * _Nullable * _Nonnull argv,
    NSString * _Nullable principalClassName,
    NSString * _Nullable delegateClassName);

static UIApplicationMain_t original_UIApplicationMain = NULL;

static int lapis_UIApplicationMain(int argc, char * _Nullable * _Nonnull argv,
    NSString * _Nullable principalClassName,
    NSString * _Nullable delegateClassName)
{
    // If UIApplication already exists, silently block the second call
    UIApplication *existing = nil;
    @try { existing = [UIApplication sharedApplication]; } @catch (...) {}
    if (existing != nil) {
        NSLog(@"[Lapis:Guard] Blocked duplicate UIApplicationMain() or NSApplicationLoad() call. Thread suspended.");
        // Non possiamo ritornare: Java si aspetta che UIApplicationMain blocchi in eterno sulla runloop!
        while (1) { sleep(1000); }
        return 0;
    }
    return original_UIApplicationMain(argc, argv, principalClassName, delegateClassName);
}

static BOOL (*original_NSApplicationLoad)(void) = NULL;
static BOOL lapis_NSApplicationLoad(void) {
    NSLog(@"[Lapis:Guard] Blocked NSApplicationLoad() call from libglfw!");
    while(1) { sleep(1000); }
    return YES;
}

static void hookUIApplicationMain(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSLog(@"[Lapis:Guard] Hooking UIApplicationMain and NSApplicationLoad via fishhook");
        rebind_symbols((struct rebinding[2]){
            {
                "UIApplicationMain",
                (void *)lapis_UIApplicationMain,
                (void **)&original_UIApplicationMain
            },
            {
                "NSApplicationLoad",
                (void *)lapis_NSApplicationLoad,
                (void **)&original_NSApplicationLoad
            }
        }, 2);
        NSLog(@"[Lapis:Guard] UIApplicationMain hook installed");
    });
}

extern char **environ;

// JNI types needed for JLI_Launch
typedef signed char jboolean;
typedef int jint;
#define JNI_TRUE 1
#define JNI_FALSE 0

// JLI_Launch function pointer type
typedef int (JLI_Launch_func)(
    int argc, const char **argv,
    int jargc, const char **jargv,
    int appclassc, const char **appclassv,
    const char *fullversion, const char *dotversion,
    const char *prgname, const char *lname,
    jboolean javaargs, jboolean cpwildcard,
    jboolean javaw, jint ergo
);

static BOOL _bypassReady = NO;
static NSString *_lastError = nil;
static NSString *_javaHome = nil;
static NSString *_gameHome = nil;

// ============================================================
// MARK: - Environment Setup
// ============================================================

static void setupDefaultEnvironment(void) {
    // CRITICO: impedisce al JRE di inizializzare UIKit/AppKit
    setenv("JAVA_STARTED_ON_FIRST_THREAD_0", "1", 1);
    setenv("SKIP_JAVA_SYSTEM_INIT", "1", 1);
    
    // Impedisce al runtime Java di cercare display/finestre macOS
    setenv("AWT_TOOLKIT", "headlessToolkit", 1);
    setenv("java.awt.headless", "true", 1);
    
    // PojavLauncher compatibility
    setenv("POJAV_ENVIRON_HOME", "", 1);
    setenv("HACK_IGNORE_START_ON_FIRST_THREAD", "1", 1);
    
    // Silence Caciocavallo NPE for missing Android libs
    setenv("LD_LIBRARY_PATH", "", 1);
    
    // GL4ES settings
    setenv("LIBGL_NOINTOVLHACK", "1", 1);
    setenv("LIBGL_NORMALIZE", "1", 1);
    
    // Mesa/Zink settings
    setenv("MESA_GL_VERSION_OVERRIDE", "4.1", 1);
    
    // Set LAPIS_HOME for the dyld bypass to know which files to allow
    if (_gameHome) {
        setenv("LAPIS_HOME", _gameHome.UTF8String, 1);
        setenv("POJAV_HOME", _gameHome.UTF8String, 1);
    }
    
    if (_javaHome) {
        setenv("JAVA_HOME", _javaHome.UTF8String, 1);
    }
}

// ============================================================
// MARK: - JRE Library Path Resolution
// ============================================================

static NSString* findJLIPath(void) {
    if (!_javaHome) return nil;
    
    NSFileManager *fm = NSFileManager.defaultManager;
    
    // Java 11+ path
    NSString *jli11 = [_javaHome stringByAppendingPathComponent:@"lib/libjli.dylib"];
    if ([fm fileExistsAtPath:jli11]) return jli11;
    
    // Java 8 path
    NSString *jli8 = [_javaHome stringByAppendingPathComponent:@"lib/jli/libjli.dylib"];
    if ([fm fileExistsAtPath:jli8]) return jli8;
    
    return nil;
}

// ============================================================
// MARK: - Public API
// ============================================================

void LapisEngine_init(void) {
    NSLog(@"[Lapis:Engine] Initializing engine...");
    
    // Initialize the dyld bypass — MUST be done before any dlopen
    init_bypassDyldLibValidation();
    _bypassReady = YES;
    
    NSLog(@"[Lapis:Engine] Engine initialized. Dyld bypass: %@",
          _bypassReady ? @"ACTIVE" : @"FAILED");
}

void LapisEngine_setJavaHome(NSString *path) {
    _javaHome = [path copy];
    NSLog(@"[Lapis:Engine] JAVA_HOME set to: %@", path);
}

void LapisEngine_setGameHome(NSString *path) {
    _gameHome = [path copy];
    NSLog(@"[Lapis:Engine] Game home set to: %@", path);
}

BOOL LapisEngine_isBypassReady(void) {
    return _bypassReady;
}

NSString* LapisEngine_getLastError(void) {
    return _lastError;
}

// ============================================================
// MARK: - JVM Thread Setup
// ============================================================

typedef struct {
    JLI_Launch_func *pJLI_Launch;
    int margc;
    const char **margv;
    int result;
} JVMArgs;

static void* jvm_thread_func(void* arg) {
    JVMArgs *jvmArgs = (JVMArgs *)arg;
    
    jvmArgs->result = jvmArgs->pJLI_Launch(
        jvmArgs->margc, jvmArgs->margv,
        0, NULL,
        0, NULL,
        "21.0-lapis",
        "21",
        "java",
        "openjdk",
        JNI_FALSE,
        JNI_TRUE,
        JNI_FALSE,
        0
    );
    
    return NULL;
}

int LapisEngine_launchJVM(NSArray<NSString *> *args) {
    @autoreleasepool {
        NSLog(@"[Lapis:Engine] ========================================");
        NSLog(@"[Lapis:Engine] Starting JVM launch sequence");
        NSLog(@"[Lapis:Engine] ========================================");
        
        // Redirect stdout and stderr to latestlog.txt
        if (_gameHome) {
            NSString *logPath = [_gameHome stringByAppendingPathComponent:@"latestlog.txt"];
            freopen([logPath UTF8String], "w", stdout);
            freopen([logPath UTF8String], "w", stderr);
            setvbuf(stdout, NULL, _IONBF, 0);
            setvbuf(stderr, NULL, _IONBF, 0);
            NSLog(@"[Lapis:Engine] Logs redirected to: %@", logPath);
            fprintf(stdout, "======== Lapis JVM Boot Log ========\n");
            fprintf(stdout, "Game Home: %s\n", _gameHome.UTF8String);
        }
        
        // 1. Check prerequisites
        if (!_bypassReady) {
            _lastError = @"Dyld bypass not initialized. Call LapisEngine_init() first.";
            NSLog(@"[Lapis:Engine] ERROR: %@", _lastError);
            return -1;
        }
        
        if (!_javaHome) {
            _lastError = @"JAVA_HOME not set. Call LapisEngine_setJavaHome() first.";
            NSLog(@"[Lapis:Engine] ERROR: %@", _lastError);
            return -1;
        }
        
        // 2. Setup environment
        setupDefaultEnvironment();
        
        // 3. Find libjli.dylib
        NSString *jliPath = findJLIPath();
        if (!jliPath) {
            _lastError = [NSString stringWithFormat:
                @"libjli.dylib not found in %@/lib/", _javaHome];
            NSLog(@"[Lapis:Engine] ERROR: %@", _lastError);
            return -1;
        }
        
        NSLog(@"[Lapis:Engine] JLI path: %@", jliPath);
        setenv("INTERNAL_JLI_PATH", jliPath.UTF8String, 1);
        
        // 4. Load JRE via dlopen
        NSLog(@"[Lapis:Engine] Loading JRE library...");
        void *libjli = dlopen(jliPath.UTF8String, RTLD_GLOBAL);
        
        if (!libjli) {
            const char *error = dlerror();
            _lastError = [NSString stringWithFormat:
                @"Failed to load JRE: %s\n\nMake sure JIT is enabled via StikDebug or TrollStore.",
                error ? error : "unknown error"];
            NSLog(@"[Lapis:Engine] ERROR: dlopen failed: %s", error ? error : "unknown");
            return -2;
        }
        
        NSLog(@"[Lapis:Engine] JRE loaded successfully!");
        
        // Installiamo lo swizzle in Objective-C per i messaggi nativi
        installObjCGuard();
        
        // CRITICAL FIX: We MUST hook UIApplicationMain AFTER libjli is loaded via dlopen
        hookUIApplicationMain();
        
        // 5. Find JLI_Launch symbol
        JLI_Launch_func *pJLI_Launch = (JLI_Launch_func *)dlsym(libjli, "JLI_Launch");
        if (!pJLI_Launch) {
            _lastError = @"JLI_Launch symbol not found in libjli.dylib";
            NSLog(@"[Lapis:Engine] ERROR: %@", _lastError);
            dlclose(libjli);
            return -3;
        }
        
        NSLog(@"[Lapis:Engine] JLI_Launch found at %p", pJLI_Launch);
        
        // 6. Build argument array
        int margc = 0;
        int totalArgs = (int)args.count;
        const char **margv = (const char **)calloc(totalArgs + 1, sizeof(char *));
        
        for (int i = 0; i < totalArgs; i++) {
            margv[i] = strdup(args[i].UTF8String);
            NSLog(@"[Lapis:Engine]   arg[%d]: %s", i, margv[i]);
        }
        margc = totalArgs;
        margv[margc] = NULL;
        
        // 7. Reset signal handlers before JVM launch
        signal(SIGSEGV, SIG_DFL);
        signal(SIGPIPE, SIG_DFL);
        signal(SIGBUS, SIG_DFL);
        signal(SIGILL, SIG_DFL);
        signal(SIGFPE, SIG_DFL);
        
        NSLog(@"[Lapis:Engine] Calling JLI_Launch with %d arguments on custom pthread with 8MB stack...", margc);
        
        // 8. Launch JVM on custom thread with 8MB stack
        JVMArgs jvmArgs;
        jvmArgs.pJLI_Launch = pJLI_Launch;
        jvmArgs.margc = margc;
        jvmArgs.margv = margv;
        jvmArgs.result = -1;
        
        pthread_attr_t attr;
        pthread_attr_init(&attr);
        pthread_attr_setstacksize(&attr, 8 * 1024 * 1024);
        
        pthread_t jvm_thread;
        int pt_res = pthread_create(&jvm_thread, &attr, jvm_thread_func, &jvmArgs);
        pthread_attr_destroy(&attr);
        
        if (pt_res == 0) {
            pthread_join(jvm_thread, NULL);
        } else {
            NSLog(@"[Lapis:Engine] ERROR: pthread_create failed with code %d", pt_res);
            jvmArgs.result = -4;
        }
        
        int result = jvmArgs.result;
        
        for (int i = 0; i < margc; i++) {
            free((void *)margv[i]);
        }
        free(margv);
        
        if (result != 0) {
            _lastError = [NSString stringWithFormat:@"JVM exited with code %d", result];
            NSLog(@"[Lapis:Engine] %@", _lastError);
        } else {
            NSLog(@"[Lapis:Engine] JVM exited normally");
        }
        
        return result;
    }
}
