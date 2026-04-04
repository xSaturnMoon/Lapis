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

int LapisEngine_launchJVM(NSArray<NSString *> *args) {
    @autoreleasepool {
        NSLog(@"[Lapis:Engine] ========================================");
        NSLog(@"[Lapis:Engine] Starting JVM launch sequence");
        NSLog(@"[Lapis:Engine] ========================================");
        
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
            margv[i] = args[i].UTF8String;
            NSLog(@"[Lapis:Engine]   arg[%d]: %s", i, margv[i]);
        }
        margc = totalArgs;
        
        // 7. Reset signal handlers before JVM launch
        // The dyld bypass set SIGBUS to SIG_IGN; JVM needs default handlers
        signal(SIGSEGV, SIG_DFL);
        signal(SIGPIPE, SIG_DFL);
        signal(SIGBUS, SIG_DFL);
        signal(SIGILL, SIG_DFL);
        signal(SIGFPE, SIG_DFL);
        
        NSLog(@"[Lapis:Engine] Calling JLI_Launch with %d arguments...", margc);
        
        // 8. Launch!
        int result = pJLI_Launch(
            margc, margv,
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
