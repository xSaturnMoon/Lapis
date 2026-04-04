#ifndef ios_uikit_bridge_h
#define ios_uikit_bridge_h

#import <UIKit/UIKit.h>

void showDialog(NSString* title, NSString* message);
void UIKit_returnToSplitView(void);
UIViewController *currentVC(void);

#endif /* ios_uikit_bridge_h */
