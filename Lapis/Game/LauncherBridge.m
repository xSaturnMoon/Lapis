#import "LauncherBridge.h"
#import <dlfcn.h>

typedef int (*JavaLauncherMainFunc)(int argc, char **argv);

@implementation LauncherBridge

+ (void)launchWithArgs:(NSArray<NSString *> *)args completion:(void(^)(int exitCode))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        // Load the engine from the current process
        void *handle = dlopen(NULL, RTLD_NOW);
        
        // Try multiple symbol names (Old Pojav and likely Amethyst names)
        JavaLauncherMainFunc func = (JavaLauncherMainFunc)dlsym(handle, "JavaLauncher_main");
        if (!func) func = (JavaLauncherMainFunc)dlsym(handle, "AmethystLauncher_main");
        if (!func) func = (JavaLauncherMainFunc)dlsym(handle, "main_java");
        
        if (!func) {
            NSLog(@"[LapisEngine] FATAL: Launcher entry point not found. Symbols searched: JavaLauncher_main, AmethystLauncher_main, main_java");
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(-2);
            });
            return;
        }
        
        // Setup JAVA_HOME pointing to our bundled runtime
        NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
        NSString *jrePath = [bundlePath stringByAppendingPathComponent:@"runtime"]; // Amethyst folder
        if (![[NSFileManager defaultManager] fileExistsAtPath:jrePath]) {
            jrePath = [bundlePath stringByAppendingPathComponent:@"java_runtimes"]; // Alternative
        }
        setenv("JAVA_HOME", [jrePath UTF8String], 1);
        NSLog(@"[LapisEngine] JAVA_HOME set to: %@", jrePath);
        
        int argc = (int)args.count;
        char **argv = malloc(sizeof(char *) * (argc + 1));
        for (int i = 0; i < argc; i++) {
            argv[i] = strdup([args[i] UTF8String]);
        }
        argv[argc] = NULL;
        
        // Essential environment variables for Java on iOS
        setenv("PRINT_ALL_EXCEPTIONS", "1", 1);
        setenv("JLI_SEP", ":", 1);
        
        NSLog(@"[LapisEngine] Calling JavaLauncher_main...");
        int result = func(argc, argv);
        NSLog(@"[LapisEngine] Engine terminated. Exit code: %d", result);
        
        // Cleanup
        for (int i = 0; i < argc; i++) free(argv[i]);
        free(argv);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(result);
        });
    });
}

@end
