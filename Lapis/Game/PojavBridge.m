#import "PojavBridge.h"
#include <dlfcn.h>
#include <pthread.h>
#include <sys/stat.h>
#include <sys/mman.h>

#ifndef MAP_ANONYMOUS
#define MAP_ANONYMOUS MAP_ANON
#endif

#ifndef MAP_JIT
#define MAP_JIT 0x0800
#endif

static NSString *_javaHome = nil;
static int _renderer = 0;

@implementation PojavBridge

+ (int)launchJVMWithArgs:(NSArray<NSString *> *)args {
    NSString *jrePath = [self jrePath];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:jrePath]) {
        NSLog(@"[Lapis] ERROR: JRE not found at %@", jrePath);
        return -1;
    }
    
    if (![self isJITAvailable]) {
        NSLog(@"[Lapis] WARNING: JIT not available. Game will be slow.");
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
    
    // 1. Check app bundle
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *jrePath = [bundlePath stringByAppendingPathComponent:@"jre"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:jrePath]) return jrePath;
    
    // 2. Check Documents
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    jrePath = [paths.firstObject stringByAppendingPathComponent:@"Lapis/jre"];
    
    return jrePath;
}

+ (BOOL)isJITAvailable {
    void *ptr = mmap(NULL, 4096,
                     PROT_READ | PROT_WRITE | PROT_EXEC,
                     MAP_PRIVATE | MAP_ANONYMOUS | MAP_JIT,
                     -1, 0);
    if (ptr != MAP_FAILED) {
        munmap(ptr, 4096);
        return YES;
    }
    
    ptr = mmap(NULL, 4096,
               PROT_READ | PROT_WRITE | PROT_EXEC,
               MAP_PRIVATE | MAP_ANONYMOUS,
               -1, 0);
    if (ptr != MAP_FAILED) {
        munmap(ptr, 4096);
        return YES;
    }
    
    return NO;
}

+ (void)enableJIT {
    NSLog(@"[Lapis] JIT: %@", [self isJITAvailable] ? @"Available" : @"Not available");
}

@end
