// TweakUI.m — 全新重写版（参考 juzihub 方式）
#import <UIKit/UIKit.h>
#import "TweakUI.h"
#import "../Config.h"
#import "../MacroManager.h"

#define COLOR_BG [UIColor colorWithWhite:0.12 alpha:0.95]
#define COLOR_CELL [UIColor colorWithWhite:0.18 alpha:1.0]
#define COLOR_TEXT [UIColor whiteColor]
#define COLOR_ACCENT [UIColor colorWithRed:0.25 green:0.55 blue:1.0 alpha:1.0]

#pragma mark - 主 UI
@interface TweakUI ()
@property (strong) UIWindow *floatWindow;
@property (strong) UIButton *floatButton;
@property (strong) UIView *menuView;
@property (assign) BOOL menuOpen;
@end

@implementation TweakUI

+ (instancetype)shared {
    static TweakUI *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[TweakUI alloc] init]; });
    return instance;
}

+ (void)showFloatingWindow {
    [[TweakUI shared] setupUI];
}

- (void)setupUI {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.floatWindow) return;
        
        // iOS 13+ 正确方式：获取 keyWindowScene
        UIWindowScene *keyScene = nil;
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    keyScene = scene;
                    break;
                }
            }
        }
        
        if (!keyScene) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    keyScene = scene;
                    break;
                }
            }
        }
        
        if (!keyScene) {
            NSLog(@"[TweakUI] ERROR: No keyWindowScene!");
            return;
        }
        
        // 用 initWithWindowScene: 创建（iOS 13+ 正确方式）
        self.floatWindow = [[UIWindow alloc] initWithWindowScene:keyScene];
        self.floatWindow.frame = keyScene.coordinateSpace.bounds;
        self.floatWindow.windowLevel = UIWindowLevelAlert + 100;
        self.floatWindow.backgroundColor = [UIColor clearColor];
        self.floatWindow.hidden = NO;
        
        // 悬浮球按钮
        self.floatButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.floatButton.frame = CGRectMake(20, 100, 50, 50);
        self.floatButton.backgroundColor = COLOR_ACCENT;
        self.floatButton.layer.cornerRadius = 25;
        [self.floatButton setTitle:@"⚙" forState:UIControlStateNormal];
        self.floatButton.titleLabel.font = [UIFont systemFontOfSize:22];
        [self.floatButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
        [self.floatWindow addSubview:self.floatButton];
        
        // 拖动悬浮球
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragFloat:)];
        [self.floatButton addGestureRecognizer:pan];
        
        // 创建菜单
        [self setupMenu];
        
        // 挂载宏按钮
        [[MacroManager shared] setupMacroButtonsInWindow:self.floatWindow];
        
        NSLog(@"[TweakUI] UI setup complete!");
    });
}

- (void)setupMenu {
    CGFloat w = MIN([UIScreen mainScreen].bounds.size.width - 40, 340);
    CGFloat h = MIN([UIScreen mainScreen].bounds.size.height - 120, 520);
    
    self.menuView = [[UIView alloc] initWithFrame:CGRectMake(20, 80, w, h)];
    self.menuView.backgroundColor = COLOR_BG;
    self.menuView.layer.cornerRadius = 14;
    self.menuView.alpha = 0;
    [self.floatWindow addSubview:self.menuView];
    
    // 关闭按钮
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(w - 40, 8, 32, 32);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [closeBtn addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.menuView addSubview:closeBtn];
    
    // 标题
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 10, w - 80, 32)];
    title.text = @"GameTweak";
    title.textColor = COLOR_TEXT;
    title.font = [UIFont boldSystemFontOfSize:18];
    [self.menuView addSubview:title];
    
    // 简单的开关示例
    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(20, 60, 51, 31)];
    sw.on = [GlobalConfig shared].debugMode;
    [sw addTarget:self action:@selector(debugSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuView addSubview:sw];
    
    UILabel *swLabel = [[UILabel alloc] initWithFrame:CGRectMake(85, 60, 200, 31)];
    swLabel.text = @"调试模式（可拖动宏按钮）";
    swLabel.textColor = COLOR_TEXT;
    swLabel.font = [UIFont systemFontOfSize:14];
    [self.menuView addSubview:swLabel];
}

- (void)debugSwitchChanged:(UISwitch *)sw {
    [GlobalConfig shared].debugMode = sw.on;
    [[GlobalConfig shared] save];
}

- (void)toggleMenu {
    self.menuOpen = !self.menuOpen;
    [UIView animateWithDuration:0.25 animations:^{
        self.menuView.alpha = self.menuOpen ? 1.0 : 0.0;
    }];
}

- (void)closeMenu {
    if (self.menuOpen) [self toggleMenu];
}

- (void)dragFloat:(UIPanGestureRecognizer *)pan {
    CGPoint pt = [pan translationInView:self.floatWindow];
    CGPoint center = self.floatButton.center;
    center.x += pt.x;
    center.y += pt.y;
    self.floatButton.center = center;
    [pan setTranslation:CGPointZero inView:self.floatWindow];
}

@end
