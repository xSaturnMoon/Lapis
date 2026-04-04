// LapisLauncher.m — JVM launcher for Lapis
// Adapted from PojavLauncher's JavaLauncher.m
// https://github.com/PojavLauncherTeam/PojavLauncher_iOS

#import "LapisLauncher.h"
#import "dyld_bypass.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <dlfcn.h>
#include <signal.h>
#include <string.h>
#include <pthread.h>

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
    // Silence Caciocavallo NPE for missing Android libs
    setenv("LD_LIBRARY_PATH", "", 1);
    
    // GL4ES settings
    setenv("LIBGL_NOINTOVLHACK", "1", 1);  // Disable overloaded functions hack (MC 1.17+)
    setenv("LIBGL_NORMALIZE", "1", 1);       // Fix white color on banner/sheep
    
    // Mesa/Zink settings
    setenv("MESA_GL_VERSION_OVERRIDE", "4.1", 1);
    
    // Run JVM in separate thread
    setenv("HACK_IGNORE_START_ON_FIRST_THREAD", "1", 1);
    
    // Set LAPIS_HOME for the dyld bypass to know which files to allow
    if (_gameHome) {
        setenv("LAPIS_HOME", _gameHome.UTF8String, 1);
        setenv("POJAV_HOME", _gameHome.UTF8String, 1); // Compat with PojavLauncher libs
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
        0, NULL,    // jargc, jargv
        0, NULL,    // appclassc, appclassv
        "17.0-lapis",       // fullversion
        "17",               // dotversion
        "java",             // prgname
        "openjdk",          // lname
        JNI_FALSE,          // javaargs
        JNI_TRUE,           // cpwildcard
        JNI_FALSE,          // javaw
        0                   // ergo
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
            // Disable buffering to capture standard output instantly
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
        
        // 4. Load JRE via dlopen (dyld bypass must be active for this to work)
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
        // The dyld bypass set SIGBUS to SIG_IGN; JVM needs default handlers
        signal(SIGSEGV, SIG_DFL);
        signal(SIGPIPE, SIG_DFL);
        signal(SIGBUS, SIG_DFL);
        signal(SIGILL, SIG_DFL);
        signal(SIGFPE, SIG_DFL);
        
        NSLog(@"[Lapis:Engine] Calling JLI_Launch with %d arguments on custom pthread with 8MB stack...", margc);
        
        // 8. Launch JVM on custom thread with enough stack memory!
        JVMArgs jvmArgs;
        jvmArgs.pJLI_Launch = pJLI_Launch;
        jvmArgs.margc = margc;
        jvmArgs.margv = margv;
        jvmArgs.result = -1;
        
        pthread_attr_t attr;
        pthread_attr_init(&attr);
        pthread_attr_setstacksize(&attr, 8 * 1024 * 1024); // 8MB stack
        
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
            _lastError = [NSString stringWithFormat:
                @"JVM exited with code %d", result];
            NSLog(@"[Lapis:Engine] %@", _lastError);
        } else {
            NSLog(@"[Lapis:Engine] JVM exited normally");
        }
        
        return result;
    }
}
