#import "LauncherBridge.h"
#import <dlfcn.h>

typedef int (*JavaLauncherMainFunc)(int argc, char **argv);

@implementation LauncherBridge

+ (void)launchWithArgs:(NSArray<NSString *> *)args completion:(void(^)(int exitCode))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        // Load the engine from the current process (it will be linked via project.yml)
        void *handle = dlopen(NULL, RTLD_NOW);
        JavaLauncherMainFunc func = (JavaLauncherMainFunc)dlsym(handle, "JavaLauncher_main");
        
        if (!func) {
            NSLog(@"[LapisEngine] FATAL: JavaLauncher_main symbol not found in any loaded framework.");
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(-2);
            });
            return;
        }
        
        int argc = (int)args.count;
        char **argv = malloc(sizeof(char *) * (argc + 1));
        NSLog(@"[LapisEngine] Starting Minecraft Engine with %d arguments...", argc);
        
        for (int i = 0; i < argc; i++) {
            argv[i] = strdup([args[i] UTF8String]);
            NSLog(@"[LapisEngine] [%d] %s", i, argv[i]);
            
            // Auto-detect JRE path to set JAVA_HOME environmental variable
            if ([args[i] containsString:@"jre17-arm64"]) {
                setenv("JAVA_HOME", [args[i] UTF8String], 1);
                NSLog(@"[LapisEngine] Environment: Set JAVA_HOME to %s", argv[i]);
            }
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
