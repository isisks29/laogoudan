// TweakUI.m — 全新重写版（参考 juzihub 方式）
#import <UIKit/UIKit.h>
#import "TweakUI.h"
#import "../Config.h"
#import "../MacroManager.h"

#define COLOR_BG [UIColor colorWithWhite:0.12 alpha:0.95]
#define COLOR_TEXT [UIColor whiteColor]
#define COLOR_ACCENT [UIColor colorWithRed:0.25 green:0.55 blue:1.0 alpha:1.0]

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
// 自定义 PassThroughWindow，让触摸事件穿透
@interface PassThroughWindow : UIWindow
@end
@implementation PassThroughWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *view = [super hitTest:point withEvent:event];
    if (view == self) return nil;
    return view;
}
@end

- (void)setupUI {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.floatWindow) return;
        
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
        if (!keyScene) return;
        
        // 用 PassThroughWindow 创建（触摸事件穿透）
        self.floatWindow = [[PassThroughWindow alloc] initWithWindowScene:keyScene];
        self.floatWindow.frame = keyScene.coordinateSpace.bounds;
        self.floatWindow.windowLevel = UIWindowLevelAlert + 100;
        self.floatWindow.backgroundColor = [UIColor clearColor];
        self.floatWindow.hidden = NO;
        
        // 悬浮球
        self.floatButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.floatButton.frame = CGRectMake(20, 100, 50, 50);
        self.floatButton.backgroundColor = COLOR_ACCENT;
        self.floatButton.layer.cornerRadius = 25;
        [self.floatButton setTitle:@"⚙" forState:UIControlStateNormal];
        self.floatButton.titleLabel.font = [UIFont systemFontOfSize:22];
        [self.floatButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
        [self.floatWindow addSubview:self.floatButton];
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragFloat:)];
        [self.floatButton addGestureRecognizer:pan];
        
        [self setupMenu];
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
    
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(w - 40, 8, 32, 32);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [closeBtn addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.menuView addSubview:closeBtn];
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 10, w - 80, 32)];
    title.text = @"GameTweak";
    title.textColor = COLOR_TEXT;
    title.font = [UIFont boldSystemFontOfSize:18];
    [self.menuView addSubview:title];
    
    CGFloat y = 60;
    
    // 调试模式
    UISwitch *sw1 = [[UISwitch alloc] initWithFrame:CGRectMake(20, y, 51, 31)];
    sw1.on = [GlobalConfig shared].debugMode;
    [sw1 addTarget:self action:@selector(debugSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuView addSubview:sw1];
    UILabel *l1 = [[UILabel alloc] initWithFrame:CGRectMake(85, y, 220, 31)];
    l1.text = @"调试模式（可拖动宏按钮）";
    l1.textColor = COLOR_TEXT;
    l1.font = [UIFont systemFontOfSize:14];
    [self.menuView addSubview:l1];
    y += 50;
    
    // 16分宏
    UISwitch *sw2 = [[UISwitch alloc] initWithFrame:CGRectMake(20, y, 51, 31)];
    sw2.on = [GlobalConfig shared].shiliufen.enabled;
    [sw2 addTarget:self action:@selector(shiliufenSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuView addSubview:sw2];
    UILabel *l2 = [[UILabel alloc] initWithFrame:CGRectMake(85, y, 220, 31)];
    l2.text = @"16分宏";
    l2.textColor = COLOR_TEXT;
    l2.font = [UIFont systemFontOfSize:14];
    [self.menuView addSubview:l2];
    y += 50;
    
    // 吐球宏
    UISwitch *sw3 = [[UISwitch alloc] initWithFrame:CGRectMake(20, y, 51, 31)];
    sw3.on = [GlobalConfig shared].tuqiu.enabled;
    [sw3 addTarget:self action:@selector(tuqiuSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuView addSubview:sw3];
    UILabel *l3 = [[UILabel alloc] initWithFrame:CGRectMake(85, y, 220, 31)];
    l3.text = @"吐球宏";
    l3.textColor = COLOR_TEXT;
    l3.font = [UIFont systemFontOfSize:14];
    [self.menuView addSubview:l3];
    y += 50;
    
    // 4分宏
    UISwitch *sw4 = [[UISwitch alloc] initWithFrame:CGRectMake(20, y, 51, 31)];
    sw4.on = [GlobalConfig shared].sifen.enabled;
    [sw4 addTarget:self action:@selector(sifenSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuView addSubview:sw4];
    UILabel *l4 = [[UILabel alloc] initWithFrame:CGRectMake(85, y, 220, 31)];
    l4.text = @"4分宏";
    l4.textColor = COLOR_TEXT;
    l4.font = [UIFont systemFontOfSize:14];
    [self.menuView addSubview:l4];
}

- (void)debugSwitchChanged:(UISwitch *)sw {
    [GlobalConfig shared].debugMode = sw.on;
    [[GlobalConfig shared] save];
}

- (void)shiliufenSwitchChanged:(UISwitch *)sw {
    MacroConfig mc = [GlobalConfig shared].shiliufen;
    mc.enabled = sw.on;
    [GlobalConfig shared].shiliufen = mc;
    [[GlobalConfig shared] save];
    [[MacroManager shared] updateButtonPositions];
}

- (void)tuqiuSwitchChanged:(UISwitch *)sw {
    MacroConfig mc = [GlobalConfig shared].tuqiu;
    mc.enabled = sw.on;
    [GlobalConfig shared].tuqiu = mc;
    [[GlobalConfig shared] save];
    [[MacroManager shared] updateButtonPositions];
}

- (void)sifenSwitchChanged:(UISwitch *)sw {
    MacroConfig mc = [GlobalConfig shared].sifen;
    mc.enabled = sw.on;
    [GlobalConfig shared].sifen = mc;
    [[GlobalConfig shared] save];
    [[MacroManager shared] updateButtonPositions];
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
