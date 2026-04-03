#import "PojavBridge.h"
#include <dlfcn.h>
#include <pthread.h>
#include <sys/stat.h>

static NSString *_javaHome = nil;
static int _renderer = 0;

@implementation PojavBridge

+ (int)launchJVMWithArgs:(NSArray<NSString *> *)args {
    NSString *jrePath = [self jrePath];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:jrePath]) {
        NSLog(@"[Lapis] ERROR: JRE not found at %@", jrePath);
        return -1;
    }
    
    setenv("JAVA_HOME", jrePath.UTF8String, 1);
    
    NSString *libPath = [jrePath stringByAppendingPathComponent:@"lib"];
    NSString *serverPath = [libPath stringByAppendingPathComponent:@"server"];
    setenv("LD_LIBRARY_PATH", [NSString stringWithFormat:@"%@:%@", libPath, serverPath].UTF8String, 1);
    
    if (_renderer == 0) {
        setenv("LIBGL_ES", "2", 1);
    }
    
    NSString *jliPath = [libPath stringByAppendingPathComponent:@"libjli.dylib"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:jliPath]) {
        NSLog(@"[Lapis] ERROR: libjli.dylib not found at %@", jliPath);
        return -2;
    }
    
    void *jliHandle = dlopen(jliPath.UTF8String, RTLD_NOW | RTLD_GLOBAL);
    
    if (!jliHandle) {
        NSLog(@"[Lapis] ERROR: Failed to load libjli: %s", dlerror());
        return -2;
    }
    
    typedef int (*JLI_Launch_t)(int argc, char **argv,
        int jargc, const char **jargv,
        int appclassc, const char **appclassv,
        const char *fullversion,
        const char *dotversion,
        const char *pname,
        const char *lname,
        int javaargs,
        int cpwildcard,
        int javaw,
        int ergo);
    
    JLI_Launch_t jliLaunch = (JLI_Launch_t)dlsym(jliHandle, "JLI_Launch");
    
    if (!jliLaunch) {
        NSLog(@"[Lapis] ERROR: JLI_Launch not found: %s", dlerror());
        dlclose(jliHandle);
        return -3;
    }
    
    int argc = (int)args.count + 1;
    char **argv = (char **)malloc(sizeof(char *) * (argc + 1));
    argv[0] = strdup("java");
    
    for (int i = 0; i < (int)args.count; i++) {
        argv[i + 1] = strdup(args[i].UTF8String);
    }
    argv[argc] = NULL;
    
    NSLog(@"[Lapis] Launching JVM with %d arguments", argc);
    
    int result = jliLaunch(argc, argv, 0, NULL, 0, NULL,
        "17.0.5", "17.0.5",
        "java", "Lapis",
        0, 0, 0, 0);
    
    for (int i = 0; i < argc; i++) {
        free(argv[i]);
    }
    free(argv);
    
    return result;
}

+ (void)setJavaHome:(NSString *)path {
    _javaHome = path;
}

+ (void)setRenderer:(int)renderer {
    _renderer = renderer;
}

+ (NSString *)jrePath {
    if (_javaHome) return _javaHome;
    
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *jrePath = [bundlePath stringByAppendingPathComponent:@"jre"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:jrePath]) return jrePath;
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    jrePath = [paths.firstObject stringByAppendingPathComponent:@"Lapis/jre"];
    
    return jrePath;
}

+ (BOOL)isJITAvailable {
    // SAFE check: do NOT use mmap or mprotect with PROT_EXEC — that crashes on iOS!
    // Instead, check if the dynamic-codesigning entitlement is present
    // by looking at the CS_DEBUGGED flag via csops
    
    // Simple approach: check if we were launched by a debugger or TrollStore
    // by checking the CS_DEBUGGED (0x10000000) flag
    uint32_t flags = 0;
    int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);
    int result = csops(getpid(), 0 /* CS_OPS_STATUS */, &flags, sizeof(flags));
    
    if (result == 0) {
        // CS_DEBUGGED = 0x10000000, CS_GET_TASK_ALLOW = 0x4
        BOOL debugged = (flags & 0x10000000) != 0;
        BOOL taskAllow = (flags & 0x4) != 0;
        NSLog(@"[Lapis] CS flags: 0x%x, debugged: %d, taskAllow: %d", flags, debugged, taskAllow);
        return debugged || taskAllow;
    }
    
    return NO;
}

+ (void)enableJIT {
    NSLog(@"[Lapis] JIT: %@", [self isJITAvailable] ? @"Available" : @"Not available");
}

@end
