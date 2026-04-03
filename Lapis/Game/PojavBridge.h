#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Bridge to PojavLauncher's JVM launching infrastructure
@interface PojavBridge : NSObject

/// Launch the JVM with the given arguments
/// @param args Array of JVM arguments including classpath, main class, and game args
/// @return Exit code (0 = success)
+ (int)launchJVMWithArgs:(NSArray<NSString *> *)args;

/// Set the Java home directory
+ (void)setJavaHome:(NSString *)path;

/// Set the rendering mode (0=gl4es, 1=zink)
+ (void)setRenderer:(int)renderer;

/// Get the path to the bundled JRE
+ (NSString *)jrePath;

/// Check if JIT is available
+ (BOOL)isJITAvailable;

/// Enable JIT compilation (required for performance)
+ (void)enableJIT;

@end

NS_ASSUME_NONNULL_END
