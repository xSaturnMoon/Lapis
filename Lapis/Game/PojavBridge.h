#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PojavBridge : NSObject

/// Launch the JVM with the given arguments
+ (int)launchJVMWithArgs:(NSArray<NSString *> *)args;

/// Set the Java home directory (path to JRE)
+ (void)setJavaHome:(NSString *)path;

/// Set the rendering mode (0=gl4es, 1=zink)
+ (void)setRenderer:(int)renderer;

/// Get the path to the JRE
+ (nullable NSString *)jrePath;

@end

NS_ASSUME_NONNULL_END
