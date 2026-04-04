#include <objc/runtime.h>
#include "ios_uikit_bridge.h"

UIViewController *currentVC(void) {
    UIWindow *window = UIApplication.sharedApplication.keyWindow;
    UIViewController *root = window.rootViewController;
    while (root.presentedViewController) {
        root = root.presentedViewController;
    }
    return root;
}

void internal_showDialog(NSString* title, NSString* message) {
    NSLog(@"[UI] Dialog shown: %@: %@", title, message);
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:title
        message:message
        preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    
    // We bind it directly to the keyWindow fallback
    [currentVC() presentViewController:alert animated:YES completion:nil];
}

void showDialog(NSString* title, NSString* message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        internal_showDialog(title, message);
    });
}

void UIKit_returnToSplitView(void) {
    // Basic Stub for Amethyst native bridge
    NSLog(@"UIKit_returnToSplitView called");
}
