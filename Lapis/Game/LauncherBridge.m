#import "LauncherBridge.h"
#import <dlfcn.h>

typedef int (*JavaLauncherMainFunc)(int argc, char **argv);

@implementation LauncherBridge

+ (void)launchWithArgs:(NSArray<NSString *> *)args completion:(void(^)(int exitCode))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSLog(@"[LauncherBridge] Preparazione lancio engine...");
        
        // Converti NSArray in argc/argv
        int argc = (int)args.count;
        char **argv = malloc(sizeof(char *) * (argc + 1));
        for (int i = 0; i < argc; i++) {
            argv[i] = strdup([args[i] UTF8String]);
        }
        argv[argc] = NULL;
        
        // Tenta di trovare JavaLauncher_main dinamicamente dai framework caricati
        // (Verranno caricati via GitHub Actions in Lapis/Game/Native)
        void *handle = RTLD_DEFAULT;
        JavaLauncherMainFunc mainFunc = (JavaLauncherMainFunc)dlsym(handle, "JavaLauncher_main");
        
        int result = -1;
        if (mainFunc) {
            NSLog(@"[LauncherBridge] Engine trovato! Avvio in corso...");
            result = mainFunc(argc, argv);
        } else {
            NSLog(@"[LauncherBridge] ERROR: JavaLauncher_main non trovato nei framework.");
            // Simulazione per test se l'engine manca
            [NSThread sleepForTimeInterval:2.0];
        }
        
        // Clean up
        for (int i = 0; i < argc; i++) free(argv[i]);
        free(argv);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(result);
        });
    });
}

@end
