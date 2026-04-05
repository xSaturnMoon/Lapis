#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 * LauncherBridge: Il punto di contatto con l'engine di PojavLauncher.
 * Si occupa di inizializzare la JVM e lanciare il main di Minecraft.
 */
@interface LauncherBridge : NSObject

+ (void)launchWithArgs:(NSArray<NSString *> *)args completion:(void(^)(int exitCode))completion;

@end
