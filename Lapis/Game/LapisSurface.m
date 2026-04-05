#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static UIWindow *gameWindow = nil;

void LapisSurface_show(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gameWindow) return;
        UIWindowScene *scene = (UIWindowScene *)
            [UIApplication.sharedApplication.connectedScenes anyObject];
        gameWindow = [[UIWindow alloc] initWithWindowScene:scene];
        gameWindow.frame = UIScreen.mainScreen.bounds;
        gameWindow.backgroundColor = UIColor.blackColor;
        gameWindow.windowLevel = UIWindowLevelNormal + 1;
        gameWindow.hidden = NO;
        [gameWindow makeKeyAndVisible];
        NSLog(@"[Lapis:Surface] Game window created");
    });
}

void LapisSurface_hide(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        gameWindow.hidden = YES;
        gameWindow = nil;
    });
}
