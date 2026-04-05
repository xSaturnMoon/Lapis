#import <UIKit/UIKit.h>

#import "customcontrols/ControlLayout.h"
#import "GameSurfaceView.h"

CGRect virtualMouseFrame;
CGPoint lastVirtualMousePoint;

@interface SurfaceViewController : UIViewController

@property(nonatomic) ControlLayout *ctrlView;
@property(nonatomic) GameSurfaceView* surfaceView;
@property(nonatomic) UIView *touchView;
@property UIImageView* mousePointerView;
@property(nonatomic) UIPanGestureRecognizer* scrollPanGesture;

@property(nonatomic, strong) NSString *username;
@property(nonatomic, strong) NSArray<NSString *> *jvmArgs;

- (instancetype)initWithArgs:(NSArray<NSString *> *)args username:(NSString *)username;
- (void)sendTouchPoint:(CGPoint)location withEvent:(int)event;
- (void)updateSavedResolution;
- (void)updateGrabState;

+ (GameSurfaceView *)surface;
+ (BOOL)isRunning;

@end
