#import "LauncherBridge.h"
#import <dlfcn.h>

typedef int (*JavaLauncherMainFunc)(int argc, char **argv);

@implementation LauncherBridge

void appendLogToLaunchFile(NSString *message) {
    NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *logPath = [docs stringByAppendingPathComponent:@"Lapis/launch.log"];
    
    // Ensure directory exists
    [[NSFileManager defaultManager] createDirectoryAtPath:[logPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSString *timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterLongStyle];
    NSString *fullMessage = [NSString NS_FORMAT:@"[%@] %@\n", timestamp, message];
    
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:logPath];
    if (handle) {
        [handle seekToEndOfFile];
        [handle writeData:[fullMessage dataUsingEncoding:NSUTF8StringEncoding]];
        [handle closeFile];
    } else {
        [fullMessage writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    NSLog(@"[LapisBridgeLog] %@", message);
}

+ (void)launchWithArgs:(NSArray<NSString *> *)args completion:(void(^)(int exitCode))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        appendLogToLaunchFile(@"--- Launch Sequence Started ---");
        
        // 1. Force load essential frameworks to expose symbols
        NSString *frameworkPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Frameworks"];
        NSArray *fwNames = @[@"AltKit.framework/AltKit", @"CAltKit.framework/CAltKit", @"libGLESv2.framework/libGLESv2", @"libEGL.framework/libEGL"];
        
        for (NSString *fw in fwNames) {
            NSString *fullPath = [frameworkPath stringByAppendingPathComponent:fw];
            void *fwHandle = dlopen([fullPath UTF8String], RTLD_NOW | RTLD_GLOBAL);
            if (fwHandle) {
                appendLogToLaunchFile([NSString NS_FORMAT:@"Successfully pre-loaded: %@", fw]);
            } else {
                appendLogToLaunchFile([NSString NS_FORMAT:@"Warning: Could not pre-load %@: %s", fw, dlerror()]);
            }
        }

        // 2. Search for entry point symbol
        void *handle = RTLD_DEFAULT;
        JavaLauncherMainFunc func = NULL;
        
        NSArray *symbolNames = @[@"JavaLauncher_main", @"AmethystLauncher_main", @"main_java", @"amethyst_main", @"main"];
        for (NSString *symName in symbolNames) {
            func = (JavaLauncherMainFunc)dlsym(handle, [symName UTF8String]);
            if (func) {
                appendLogToLaunchFile([NSString NS_FORMAT:@"Found entry point: %@", symName]);
                break;
            }
        }
        
        if (!func) {
            appendLogToLaunchFile([NSString NS_FORMAT:@"FATAL: All entry points failed. Last error: %s", dlerror()]);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(-2);
            });
            return;
        }
        
        // 3. Setup JAVA_HOME correctly
        NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
        NSString *jrePath = [bundlePath stringByAppendingPathComponent:@"runtime"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:jrePath]) {
            jrePath = [bundlePath stringByAppendingPathComponent:@"java_runtimes"];
        }
        setenv("JAVA_HOME", [jrePath UTF8String], 1);
        appendLogToLaunchFile([NSString NS_FORMAT:@"JAVA_HOME set to: %@", jrePath]);
        
        int argc = (int)args.count;
        char **argv = malloc(sizeof(char *) * (argc + 1));
        for (int i = 0; i < argc; i++) {
            argv[i] = strdup([args[i] UTF8String]);
        }
        argv[argc] = NULL;
        
        setenv("PRINT_ALL_EXCEPTIONS", "1", 1);
        setenv("JLI_SEP", ":", 1);
        
        appendLogToLaunchFile(@"REACHING POINT OF NO RETURN: Calling engine main...");
        int result = func(argc, argv);
        appendLogToLaunchFile([NSString NS_FORMAT:@"Engine terminated with Code: %d", result]);
        
        for (int i = 0; i < argc; i++) free(argv[i]);
        free(argv);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(result);
        });
    });
}

@end
