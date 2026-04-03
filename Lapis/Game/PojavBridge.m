#import "PojavBridge.h"
#include <dlfcn.h>
#include <pthread.h>
#include <sys/stat.h>

// Forward declarations for PojavLauncher native functions
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

static NSString *_javaHome = nil;
static int _renderer = 0; // 0 = gl4es

@implementation PojavBridge

+ (int)launchJVMWithArgs:(NSArray<NSString *> *)args {
    NSString *jrePath = [self jrePath];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:jrePath]) {
        NSLog(@"[Lapis] ERROR: JRE not found at %@", jrePath);
        return -1;
    }
    
    // Set up environment variables
    setenv("JAVA_HOME", jrePath.UTF8String, 1);
    
    NSString *libPath = [jrePath stringByAppendingPathComponent:@"lib"];
    NSString *serverPath = [libPath stringByAppendingPathComponent:@"server"];
    setenv("LD_LIBRARY_PATH", [NSString stringWithFormat:@"%@:%@", libPath, serverPath].UTF8String, 1);
    
    // Set renderer
    if (_renderer == 0) {
        setenv("LIBGL_ES", "2", 1);
    }
    
    // Load libjli.dylib
    NSString *jliPath = [libPath stringByAppendingPathComponent:@"libjli.dylib"];
    void *jliHandle = dlopen(jliPath.UTF8String, RTLD_NOW | RTLD_GLOBAL);
    
    if (!jliHandle) {
        NSLog(@"[Lapis] ERROR: Failed to load libjli.dylib: %s", dlerror());
        return -2;
    }
    
    JLI_Launch_t jliLaunch = (JLI_Launch_t)dlsym(jliHandle, "JLI_Launch");
    
    if (!jliLaunch) {
        NSLog(@"[Lapis] ERROR: JLI_Launch not found: %s", dlerror());
        dlclose(jliHandle);
        return -3;
    }
    
    // Convert NSArray to C argv
    int argc = (int)args.count + 1; // +1 for "java" prefix
    char **argv = (char **)malloc(sizeof(char *) * (argc + 1));
    argv[0] = strdup("java");
    
    for (int i = 0; i < args.count; i++) {
        argv[i + 1] = strdup(args[i].UTF8String);
    }
    argv[argc] = NULL;
    
    NSLog(@"[Lapis] Launching JVM with %d args", argc);
    for (int i = 0; i < argc; i++) {
        NSLog(@"[Lapis]   arg[%d]: %s", i, argv[i]);
    }
    
    // Launch JVM on a separate thread
    int result = jliLaunch(argc, argv, 0, NULL, 0, NULL,
        "17.0.1", "17.0.1",
        "java", "Lapis",
        0, 0, 0, 0);
    
    // Cleanup
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
    
    // Default: bundled JRE in app bundle
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *jrePath = [bundlePath stringByAppendingPathComponent:@"jre"];
    
    // Check Documents directory as fallback
    if (![[NSFileManager defaultManager] fileExistsAtPath:jrePath]) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *docsDir = paths.firstObject;
        jrePath = [docsDir stringByAppendingPathComponent:@"Lapis/jre"];
    }
    
    return jrePath;
}

+ (BOOL)isJITAvailable {
    // Check if JIT is enabled by trying to allocate RWX memory
    void *ptr = mmap(NULL, 4096, PROT_READ | PROT_WRITE | PROT_EXEC,
                     MAP_PRIVATE | MAP_ANONYMOUS | MAP_JIT, -1, 0);
    if (ptr != MAP_FAILED) {
        munmap(ptr, 4096);
        return YES;
    }
    return NO;
}

+ (void)enableJIT {
    // JIT is enabled via entitlements or TrollStore
    // This is a no-op if already enabled
    NSLog(@"[Lapis] JIT status: %@", [self isJITAvailable] ? @"Available" : @"Not available");
}

@end
