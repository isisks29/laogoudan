#import <UIKit/UIKit.h>
#import "TweakUI.h"
#import "../Config.h"
#import "../MacroManager.h"
#import "../FeatureManager.h"
#import "../PeelManager.h"

#define COLOR_BG [UIColor colorWithWhite:0.12 alpha:0.95]
#define COLOR_CELL [UIColor colorWithWhite:0.18 alpha:1.0]
#define COLOR_TEXT [UIColor whiteColor]
#define COLOR_SUBTEXT [UIColor colorWithWhite:0.6 alpha:1.0]
#define COLOR_ACCENT [UIColor colorWithRed:0.25 green:0.55 blue:1.0 alpha:1.0]
#define COLOR_TEXT_DIM [UIColor colorWithWhite:0.6 alpha:1.0]

#pragma mark - 触屏穿透 Window
@interface PassThroughWindow : UIWindow
@end
@implementation PassThroughWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *view = [super hitTest:point withEvent:event];
    if (view == self) return nil;
    return view;
}
@end

#pragma mark - 开关行
@interface SwitchRow : UIView
@property (strong) UILabel *titleLabel;
@property (strong) UISwitch *switchCtrl;
@property (copy) void (^onChange)(BOOL on);
@end
@implementation SwitchRow
- (instancetype)initWithTitle:(NSString *)title {
    self = [super init];
    if (self) {
        self.backgroundColor = COLOR_CELL;
        self.layer.cornerRadius = 8;
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.text = title;
        _titleLabel.textColor = COLOR_TEXT;
        _titleLabel.font = [UIFont systemFontOfSize:14];
        [self addSubview:_titleLabel];
        _switchCtrl = [[UISwitch alloc] init];
        _switchCtrl.onTintColor = COLOR_ACCENT;
        [_switchCtrl addTarget:self action:@selector(changed) forControlEvents:UIControlEventValueChanged];
        [self addSubview:_switchCtrl];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    _titleLabel.frame = CGRectMake(14, 0, self.bounds.size.width - 80, self.bounds.size.height);
    _switchCtrl.center = CGPointMake(self.bounds.size.width - 40, self.bounds.size.height / 2);
}
- (void)changed { if (_onChange) _onChange(_switchCtrl.isOn); }
@end

#pragma mark - 滑块行
@interface SliderRow : UIView
@property (strong) UILabel *titleLabel;
@property (strong) UILabel *valueLabel;
@property (strong) UISlider *slider;
@property (copy) void (^onChange)(float value);
@end
@implementation SliderRow
- (instancetype)initWithTitle:(NSString *)title min:(float)min max:(float)max {
    self = [super init];
    if (self) {
        self.backgroundColor = COLOR_CELL;
        self.layer.cornerRadius = 8;
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.text = title;
        _titleLabel.textColor = COLOR_TEXT;
        _titleLabel.font = [UIFont systemFontOfSize:13];
        [self addSubview:_titleLabel];
        _valueLabel = [[UILabel alloc] init];
        _valueLabel.textColor = COLOR_ACCENT;
        _valueLabel.font = [UIFont boldSystemFontOfSize:13];
        _valueLabel.textAlignment = NSTextAlignmentRight;
        [self addSubview:_valueLabel];
        _slider = [[UISlider alloc] init];
        _slider.minimumValue = min;
        _slider.maximumValue = max;
        _slider.minimumTrackTintColor = COLOR_ACCENT;
        [_slider addTarget:self action:@selector(changed) forControlEvents:UIControlEventValueChanged];
        [self addSubview:_slider];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    _titleLabel.frame = CGRectMake(14, 8, self.bounds.size.width - 100, 18);
    _valueLabel.frame = CGRectMake(self.bounds.size.width - 80, 8, 66, 18);
    _slider.frame = CGRectMake(14, 28, self.bounds.size.width - 28, 30);
}
- (void)changed {
    _valueLabel.text = [NSString stringWithFormat:@"%.1f", _slider.value];
    if (_onChange) _onChange(_slider.value);
}
@end

#pragma mark - 数值输入行
@interface InputRow : UIView
@property (strong) UILabel *titleLabel;
@property (strong) UILabel *valueLabel;
@property (copy) void (^onInput)(NSString *value);
@property (strong) NSString *currentValue;
@end
@implementation InputRow
- (instancetype)initWithTitle:(NSString *)title value:(NSString *)value {
    self = [super init];
    if (self) {
        self.backgroundColor = COLOR_CELL;
        self.layer.cornerRadius = 8;
        self.userInteractionEnabled = YES;
        _currentValue = value;
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.text = title;
        _titleLabel.textColor = COLOR_TEXT;
        _titleLabel.font = [UIFont systemFontOfSize:13];
        [self addSubview:_titleLabel];
        _valueLabel = [[UILabel alloc] init];
        _valueLabel.text = value;
        _valueLabel.textColor = COLOR_ACCENT;
        _valueLabel.font = [UIFont boldSystemFontOfSize:13];
        _valueLabel.textAlignment = NSTextAlignmentRight;
        [self addSubview:_valueLabel];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showInput)];
        [self addGestureRecognizer:tap];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    _titleLabel.frame = CGRectMake(14, 0, self.bounds.size.width - 100, self.bounds.size.height);
    _valueLabel.frame = CGRectMake(self.bounds.size.width - 90, 0, 76, self.bounds.size.height);
}
- (void)showInput {
    UIViewController *rootVC = nil;
    // 优先用 delegate.window
    UIWindow *appWindow = [UIApplication sharedApplication].delegate.window;
    if (appWindow) rootVC = appWindow.rootViewController;
    // fallback：遍历 connectedScenes
    if (!rootVC) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                for (UIWindow *w in scene.windows) {
                    if (w.rootViewController && !w.hidden) { rootVC = w.rootViewController; break; }
                }
            }
        }
    }
    if (!rootVC) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:_titleLabel.text
                                                                       message:@"输入数值（支持小数）"
                                                                preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = _currentValue;
        tf.keyboardType = UIKeyboardTypeDecimalPad;
        tf.placeholder = @"输入数值";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *val = alert.textFields[0].text;
        if (val.length > 0) {
            _currentValue = val;
            _valueLabel.text = val;
            if (_onInput) _onInput(val);
        }
    }]];
    [rootVC presentViewController:alert animated:YES completion:nil];
}
@end

#pragma mark - 宏设置行
@interface MacroConfigRow : UIView
@property (strong) UILabel *titleLabel;
@property (strong) SliderRow *sizeSlider;
@property (strong) SliderRow *pressSlider;
@property (strong) SliderRow *intervalSlider;
@end
@implementation MacroConfigRow
- (instancetype)initWithTitle:(NSString *)title {
    self = [super init];
    if (self) {
        self.backgroundColor = COLOR_CELL;
        self.layer.cornerRadius = 8;
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.text = title;
        _titleLabel.textColor = COLOR_TEXT;
        _titleLabel.font = [UIFont boldSystemFontOfSize:15];
        [self addSubview:_titleLabel];
        _sizeSlider = [[SliderRow alloc] initWithTitle:@"按钮大小" min:20 max:80];
        [self addSubview:_sizeSlider];
        _pressSlider = [[SliderRow alloc] initWithTitle:@"单次时长(ms)" min:10 max:200];
        [self addSubview:_pressSlider];
        _intervalSlider = [[SliderRow alloc] initWithTitle:@"点击间隔(ms)" min:5 max:500];
        [self addSubview:_intervalSlider];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    _titleLabel.frame = CGRectMake(14, 10, w - 28, 20);
    _sizeSlider.frame = CGRectMake(10, 36, w - 20, 62);
    _pressSlider.frame = CGRectMake(10, 104, w - 20, 62);
    _intervalSlider.frame = CGRectMake(10, 172, w - 20, 62);
}
+ (CGFloat)rowHeight { return 242; }
@end

#pragma mark - 主 UI
@interface TweakUI () <UIScrollViewDelegate>
@property (strong) PassThroughWindow *floatWindow;
@property (strong) UIButton *floatButton;
@property (strong) UIView *overlayView;
@property (strong) UIView *menuView;
@property (strong) UIButton *closeButton;
@property (strong) UISegmentedControl *tabControl;
@property (strong) UIScrollView *scrollView;
@property (strong) NSMutableArray *tabViews;
@property (assign) BOOL menuOpen;
@end

@implementation TweakUI

- (void)showUI {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setupFloatButton];
        [self setupMenu];
    });
}

+ (void)showFloatingWindow {
    [[TweakUI shared] showUI];
}

+ (instancetype)shared {
    static TweakUI *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[TweakUI alloc] init]; });
    return instance;
}

- (void)setupFloatButton {
    if (self.floatWindow) return;

    self.floatWindow = [[PassThroughWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.floatWindow.windowLevel = UIWindowLevelAlert + 100;
    self.floatWindow.backgroundColor = [UIColor clearColor];
    self.floatWindow.hidden = NO;

    // 全屏遮罩（菜单打开时显示，拦截游戏触摸）
    self.overlayView = [[UIView alloc] initWithFrame:self.floatWindow.bounds];
    self.overlayView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
    self.overlayView.hidden = YES;
    [self.floatWindow addSubview:self.overlayView];

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

    // 挂载宏按钮到悬浮窗
    [[MacroManager shared] setupMacroButtonsInWindow:self.floatWindow];
}

- (void)dragFloat:(UIPanGestureRecognizer *)pan {
    CGPoint pt = [pan translationInView:self.floatWindow];
    CGPoint center = self.floatButton.center;
    center.x += pt.x;
    center.y += pt.y;
    self.floatButton.center = center;
    [pan setTranslation:CGPointZero inView:self.floatWindow];
}

- (void)toggleMenu {
    self.menuOpen = !self.menuOpen;
    self.overlayView.hidden = !self.menuOpen;
    self.menuView.userInteractionEnabled = self.menuOpen;
    [UIView animateWithDuration:0.25 animations:^{
        self.menuView.alpha = self.menuOpen ? 1.0 : 0.0;
        self.menuView.transform = self.menuOpen ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.9, 0.9);
    }];
    if (self.menuOpen) [self refresh];
    // 去掉了 setMacroButtonsHidden —— 宏按钮不随菜单隐藏
}

- (void)closeMenu {
    if (self.menuOpen) [self toggleMenu];
}

- (void)setupMenu {
    if (self.menuView) return;

    CGFloat w = MIN([UIScreen mainScreen].bounds.size.width - 40, 340);
    CGFloat h = MIN([UIScreen mainScreen].bounds.size.height - 120, 520);

    self.menuView = [[UIView alloc] initWithFrame:CGRectMake(20, 80, w, h)];
    self.menuView.userInteractionEnabled = NO;
    self.menuView.backgroundColor = COLOR_BG;
    self.menuView.layer.cornerRadius = 14;
    self.menuView.clipsToBounds = YES;
    self.menuView.alpha = 0;
    self.menuView.transform = CGAffineTransformMakeScale(0.9, 0.9);
    [self.floatWindow addSubview:self.menuView];

    // 右上角关闭按钮
    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.closeButton.frame = CGRectMake(w - 40, 8, 32, 32);
    [self.closeButton setTitle:@"✕" forState:UIControlStateNormal];
    [self.closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.closeButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.closeButton addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.menuView addSubview:self.closeButton];

    // 标签栏：功能 / 宏 / 美化
    self.tabControl = [[UISegmentedControl alloc] initWithItems:@[@"功能", @"宏", @"美化"]];
    self.tabControl.frame = CGRectMake(12, 12, w - 60, 32);
    self.tabControl.selectedSegmentIndex = 0;
    self.tabControl.tintColor = COLOR_ACCENT;
    [self.tabControl addTarget:self action:@selector(tabChanged) forControlEvents:UIControlEventValueChanged];
    [self.menuView addSubview:self.tabControl];

    // 横向分页滚动
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 52, w, h - 52)];
    self.scrollView.pagingEnabled = YES;
    self.scrollView.delegate = self;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.contentSize = CGSizeMake(w * 3, h - 52);
    [self.menuView addSubview:self.scrollView];

    self.tabViews = [NSMutableArray array];
    [self buildFeatureTab];
    [self buildMacroTab];
    [self buildBeautifyTab];
}

- (void)tabChanged {
    CGFloat w = self.scrollView.bounds.size.width;
    [UIView animateWithDuration:0.25 animations:^{
        self.scrollView.contentOffset = CGPointMake(w * self.tabControl.selectedSegmentIndex, 0);
    }];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    CGFloat w = scrollView.bounds.size.width;
    self.tabControl.selectedSegmentIndex = scrollView.contentOffset.x / w;
}

#pragma mark - 创建纵向滚动容器
- (UIScrollView *)createVerticalTabAtX:(CGFloat)x width:(CGFloat)w height:(CGFloat)h {
    UIScrollView *tab = [[UIScrollView alloc] initWithFrame:CGRectMake(x, 0, w, h)];
    tab.showsVerticalScrollIndicator = YES;
    tab.alwaysBounceVertical = YES;
    [self.scrollView addSubview:tab];
    [self.tabViews addObject:tab];
    return tab;
}

#pragma mark - 标签页1：功能
- (void)buildFeatureTab {
    CGFloat w = self.scrollView.bounds.size.width;
    CGFloat h = self.scrollView.bounds.size.height;
    UIScrollView *tab = [self createVerticalTabAtX:0 width:w height:h];

    GlobalConfig *cfg = [GlobalConfig shared];
    CGFloat y = 12;

    NSArray *features = @[
        @{@"title": @"双连点", @"key": @"shuangliandian"},
        @{@"title": @"解限", @"key": @"jielim"},
        @{@"title": @"灵敏", @"key": @"lingmin"},
        @{@"title": @"解断", @"key": @"jieduan"},
        @{@"title": @"名字大小", @"key": @"mingzidaxiao"},
        @{@"title": @"粘合", @"key": @"nianhe"},
        @{@"title": @"视野大小", @"key": @"shiyedaxiao"},
        @{@"title": @"球体内显", @"key": @"qiutineixian"},
        @{@"title": @"防录制", @"key": @"fangluzhi"},
        @{@"title": @"摇杆回弹", @"key": @"yaoganhuitan"},
    ];

    for (NSDictionary *f in features) {
        SwitchRow *row = [[SwitchRow alloc] initWithTitle:f[@"title"]];
        row.frame = CGRectMake(12, y, w - 24, 40);
        row.switchCtrl.on = [[cfg valueForKey:f[@"key"]] boolValue];
        NSString *key = f[@"key"];
        row.onChange = ^(BOOL on) {
            [cfg setValue:@(on) forKey:key];
            [cfg save];
            [[FeatureManager sharedManager] applyFeatures];
        };
        [tab addSubview:row];
        y += 46;
    }

    y += 8;
    NSArray *inputs = @[
        @{@"title": @"名字大小", @"key": @"mingziValue"},
        @{@"title": @"粘合大小", @"key": @"nianheValue"},
        @{@"title": @"视野大小", @"key": @"shiyeValue"},
        @{@"title": @"回弹数值", @"key": @"huitanValue"},
    ];

    for (NSDictionary *s in inputs) {
        NSString *val = [cfg valueForKey:s[@"key"]] ?: @"1.0";
        InputRow *row = [[InputRow alloc] initWithTitle:s[@"title"] value:val];
        row.frame = CGRectMake(12, y, w - 24, 40);
        NSString *key = s[@"key"];
        row.onInput = ^(NSString *value) {
            [cfg setValue:value forKey:key];
            [cfg save];
        };
        [tab addSubview:row];
        y += 46;
    }

    y += 8;
    UILabel *jlTitle = [[UILabel alloc] initWithFrame:CGRectMake(14, y, w - 28, 20)];
    jlTitle.text = @"解限高级配置";
    jlTitle.textColor = COLOR_TEXT_DIM;
    jlTitle.font = [UIFont systemFontOfSize:11];
    [tab addSubview:jlTitle];
    y += 26;

    InputRow *jlWrite = [[InputRow alloc] initWithTitle:@"写入值" value:cfg.jielimWriteValue];
    jlWrite.frame = CGRectMake(12, y, w - 24, 40);
    jlWrite.onInput = ^(NSString *value) { cfg.jielimWriteValue = value; [cfg save]; };
    [tab addSubview:jlWrite];
    y += 46;

    InputRow *jlSearch = [[InputRow alloc] initWithTitle:@"搜索值" value:cfg.jielimSearchValue];
    jlSearch.frame = CGRectMake(12, y, w - 24, 40);
    jlSearch.onInput = ^(NSString *value) { cfg.jielimSearchValue = value; [cfg save]; };
    [tab addSubview:jlSearch];
    y += 46;

    SwitchRow *jlType = [[SwitchRow alloc] initWithTitle:@"按int写入(关闭=float)"];
    jlType.frame = CGRectMake(12, y, w - 24, 40);
    jlType.switchCtrl.on = cfg.jielimWriteAsInt;
    jlType.onChange = ^(BOOL on) { cfg.jielimWriteAsInt = on; [cfg save]; };
    [tab addSubview:jlType];
    y += 56;

    tab.contentSize = CGSizeMake(w, y);
}

#pragma mark - 标签页2：宏
- (void)buildMacroTab {
    CGFloat w = self.scrollView.bounds.size.width;
    CGFloat h = self.scrollView.bounds.size.height;
    UIScrollView *tab = [self createVerticalTabAtX:w width:w height:h];

    GlobalConfig *cfg = [GlobalConfig shared];
    CGFloat y = 12;

    NSArray *macros = @[
        @{@"title": @"16分（按住循环）", @"config": @"shiliufen"},
        @{@"title": @"吐球（按住循环）", @"config": @"tuqiu"},
        @{@"title": @"4分（点击触发）", @"config": @"sifen"},
    ];

    for (NSDictionary *m in macros) {
        SwitchRow *sw = [[SwitchRow alloc] initWithTitle:m[@"title"]];
        sw.frame = CGRectMake(12, y, w - 24, 40);
        NSString *configKey = m[@"config"];
        NSValue *val = [cfg valueForKey:configKey];
        MacroConfig mc;
        if (val) [val getValue:&mc];
        sw.switchCtrl.on = mc.enabled;
        sw.onChange = ^(BOOL on) {
            NSValue *cv = [[GlobalConfig shared] valueForKey:configKey];
            MacroConfig c;
            if (cv) [cv getValue:&c];
            c.enabled = on;
            NSValue *vOut = [NSValue valueWithBytes:&c objCType:@encode(MacroConfig)];
            [[GlobalConfig shared] setValue:vOut forKey:configKey];
            [[GlobalConfig shared] save];
            [[MacroManager shared] updateButtonPositions];
        };
        [tab addSubview:sw];
        y += 48;

        MacroConfigRow *configRow = [[MacroConfigRow alloc] initWithTitle:@"参数设置"];
        configRow.frame = CGRectMake(12, y, w - 24, [MacroConfigRow rowHeight]);
        NSValue *val2 = [cfg valueForKey:configKey];
        MacroConfig current;
        if (val2) [val2 getValue:&current];
        configRow.sizeSlider.slider.value = current.buttonSize;
        configRow.sizeSlider.valueLabel.text = [NSString stringWithFormat:@"%.0f", current.buttonSize];
        configRow.pressSlider.slider.value = current.pressDuration;
        configRow.pressSlider.valueLabel.text = [NSString stringWithFormat:@"%.0f", current.pressDuration];
        configRow.intervalSlider.slider.value = current.interval;
        configRow.intervalSlider.valueLabel.text = [NSString stringWithFormat:@"%.0f", current.interval];

        configRow.sizeSlider.onChange = ^(float v) {
            NSValue *cv = [[GlobalConfig shared] valueForKey:configKey];
            MacroConfig c;
            if (cv) [cv getValue:&c];
            c.buttonSize = v;
            [[GlobalConfig shared] setValue:[NSValue valueWithBytes:&c objCType:@encode(MacroConfig)] forKey:configKey];
            [[GlobalConfig shared] save];
            [[MacroManager shared] updateButtonPositions];
        };
        configRow.pressSlider.onChange = ^(float v) {
            NSValue *cv = [[GlobalConfig shared] valueForKey:configKey];
            MacroConfig c;
            if (cv) [cv getValue:&c];
            c.pressDuration = v;
            [[GlobalConfig shared] setValue:[NSValue valueWithBytes:&c objCType:@encode(MacroConfig)] forKey:configKey];
            [[GlobalConfig shared] save];
        };
        configRow.intervalSlider.onChange = ^(float v) {
            NSValue *cv = [[GlobalConfig shared] valueForKey:configKey];
            MacroConfig c;
            if (cv) [cv getValue:&c];
            c.interval = v;
            [[GlobalConfig shared] setValue:[NSValue valueWithBytes:&c objCType:@encode(MacroConfig)] forKey:configKey];
            [[GlobalConfig shared] save];
        };

        [tab addSubview:configRow];
        y += [MacroConfigRow rowHeight] + 12;
    }

    tab.contentSize = CGSizeMake(w, y);
}

#pragma mark - 标签页3：美化
- (void)buildBeautifyTab {
    CGFloat w = self.scrollView.bounds.size.width;
    CGFloat h = self.scrollView.bounds.size.height;
    UIScrollView *tab = [self createVerticalTabAtX:w * 2 width:w height:h];

    GlobalConfig *cfg = [GlobalConfig shared];
    CGFloat y = 12;

    // 去皮开关
    SwitchRow *peelRow = [[SwitchRow alloc] initWithTitle:@"去皮"];
    peelRow.frame = CGRectMake(12, y, w - 24, 44);
    peelRow.switchCtrl.on = cfg.peelEnabled;
    peelRow.onChange = ^(BOOL on) {
        cfg.peelEnabled = on;
        [cfg save];
        if (on) {
            [[PeelManager shared] startPeel];
        } else {
            [[PeelManager shared] stopPeel];
        }
    };
    [tab addSubview:peelRow];
    y += 52;

    UILabel *tip = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 60)];
    tip.text = @"去皮：移除球的外层皮肤显示。\n开启后持续生效，关闭后恢复。";
    tip.textColor = COLOR_SUBTEXT;
    tip.font = [UIFont systemFontOfSize:12];
    tip.numberOfLines = 0;
    [tab addSubview:tip];
    y += 70;

    tab.contentSize = CGSizeMake(w, y);
}

- (void)refresh {
    // 刷新各标签页开关状态
    GlobalConfig *cfg = [GlobalConfig shared];
    for (UIScrollView *tab in self.tabViews) {
        for (UIView *sub in tab.subviews) {
            if ([sub isKindOfClass:[SwitchRow class]]) {
                // 开关已通过 onChange 绑定，不需要手动刷新
            }
        }
    }
}

@end
