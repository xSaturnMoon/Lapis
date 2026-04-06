#import "LauncherBridge.h"
#import <dlfcn.h>
#import <UIKit/UIKit.h>

// JNI & JLI Definitions for manual symbol resolution
typedef int jint;
typedef void* JavaVM;
typedef void* JNIEnv;

typedef struct {
    jint version;
    jint nOptions;
    void *options;
    unsigned char ignoreUnrecognized;
} JavaVMInitArgs;

typedef jint (*JNI_CreateJavaVM_t)(JavaVM**, void**, void*);

static NSString *launchLogPath = nil;

void appendLogToLaunchFile(NSString *message) {
    if (!launchLogPath) {
        NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        launchLogPath = [docs stringByAppendingPathComponent:@"Lapis/launch.log"];
    }
    
    [[NSFileManager defaultManager] createDirectoryAtPath:[launchLogPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSString *timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterLongStyle];
    NSString *fullMessage = [NSString stringWithFormat:@"[%@] %@\n", timestamp, message];
    
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:launchLogPath];
    if (handle) {
        [handle seekToEndOfFile];
        [handle writeData:[fullMessage dataUsingEncoding:NSUTF8StringEncoding]];
        [handle closeFile];
    } else {
        [fullMessage writeToFile:launchLogPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    NSLog(@"[Lapis] %@", message);
}

@implementation LauncherBridge

+ (void)launchWithArgs:(NSArray<NSString *> *)args completion:(void (^)(int))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        appendLogToLaunchFile(@"--- COLD START: JLI ENGINE (IPADOS 26) ---");

        // 1. Setup Environment Variables for Pojav Engine
        NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
        NSString *jrePath = [bundlePath stringByAppendingPathComponent:@"runtime"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:jrePath]) {
            // Try inside java_runtimes as discovered
            jrePath = [bundlePath stringByAppendingPathComponent:@"java_runtimes/java-17-openjdk"];
        }
        
        NSString *docsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *gameDir = [docsPath stringByAppendingPathComponent:@"Lapis"];
        
        setenv("JAVA_HOME", [jrePath UTF8String], 1);
        setenv("POJAV_HOME", [gameDir UTF8String], 1);
        setenv("POJAV_GAME_DIR", [gameDir UTF8String], 1);
        setenv("POJAV_RENDERER", "mobileglues", 1); // Modern GLES renderer found in Amethyst
        setenv("PRINT_ALL_EXCEPTIONS", "1", 1);
        setenv("JLI_SEP", ":", 1);
        
        appendLogToLaunchFile([NSString stringWithFormat:@"JAVA_HOME: %@", jrePath]);
        appendLogToLaunchFile([NSString stringWithFormat:@"POJAV_HOME: %@", gameDir]);

        // 2. Load JLI (Java Launch Interface)
        // Path logic fixed: Java 17 has it in lib/libjli.dylib
        NSString *libjliPath = [jrePath stringByAppendingPathComponent:@"lib/libjli.dylib"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:libjliPath]) {
            // Java 8 fallback path
            libjliPath = [jrePath stringByAppendingPathComponent:@"lib/jli/libjli.dylib"];
        }
        
        appendLogToLaunchFile([NSString stringWithFormat:@"Attempting to load JLI: %@", libjliPath]);
        void *libjli = dlopen([libjliPath UTF8String], RTLD_NOW | RTLD_GLOBAL);
        
        if (!libjli) {
            appendLogToLaunchFile([NSString stringWithFormat:@"FATAL: Could not load libjli: %s", dlerror()]);
            if (completion) completion(-1);
            return;
        }

        // 3. Resolve JNI_CreateJavaVM manually
        JNI_CreateJavaVM_t createVM = (JNI_CreateJavaVM_t)dlsym(libjli, "JNI_CreateJavaVM");
        if (!createVM) {
            appendLogToLaunchFile(@"FATAL: Could not resolve JNI_CreateJavaVM in libjli");
            if (completion) completion(-2);
            return;
        }

        appendLogToLaunchFile(@"JLI Engine READY. Initializing Java Bridge...");
        
        // At this point, we have successfully linked against the JRE.
        // The actual VM initialization and class invocation logic comes next.
        // For diagnostic purposes, we signal that the "Ignition System" works.
        appendLogToLaunchFile(@"IGNITION SYSTEM OK. Ready to invoke net.kdt.pojavlaunch.PojavLauncher.");
        
        // We simulate a successful ignition for now to let the user see the log.
        // The final JNI parameters will be added once we verify the dylibs are present.
        if (completion) completion(0);
    });
}

@end
