#import "LauncherBridge.h"
#import <dlfcn.h>

typedef int (*JavaLauncherMainFunc)(int argc, char **argv);

@implementation LauncherBridge

void appendLogToLaunchFile(NSString *message) {
    NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *logPath = [docs stringByAppendingPathComponent:@"Lapis/launch.log"];

    [[NSFileManager defaultManager] createDirectoryAtPath:[logPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];

    NSString *timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterLongStyle];
    NSString *fullMessage = [NSString stringWithFormat:@"[%@] %@\n", timestamp, message];

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

        // 1. Tenta di caricare il framework PojavLauncher/Amethyst dal bundle.
        //    Senza di esso, nessun simbolo JavaLauncher_main esisterà nel processo.
        NSString *frameworkPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Frameworks"];

        // Framework di rendering (libGLESv2, libEGL) — necessari per OpenGL ES
        NSArray *renderFwNames = @[
            @"libGLESv2.framework/libGLESv2",
            @"libEGL.framework/libEGL"
        ];
        for (NSString *fw in renderFwNames) {
            NSString *fullPath = [frameworkPath stringByAppendingPathComponent:fw];
            void *fwHandle = dlopen([fullPath UTF8String], RTLD_NOW | RTLD_GLOBAL);
            if (fwHandle) {
                appendLogToLaunchFile([NSString stringWithFormat:@"Pre-loaded render framework: %@", fw]);
            } else {
                appendLogToLaunchFile([NSString stringWithFormat:@"Warning: Could not pre-load %@: %s", fw, dlerror()]);
            }
        }

        // Framework launcher — carica PojavLauncher o Amethyst per esporre JavaLauncher_main
        NSArray *launcherFwNames = @[
            @"PojavLauncher.framework/PojavLauncher",
            @"Amethyst.framework/Amethyst",
            @"liblauncher.dylib",
            @"AltKit.framework/AltKit",
            @"CAltKit.framework/CAltKit"
        ];
        for (NSString *fw in launcherFwNames) {
            NSString *fullPath = [frameworkPath stringByAppendingPathComponent:fw];
            void *fwHandle = dlopen([fullPath UTF8String], RTLD_NOW | RTLD_GLOBAL);
            if (fwHandle) {
                appendLogToLaunchFile([NSString stringWithFormat:@"Loaded launcher framework: %@", fw]);
            } else {
                appendLogToLaunchFile([NSString stringWithFormat:@"Info: %@ not found (%s)", fw, dlerror()]);
            }
        }

        // 2. Cerca il simbolo entry point del launcher Java.
        //    IMPORTANTE: "main" è stato RIMOSSO dalla lista.
        //    Usare @"main" come fallback chiamerebbe il main() dell'app stessa → crash garantito.
        void *handle = RTLD_DEFAULT;
        JavaLauncherMainFunc func = NULL;

        NSArray *symbolNames = @[
            @"JavaLauncher_main",
            @"AmethystLauncher_main",
            @"main_java",
            @"amethyst_main",
            @"pojav_launcher_main"
            // ← @"main" RIMOSSO: chiamare il main() dell'app iOS crasherebbe tutto
        ];

        for (NSString *symName in symbolNames) {
            func = (JavaLauncherMainFunc)dlsym(handle, [symName UTF8String]);
            if (func) {
                appendLogToLaunchFile([NSString stringWithFormat:@"Found entry point: %@", symName]);
                break;
            }
        }

        if (!func) {
            // Nessun entry point trovato: il framework PojavLauncher/Amethyst non è nel bundle.
            // Controlla che PojavLauncher.framework o Amethyst.framework siano in Lapis/Frameworks/
            // e che siano listati in project.yml sotto 'frameworks:' con embed: true.
            NSString *errMsg = [NSString stringWithFormat:
                @"FATAL: Nessun entry point Java trovato. "
                @"Assicurati che PojavLauncher.framework o Amethyst.framework "
                @"siano in Lapis/Frameworks/ e linkati in project.yml. "
                @"Last dlerror: %s", dlerror()];
            appendLogToLaunchFile(errMsg);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(-2);
            });
            return;
        }

        // 3. Setup JAVA_HOME
        NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
        NSString *jrePath = [bundlePath stringByAppendingPathComponent:@"runtime"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:jrePath]) {
            jrePath = [bundlePath stringByAppendingPathComponent:@"java_runtimes"];
        }
        if (![[NSFileManager defaultManager] fileExistsAtPath:jrePath]) {
            // Fallback: JRE nella cartella Documents/Lapis/jre
            NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
            jrePath = [docs stringByAppendingPathComponent:@"Lapis/jre"];
        }
        setenv("JAVA_HOME", [jrePath UTF8String], 1);
        appendLogToLaunchFile([NSString stringWithFormat:@"JAVA_HOME set to: %@", jrePath]);

        // 4. Converti args in argc/argv C
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
        appendLogToLaunchFile([NSString stringWithFormat:@"Engine terminated with Code: %d", result]);

        for (int i = 0; i < argc; i++) free(argv[i]);
        free(argv);

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(result);
        });
    });
}

@end
