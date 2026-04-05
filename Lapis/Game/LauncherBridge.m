#import "LauncherBridge.h"
#import <dlfcn.h>

typedef int (*JavaLauncherMainFunc)(int argc, char **argv);

@implementation LauncherBridge

+ (void)launchWithArgs:(NSArray<NSString *> *)args completion:(void(^)(int exitCode))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSLog(@"[LapisEngine] Starting exhaustive symbol search for Amethyst engine...");
        
        // 1. Force load essential frameworks to expose symbols
        NSString *frameworkPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Frameworks"];
        NSArray *fwNames = @[@"AltKit.framework/AltKit", @"CAltKit.framework/CAltKit", @"libGLESv2.framework/libGLESv2", @"libEGL.framework/libEGL"];
        
        for (NSString *fw in fwNames) {
            NSString *fullPath = [frameworkPath stringByAppendingPathComponent:fw];
            void *fwHandle = dlopen([fullPath UTF8String], RTLD_NOW | RTLD_GLOBAL);
            if (fwHandle) {
                NSLog(@"[LapisEngine] Successfully pre-loaded: %@", fw);
            } else {
                NSLog(@"[LapisEngine] Warning: Could not pre-load %@: %s", fw, dlerror());
            }
        }

        // 2. Search for entry point symbol in the global namespace
        void *handle = RTLD_DEFAULT;
        JavaLauncherMainFunc func = NULL;
        
        NSArray *symbolNames = @[@"JavaLauncher_main", @"AmethystLauncher_main", @"main_java", @"amethyst_main", @"main"];
        for (NSString *symName in symbolNames) {
            func = (JavaLauncherMainFunc)dlsym(handle, [symName UTF8String]);
            if (func) {
                NSLog(@"[LapisEngine] Found entry point: %@", symName);
                break;
            }
        }
        
        if (!func) {
            NSLog(@"[LapisEngine] FATAL: All entry points failed. Error: %s", dlerror());
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(-2);
            });
            return;
        }
        
        // 3. Setup JAVA_HOME correctly
        NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
        NSString *jrePath = [bundlePath stringByAppendingPathComponent:@"runtime"]; // Amethyst structure
        if (![[NSFileManager defaultManager] fileExistsAtPath:jrePath]) {
            jrePath = [bundlePath stringByAppendingPathComponent:@"java_runtimes"];
        }
        setenv("JAVA_HOME", [jrePath UTF8String], 1);
        
        // Essential JRE paths for Java 17
        setenv("LD_LIBRARY_PATH", [[bundlePath stringByAppendingPathComponent:@"Frameworks"] UTF8String], 1);
        setenv("DYLD_LIBRARY_PATH", [[bundlePath stringByAppendingPathComponent:@"Frameworks"] UTF8String], 1);
        
        int argc = (int)args.count;
        char **argv = malloc(sizeof(char *) * (argc + 1));
        for (int i = 0; i < argc; i++) {
            argv[i] = strdup([args[i] UTF8String]);
        }
        argv[argc] = NULL;
        
        setenv("PRINT_ALL_EXCEPTIONS", "1", 1);
        setenv("JLI_SEP", ":", 1);
        
        NSLog(@"[LapisEngine] Reaching point of no return: Calling engine...");
        int result = func(argc, argv);
        NSLog(@"[LapisEngine] Engine terminated. Code: %d", result);
        
        for (int i = 0; i < argc; i++) free(argv[i]);
        free(argv);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(result);
        });
    });
}

@end
