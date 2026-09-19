// TweakUI.m — 完整 UI（支持下滑 + 滑条整数显示）
#import "TweakUI.h"
#import "../Config.h"
#import "../MacroManager.h"
#import <UIKit/UIKit.h>

#define COLOR_BG [UIColor colorWithRed:0.1 green:0.1 blue:0.12 alpha:0.95]
#define COLOR_TEXT [UIColor whiteColor]
#define COLOR_ACCENT [UIColor colorWithRed:0.4 green:0.8 blue:1.0 alpha:1.0]

@interface PassThroughWindow : UIWindow
@end

@implementation PassThroughWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *view = [super hitTest:point withEvent:event];
    if (view == self) {
        return nil;
    }
    return view;
}
@end

@interface TweakUI ()
@property (strong, nonatomic) PassThroughWindow *window;
@property (strong, nonatomic) UIButton *floatButton;
@property (strong, nonatomic) UIScrollView *menuScrollView;
@property (strong, nonatomic) UIView *menuView;
@property (assign, nonatomic) BOOL isMenuOpen;
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
        if (self.window) return;
        
        // 获取 keyWindowScene
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
        
        // 创建悬浮球窗口
        self.window = [[PassThroughWindow alloc] initWithWindowScene:keyScene];
        self.window.frame = keyScene.coordinateSpace.bounds;
        self.window.windowLevel = UIWindowLevelAlert + 100;
        self.window.backgroundColor = [UIColor clearColor];
        self.window.hidden = NO;
        
        // 悬浮球
        self.floatButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.floatButton.frame = CGRectMake(20, 100, 50, 50);
        self.floatButton.backgroundColor = COLOR_ACCENT;
        self.floatButton.layer.cornerRadius = 25;
        [self.floatButton setTitle:@"⚙" forState:UIControlStateNormal];
        self.floatButton.titleLabel.font = [UIFont systemFontOfSize:22];
        [self.floatButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
        [self.window addSubview:self.floatButton];
        
        // 拖动手势
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragFloat:)];
        [self.floatButton addGestureRecognizer:pan];
        
        // 创建菜单
        [self setupMenu];
        
        // 挂载宏按钮
        [[MacroManager shared] setupMacroButtonsInWindow:self.window];
        
        NSLog(@"[TweakUI] UI setup complete!");
    });
}

- (void)setupMenu {
    CGFloat w = MIN([UIScreen mainScreen].bounds.size.width - 40, 340);
    CGFloat h = MIN([UIScreen mainScreen].bounds.size.height - 120, 520);
    
    // 菜单滚动视图
    self.menuScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(20, 80, w, h)];
    self.menuScrollView.backgroundColor = COLOR_BG;
    self.menuScrollView.layer.cornerRadius = 14;
    self.menuScrollView.hidden = YES;
    self.menuScrollView.showsVerticalScrollIndicator = YES;
    [self.window addSubview:self.menuScrollView];
    
    // 菜单内容视图
    self.menuView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 1000)];
    [self.menuScrollView addSubview:self.menuView];
    
    CGFloat y = 20;
    CGFloat contentW = w - 40;
    
    // 标题
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, y, contentW, 30)];
    title.text = @"GameTweak";
    title.textColor = COLOR_TEXT;
    title.font = [UIFont boldSystemFontOfSize:20];
    title.textAlignment = NSTextAlignmentCenter;
    [self.menuView addSubview:title];
    y += 50;
    
    // 关闭按钮
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(w - 40, 8, 32, 32);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [closeBtn addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.menuScrollView addSubview:closeBtn];
    
    // === 调试模式 ===
    UISwitch *debugSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(20, y, 51, 31)];
    debugSwitch.on = [GlobalConfig shared].debugMode;
    [debugSwitch addTarget:self action:@selector(debugSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuView addSubview:debugSwitch];
    UILabel *debugLabel = [[UILabel alloc] initWithFrame:CGRectMake(85, y, contentW - 80, 31)];
    debugLabel.text = @"调试模式（可拖动宏）";
    debugLabel.textColor = COLOR_TEXT;
    debugLabel.font = [UIFont systemFontOfSize:16];
    [self.menuView addSubview:debugLabel];
    y += 50;
    
    // === 16分宏 ===
    UISwitch *sw16 = [[UISwitch alloc] initWithFrame:CGRectMake(20, y, 51, 31)];
    sw16.on = [GlobalConfig shared].shiliufen.enabled;
    [sw16 addTarget:self action:@selector(shiliufenSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuView addSubview:sw16];
    UILabel *l16 = [[UILabel alloc] initWithFrame:CGRectMake(85, y, contentW - 80, 31)];
    l16.text = @"16分宏";
    l16.textColor = COLOR_TEXT;
    l16.font = [UIFont boldSystemFontOfSize:16];
    [self.menuView addSubview:l16];
    y += 45;
    
    // 16分 - 按钮大小滑条
    UILabel *s16SzLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 100, 25)];
    s16SzLabel.text = @"按钮大小";
    s16SzLabel.textColor = COLOR_TEXT;
    s16SzLabel.font = [UIFont systemFontOfSize:13];
    [self.menuView addSubview:s16SzLabel];
    UILabel *s16SzValue = [[UILabel alloc] initWithFrame:CGRectMake(contentW - 60, y, 60, 25)];
    s16SzValue.text = [NSString stringWithFormat:@"%.0f", [GlobalConfig shared].shiliufen.buttonSize];
    s16SzValue.textColor = COLOR_ACCENT;
    s16SzValue.font = [UIFont systemFontOfSize:13];
    s16SzValue.textAlignment = NSTextAlignmentRight;
    [self.menuView addSubview:s16SzValue];
    UISlider *s16SzSlider = [[UISlider alloc] initWithFrame:CGRectMake(130, y + 2, contentW - 190, 25)];
    s16SzSlider.minimumValue = 20;
    s16SzSlider.maximumValue = 160;
    s16SzSlider.value = [GlobalConfig shared].shiliufen.buttonSize;
    s16SzSlider.tag = 100;
    [s16SzSlider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuView addSubview:s16SzSlider];
    y += 35;
    
    // 16分 - 按压时长滑条
    UILabel *s16PressLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 100, 25)];
    s16PressLabel.text = @"按压时长(ms)";
    s16PressLabel.textColor = COLOR_TEXT;
    s16PressLabel.font = [UIFont systemFontOfSize:13];
    [self.menuView addSubview:s16PressLabel];
    UILabel *s16PressValue = [[UILabel alloc] initWithFrame:CGRectMake(contentW - 60, y, 60, 25)];
    s16PressValue.text = [NSString stringWithFormat:@"%.0f", [GlobalConfig shared].shiliufen.pressDuration];
    s16PressValue.textColor = COLOR_ACCENT;
    s16PressValue.font = [UIFont systemFontOfSize:13];
    s16PressValue.textAlignment = NSTextAlignmentRight;
    [self.menuView addSubview:s16PressValue];
    UISlider *s16PressSlider = [[UISlider alloc] initWithFrame:CGRectMake(130, y + 2, contentW - 190, 25)];
    s16PressSlider.minimumValue = 5;
    s16PressSlider.maximumValue = 100;
    s16PressSlider.value = [GlobalConfig shared].shiliufen.pressDuration;
    s16PressSlider.tag = 101;
    [s16PressSlider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuView addSubview:s16PressSlider];
    y += 35;
    
    // 16分 - 间隔滑条
    UILabel *s16IntLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 100, 25)];
    s16IntLabel.text = @"间隔(ms)";
    s16IntLabel.textColor = COLOR_TEXT;
    s16IntLabel.font = [UIFont systemFontOfSize:13];
    [self.menuView addSubview:s16IntLabel];
    UILabel *s16IntValue = [[UILabel alloc] initWithFrame:CGRectMake(contentW - 60, y, 60, 25)];
    s16IntValue.text = [NSString stringWithFormat:@"%.0f", [GlobalConfig shared].shiliufen.interval];
    s16IntValue.textColor = COLOR_ACCENT;
    s16IntValue.font = [UIFont systemFontOfSize:13];
    s16IntValue.textAlignment = NSTextAlignmentRight;
    [self.menuView addSubview:s16IntValue];
    UISlider *s16IntSlider = [[UISlider alloc] initWithFrame:CGRectMake(130, y + 2, contentW - 190, 25)];
    s16IntSlider.minimumValue = 5;
    s16IntSlider.maximumValue = 100;
    s16IntSlider.value = [GlobalConfig shared].shiliufen.interval;
    s16IntSlider.tag = 102;
    [s16IntSlider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuView addSubview:s16IntSlider];
    y += 50;
    
    // === 吐球宏 ===
    UISwitch *swTQ = [[UISwitch alloc] initWithFrame:CGRectMake(20, y, 51, 31)];
    swTQ.on = [GlobalConfig shared].tuqiu.enabled;
    [swTQ addTarget:self action:@selector(tuqiuSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuView addSubview:swTQ];
    UILabel *lTQ = [[UILabel alloc] initWithFrame:CGRectMake(85, y, contentW - 80, 31)];
    lTQ.text = @"吐球宏";
    lTQ.textColor = COLOR_TEXT;
    lTQ.font = [UIFont boldSystemFontOfSize:16];
    [self.menuView addSubview:lTQ];
    y += 45;
    
    // 吐球 - 按钮大小滑条
    UILabel *tqSzLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 100, 25)];
    tqSzLabel.text = @"按钮大小";
    tqSzLabel.textColor = COLOR_TEXT;
    tqSzLabel.font = [UIFont systemFontOfSize:13];
    [self.menuView addSubview:tqSzLabel];
    UILabel *tqSzValue = [[UILabel alloc] initWithFrame:CGRectMake(contentW - 60, y, 60, 25)];
    tqSzValue.text = [NSString stringWithFormat:@"%.0f", [GlobalConfig shared].tuqiu.buttonSize];
    tqSzValue.textColor = COLOR_ACCENT;
    tqSzValue.font = [UIFont systemFontOfSize:13];
    tqSzValue.textAlignment = NSTextAlignmentRight;
    [self.menuView addSubview:tqSzValue];
    UISlider *tqSzSlider = [[UISlider alloc] initWithFrame:CGRectMake(130, y + 2, contentW - 190, 25)];
    tqSzSlider.minimumValue = 20;
    tqSzSlider.maximumValue = 160;
    tqSzSlider.value = [GlobalConfig shared].tuqiu.buttonSize;
    tqSzSlider.tag = 200;
    [tqSzSlider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuView addSubview:tqSzSlider];
    y += 35;
    
    // 吐球 - 按压时长滑条
    UILabel *tqPressLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 100, 25)];
    tqPressLabel.text = @"按压时长(ms)";
    tqPressLabel.textColor = COLOR_TEXT;
    tqPressLabel.font = [UIFont systemFontOfSize:13];
    [self.menuView addSubview:tqPressLabel];
    UILabel *tqPressValue = [[UILabel alloc] initWithFrame:CGRectMake(contentW - 60, y, 60, 25)];
    tqPressValue.text = [NSString stringWithFormat:@"%.0f", [GlobalConfig shared].tuqiu.pressDuration];
    tqPressValue.textColor = COLOR_ACCENT;
    tqPressValue.font = [UIFont systemFontOfSize:13];
    tqPressValue.textAlignment = NSTextAlignmentRight;
    [self.menuView addSubview:tqPressValue];
    UISlider *tqPressSlider = [[UISlider alloc] initWithFrame:CGRectMake(130, y + 2, contentW - 190, 25)];
    tqPressSlider.minimumValue = 5;
    tqPressSlider.maximumValue = 100;
    tqPressSlider.value = [GlobalConfig shared].tuqiu.pressDuration;
    tqPressSlider.tag = 201;
    [tqPressSlider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuView addSubview:tqPressSlider];
    y += 35;
    
    // 吐球 - 间隔滑条
    UILabel *tqIntLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 100, 25)];
    tqIntLabel.text = @"间隔(ms)";
    tqIntLabel.textColor = COLOR_TEXT;
    tqIntLabel.font = [UIFont systemFontOfSize:13];
    [self.menuView addSubview:tqIntLabel];
    UILabel *tqIntValue = [[UILabel alloc] initWithFrame:CGRectMake(contentW - 60, y, 60, 25)];
    tqIntValue.text = [NSString stringWithFormat:@"%.0f", [GlobalConfig shared].tuqiu.interval];
    tqIntValue.textColor = COLOR_ACCENT;
    tqIntValue.font = [UIFont systemFontOfSize:13];
    tqIntValue.textAlignment = NSTextAlignmentRight;
    [self.menuView addSubview:tqIntValue];
    UISlider *tqIntSlider = [[UISlider alloc] initWithFrame:CGRectMake(130, y + 2, contentW - 190, 25)];
    tqIntSlider.minimumValue = 5;
    tqIntSlider.maximumValue = 100;
    tqIntSlider.value = [GlobalConfig shared].tuqiu.interval;
    tqIntSlider.tag = 202;
    [tqIntSlider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuView addSubview:tqIntSlider];
    y += 50;
    
    // === 4分宏 ===
    UISwitch *sw4 = [[UISwitch alloc] initWithFrame:CGRectMake(20, y, 51, 31)];
    sw4.on = [GlobalConfig shared].sifen.enabled;
    [sw4 addTarget:self action:@selector(sifenSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuView addSubview:sw4];
    UILabel *l4 = [[UILabel alloc] initWithFrame:CGRectMake(85, y, contentW - 80, 31)];
    l4.text = @"4分宏";
    l4.textColor = COLOR_TEXT;
    l4.font = [UIFont boldSystemFontOfSize:16];
    [self.menuView addSubview:l4];
    y += 45;
    
    // 4分 - 按钮大小滑条
    UILabel *s4SzLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 100, 25)];
    s4SzLabel.text = @"按钮大小";
    s4SzLabel.textColor = COLOR_TEXT;
    s4SzLabel.font = [UIFont systemFontOfSize:13];
    [self.menuView addSubview:s4SzLabel];
    UILabel *s4SzValue = [[UILabel alloc] initWithFrame:CGRectMake(contentW - 60, y, 60, 25)];
    s4SzValue.text = [NSString stringWithFormat:@"%.0f", [GlobalConfig shared].sifen.buttonSize];
    s4SzValue.textColor = COLOR_ACCENT;
    s4SzValue.font = [UIFont systemFontOfSize:13];
    s4SzValue.textAlignment = NSTextAlignmentRight;
    [self.menuView addSubview:s4SzValue];
    UISlider *s4SzSlider = [[UISlider alloc] initWithFrame:CGRectMake(130, y + 2, contentW - 190, 25)];
    s4SzSlider.minimumValue = 20;
    s4SzSlider.maximumValue = 160;
    s4SzSlider.value = [GlobalConfig shared].sifen.buttonSize;
    s4SzSlider.tag = 300;
    [s4SzSlider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuView addSubview:s4SzSlider];
    y += 35;
    
    // 4分 - 按压时长滑条
    UILabel *s4PressLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 100, 25)];
    s4PressLabel.text = @"按压时长(ms)";
    s4PressLabel.textColor = COLOR_TEXT;
    s4PressLabel.font = [UIFont systemFontOfSize:13];
    [self.menuView addSubview:s4PressLabel];
    UILabel *s4PressValue = [[UILabel alloc] initWithFrame:CGRectMake(contentW - 60, y, 60, 25)];
    s4PressValue.text = [NSString stringWithFormat:@"%.0f", [GlobalConfig shared].sifen.pressDuration];
    s4PressValue.textColor = COLOR_ACCENT;
    s4PressValue.font = [UIFont systemFontOfSize:13];
    s4PressValue.textAlignment = NSTextAlignmentRight;
    [self.menuView addSubview:s4PressValue];
    UISlider *s4PressSlider = [[UISlider alloc] initWithFrame:CGRectMake(130, y + 2, contentW - 190, 25)];
    s4PressSlider.minimumValue = 5;
    s4PressSlider.maximumValue = 100;
    s4PressSlider.value = [GlobalConfig shared].sifen.pressDuration;
    s4PressSlider.tag = 301;
    [s4PressSlider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuView addSubview:s4PressSlider];
    y += 35;
    
    // 4分 - 间隔滑条
    UILabel *s4IntLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 100, 25)];
    s4IntLabel.text = @"间隔(ms)";
    s4IntLabel.textColor = COLOR_TEXT;
    s4IntLabel.font = [UIFont systemFontOfSize:13];
    [self.menuView addSubview:s4IntLabel];
    UILabel *s4IntValue = [[UILabel alloc] initWithFrame:CGRectMake(contentW - 60, y, 60, 25)];
    s4IntValue.text = [NSString stringWithFormat:@"%.0f", [GlobalConfig shared].sifen.interval];
    s4IntValue.textColor = COLOR_ACCENT;
    s4IntValue.font = [UIFont systemFontOfSize:13];
    s4IntValue.textAlignment = NSTextAlignmentRight;
    [self.menuView addSubview:s4IntValue];
    UISlider *s4IntSlider = [[UISlider alloc] initWithFrame:CGRectMake(130, y + 2, contentW - 190, 25)];
    s4IntSlider.minimumValue = 5;
    s4IntSlider.maximumValue = 100;
    s4IntSlider.value = [GlobalConfig shared].sifen.interval;
    s4IntSlider.tag = 302;
    [s4IntSlider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuView addSubview:s4IntSlider];
    y += 50;
    
    // 设置滚动视图内容大小
    self.menuScrollView.contentSize = CGSizeMake(w, y + 20);
}

#pragma mark - Actions

- (void)toggleMenu {
    self.isMenuOpen = !self.isMenuOpen;
    self.menuScrollView.hidden = !self.isMenuOpen;
    [[MacroManager shared] setMacroButtonsHidden:!self.isMenuOpen];
}

- (void)closeMenu {
    if (self.isMenuOpen) [self toggleMenu];
}

- (void)dragFloat:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.window];
    pan.view.center = CGPointMake(pan.view.center.x + translation.x, pan.view.center.y + translation.y);
    [pan setTranslation:CGPointZero inView:self.window];
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

- (void)sliderChanged:(UISlider *)slider {
    // 更新右侧数值标签
    UILabel *valueLabel = nil;
    for (UIView *view in self.menuView.subviews) {
        if ([view isKindOfClass:[UILabel class]] && view.frame.origin.x > 200 && 
            fabs(view.frame.origin.y - slider.frame.origin.y) < 5) {
            valueLabel = (UILabel *)view;
            break;
        }
    }
    if (valueLabel) {
        valueLabel.text = [NSString stringWithFormat:@"%.0f", slider.value];
    }
    
    // 根据 tag 更新配置
    switch (slider.tag) {
        case 100: { // 16分 - 按钮大小
            MacroConfig mc = [GlobalConfig shared].shiliufen;
            mc.buttonSize = slider.value;
            [GlobalConfig shared].shiliufen = mc;
            break;
        }
        case 101: { // 16分 - 按压时长
            MacroConfig mc = [GlobalConfig shared].shiliufen;
            mc.pressDuration = slider.value;
            [GlobalConfig shared].shiliufen = mc;
            break;
        }
        case 102: { // 16分 - 间隔
            MacroConfig mc = [GlobalConfig shared].shiliufen;
            mc.interval = slider.value;
            [GlobalConfig shared].shiliufen = mc;
            break;
        }
        case 200: { // 吐球 - 按钮大小
            MacroConfig mc = [GlobalConfig shared].tuqiu;
            mc.buttonSize = slider.value;
            [GlobalConfig shared].tuqiu = mc;
            break;
        }
        case 201: { // 吐球 - 按压时长
            MacroConfig mc = [GlobalConfig shared].tuqiu;
            mc.pressDuration = slider.value;
            [GlobalConfig shared].tuqiu = mc;
            break;
        }
        case 202: { // 吐球 - 间隔
            MacroConfig mc = [GlobalConfig shared].tuqiu;
            mc.interval = slider.value;
            [GlobalConfig shared].tuqiu = mc;
            break;
        }
        case 300: { // 4分 - 按钮大小
            MacroConfig mc = [GlobalConfig shared].sifen;
            mc.buttonSize = slider.value;
            [GlobalConfig shared].sifen = mc;
            break;
        }
        case 301: { // 4分 - 按压时长
            MacroConfig mc = [GlobalConfig shared].sifen;
            mc.pressDuration = slider.value;
            [GlobalConfig shared].sifen = mc;
            break;
        }
        case 302: { // 4分 - 间隔
            MacroConfig mc = [GlobalConfig shared].sifen;
            mc.interval = slider.value;
            [GlobalConfig shared].sifen = mc;
            break;
        }
    }
    
    [[GlobalConfig shared] save];
    [[MacroManager shared] updateButtonPositions];
}

@end
