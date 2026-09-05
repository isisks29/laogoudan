#import <UIKit/UIKit.h>
#import "../Config.h"
#import "../AntiDetect.h"
#import "../MemoryUtils.h"
#import "../IL2CPPUtils.h"

// 颜色常量
#define COLOR_BG [UIColor colorWithWhite:0.12 alpha:0.95]
#define COLOR_CELL [UIColor colorWithWhite:0.18 alpha:1.0]
#define COLOR_TEXT [UIColor whiteColor]
#define COLOR_SUBTEXT [UIColor colorWithWhite:0.6 alpha:1.0]
#define COLOR_ACCENT [UIColor colorWithRed:0.25 green:0.55 blue:1.0 alpha:1.0]
#define COLOR_TAB_ACTIVE [UIColor colorWithRed:0.25 green:0.55 blue:1.0 alpha:1.0]

// 开关行
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

// 滑块行
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

// 数值输入行（点击弹窗输入任意值）
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
    UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
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

// 宏设置行（包含大小、位置、间隔、时长）
@interface MacroConfigRow : UIView
@property (strong) UILabel *titleLabel;
@property (strong) SliderRow *sizeSlider;
@property (strong) SliderRow *pressSlider;
@property (strong) SliderRow *intervalSlider;
@property (strong) UIButton *posButton;
@property (assign) BOOL editingPosition;
@property (copy) void (^onConfigChange)(void);
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
        
        _posButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_posButton setTitle:@"拖动设置位置" forState:UIControlStateNormal];
        _posButton.backgroundColor = COLOR_ACCENT;
        [_posButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _posButton.layer.cornerRadius = 6;
        _posButton.titleLabel.font = [UIFont systemFontOfSize:13];
        [self addSubview:_posButton];
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
    _posButton.frame = CGRectMake(14, 242, w - 28, 36);
}
+ (CGFloat)rowHeight { return 290; }
@end

// ===== 主 UI =====
@interface TweakUI () <UIScrollViewDelegate>
@property (strong) UIWindow *floatWindow;
@property (strong) UIButton *floatButton;
@property (strong) UIView *menuView;
@property (strong) UISegmentedControl *tabControl;
@property (strong) UIScrollView *scrollView;
@property (strong) NSMutableArray *tabViews;
@property (assign) BOOL menuOpen;
@end

@implementation TweakUI

+ (instancetype)shared {
    static TweakUI *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[TweakUI alloc] init]; });
    return instance;
}

- (void)show {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setupFloatButton];
        [self setupMenu];
    });
}

- (void)hide {
    [self.floatWindow removeFromSuperview];
    self.floatWindow = nil;
}

- (void)setupFloatButton {
    if (self.floatWindow) return;
    
    self.floatWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.floatWindow.windowLevel = UIWindowLevelAlert + 100;
    self.floatWindow.backgroundColor = [UIColor clearColor];
    self.floatWindow.hidden = NO;
    
    self.floatButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatButton.frame = CGRectMake(20, 100, 50, 50);
    self.floatButton.backgroundColor = COLOR_ACCENT;
    self.floatButton.layer.cornerRadius = 25;
    [self.floatButton setTitle:@"⚙" forState:UIControlStateNormal];
    self.floatButton.titleLabel.font = [UIFont systemFontOfSize:22];
    [self.floatButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.floatWindow addSubview:self.floatButton];
    
    // 可拖动
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragFloat:)];
    [self.floatButton addGestureRecognizer:pan];
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
    [UIView animateWithDuration:0.25 animations:^{
        self.menuView.alpha = self.menuOpen ? 1.0 : 0.0;
        self.menuView.transform = self.menuOpen ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.9, 0.9);
    }];
    if (self.menuOpen) [self refresh];
    
    GlobalConfig *cfg = [GlobalConfig shared];
    cfg.menuVisible = self.menuOpen;
    [[MacroManager shared] setMacroButtonsHidden:!self.menuOpen];
}

- (void)setupMenu {
    if (self.menuView) return;
    
    CGFloat w = MIN([UIScreen mainScreen].bounds.size.width - 40, 340);
    CGFloat h = MIN([UIScreen mainScreen].bounds.size.height - 120, 520);
    
    self.menuView = [[UIView alloc] initWithFrame:CGRectMake(20, 80, w, h)];
    self.menuView.backgroundColor = COLOR_BG;
    self.menuView.layer.cornerRadius = 14;
    self.menuView.clipsToBounds = YES;
    self.menuView.alpha = 0;
    self.menuView.transform = CGAffineTransformMakeScale(0.9, 0.9);
    [self.floatWindow addSubview:self.menuView];
    
    // 标签栏
    self.tabControl = [[UISegmentedControl alloc] initWithItems:@[@"反检测", @"功能", @"宏"]];
    self.tabControl.frame = CGRectMake(12, 12, w - 24, 32);
    self.tabControl.selectedSegmentIndex = 1;
    self.tabControl.tintColor = COLOR_ACCENT;
    [self.tabControl addTarget:self action:@selector(tabChanged) forControlEvents:UIControlEventValueChanged];
    [self.menuView addSubview:self.tabControl];
    
    // 滚动视图
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 52, w, h - 52)];
    self.scrollView.pagingEnabled = YES;
    self.scrollView.delegate = self;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.contentSize = CGSizeMake(w * 3, h - 52);
    [self.menuView addSubview:self.scrollView];
    
    self.tabViews = [NSMutableArray array];
    [self buildAntiDetectTab];
    [self buildFeatureTab];
    [self buildMacroTab];
    
    self.scrollView.contentOffset = CGPointMake(w, 0);
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

#pragma mark - 标签页1：反检测

- (void)buildAntiDetectTab {
    CGFloat w = self.scrollView.bounds.size.width;
    CGFloat x = 0;
    UIView *tab = [[UIView alloc] initWithFrame:CGRectMake(x, 0, w, self.scrollView.bounds.size.height)];
    [self.scrollView addSubview:tab];
    [self.tabViews addObject:tab];
    
    GlobalConfig *cfg = [GlobalConfig shared];
    CGFloat y = 12;
    
    NSArray *items = @[
        @{@"title": @"总开关", @"key": @"antiDetectEnabled"},
        @{@"title": @"ptrace Hook", @"key": @"ptraceHook"},
        @{@"title": @"sysctl Hook", @"key": @"sysctlHook"},
        @{@"title": @"dyld 镜像隐藏", @"key": @"dyldHide"},
        @{@"title": @"越狱检测反制", @"key": @"jailbreakHide"},
        @{@"title": @"注入器环境感知", @"key": @"injectorDetect"},
    ];
    
    for (NSDictionary *item in items) {
        SwitchRow *row = [[SwitchRow alloc] initWithTitle:item[@"title"]];
        row.frame = CGRectMake(12, y, w - 24, 44);
        row.switchCtrl.on = [[cfg valueForKey:item[@"key"]] boolValue];
        NSString *key = item[@"key"];
        row.onChange = ^(BOOL on) {
            [cfg setValue:@(on) forKey:key];
            [cfg save];
        };
        [tab addSubview:row];
        y += 52;
    }
    
    // 说明文字
    UILabel *tip = [[UILabel alloc] initWithFrame:CGRectMake(16, y + 8, w - 32, 80)];
    tip.text = @"反检测体系在启动时自动生效。\n总开关关闭后，所有反检测 Hook 将不生效。\n建议保持全部开启。";
    tip.textColor = COLOR_SUBTEXT;
    tip.font = [UIFont systemFontOfSize:12];
    tip.numberOfLines = 0;
    [tab addSubview:tip];
}

#pragma mark - 标签页2：功能开关

- (void)buildFeatureTab {
    CGFloat w = self.scrollView.bounds.size.width;
    CGFloat x = w;
    UIView *tab = [[UIView alloc] initWithFrame:CGRectMake(x, 0, w, self.scrollView.bounds.size.height)];
    [self.scrollView addSubview:tab];
    [self.tabViews addObject:tab];
    
    GlobalConfig *cfg = [GlobalConfig shared];
    CGFloat y = 12;
    
    // 功能开关列表
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
            [[FeatureManager shared] applyFeatures];
            if (on) [[FeatureManager shared] rescanMemory];
        };
        [tab addSubview:row];
        y += 46;
    }
    
    // 数值输入（点击弹窗输入任意值）
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
            [[FeatureManager shared] applyFeatures];
        };
        [tab addSubview:row];
        y += 46;
    }
    
    // 解限配置（写入值 + int/float切换 + 搜索值）
    y += 8;
    UILabel *jlTitle = [[UILabel alloc] initWithFrame:CGRectMake(14, y, w - 28, 20)];
    jlTitle.text = @"解限高级配置";
    jlTitle.textColor = COLOR_TEXT_DIM;
    jlTitle.font = [UIFont systemFontOfSize:11];
    [tab addSubview:jlTitle];
    y += 26;
    
    // 解限写入值
    InputRow *jlWrite = [[InputRow alloc] initWithTitle:@"写入值" value:cfg.jielimWriteValue];
    jlWrite.frame = CGRectMake(12, y, w - 24, 40);
    jlWrite.onInput = ^(NSString *value) {
        cfg.jielimWriteValue = value;
        [cfg save];
    };
    [tab addSubview:jlWrite];
    y += 46;
    
    // 解限搜索值
    InputRow *jlSearch = [[InputRow alloc] initWithTitle:@"搜索值" value:cfg.jielimSearchValue];
    jlSearch.frame = CGRectMake(12, y, w - 24, 40);
    jlSearch.onInput = ^(NSString *value) {
        cfg.jielimSearchValue = value;
        [cfg save];
        [[FeatureManager shared] rescanMemory];
    };
    [tab addSubview:jlSearch];
    y += 46;
    
    // 解限写入类型切换
    SwitchRow *jlType = [[SwitchRow alloc] initWithTitle:@"按int写入(关闭=float)"];
    jlType.frame = CGRectMake(12, y, w - 24, 40);
    jlType.switchCtrl.on = cfg.jielimWriteAsInt;
    jlType.onChange = ^(BOOL on) {
        cfg.jielimWriteAsInt = on;
        [cfg save];
    };
    [tab addSubview:jlType];
}

#pragma mark - 标签页3：宏设置

- (void)buildMacroTab {
    CGFloat w = self.scrollView.bounds.size.width;
    CGFloat x = w * 2;
    UIView *tab = [[UIView alloc] initWithFrame:CGRectMake(x, 0, w, self.scrollView.bounds.size.height)];
    [self.scrollView addSubview:tab];
    [self.tabViews addObject:tab];
    
    GlobalConfig *cfg = [GlobalConfig shared];
    CGFloat y = 12;
    
    NSArray *macros = @[
        @{@"title": @"16分（按住循环）", @"config": @"shiliufen", @"type": @0},
        @{@"title": @"吐球（按住循环）", @"config": @"tuqiu", @"type": @1},
        @{@"title": @"4分（点击触发）", @"config": @"sifen", @"type": @2},
    ];
    
    for (NSDictionary *m in macros) {
        // 开关
        SwitchRow *sw = [[SwitchRow alloc] initWithTitle:m[@"title"]];
        sw.frame = CGRectMake(12, y, w - 24, 40);
        NSString *configKey = m[@"config"];
        MacroConfig mc = [[cfg valueForKey:configKey] pointerValue];
        sw.switchCtrl.on = mc.enabled;
        sw.onChange = ^(BOOL on) {
            MacroConfig c = [[GlobalConfig shared] valueForKey:configKey].pointerValue;
            c.enabled = on;
            NSValue *v = [NSValue valueWithBytes:&c objCType:@encode(MacroConfig)];
            [[GlobalConfig shared] setValue:v forKey:configKey];
            [[GlobalConfig shared] save];
            [[MacroManager shared] updateButtonPositions];
        };
        [tab addSubview:sw];
        y += 48;
        
        // 配置行
        MacroConfigRow *configRow = [[MacroConfigRow alloc] initWithTitle:@"参数设置"];
        configRow.frame = CGRectMake(12, y, w - 24, [MacroConfigRow rowHeight]);
        MacroConfig current = [[cfg valueForKey:configKey] pointerValue];
        configRow.sizeSlider.slider.value = current.buttonSize;
        configRow.sizeSlider.valueLabel.text = [NSString stringWithFormat:@"%.0f", current.buttonSize];
        configRow.pressSlider.slider.value = current.pressDuration;
        configRow.pressSlider.valueLabel.text = [NSString stringWithFormat:@"%.0f", current.pressDuration];
        configRow.intervalSlider.slider.value = current.interval;
        configRow.intervalSlider.valueLabel.text = [NSString stringWithFormat:@"%.0f", current.interval];
        
        configRow.sizeSlider.onChange = ^(float val) {
            MacroConfig c = [[GlobalConfig shared] valueForKey:configKey].pointerValue;
            c.buttonSize = val;
            [[GlobalConfig shared] setValue:[NSValue valueWithBytes:&c objCType:@encode(MacroConfig)] forKey:configKey];
            [[GlobalConfig shared] save];
            [[MacroManager shared] updateButtonPositions];
        };
        configRow.pressSlider.onChange = ^(float val) {
            MacroConfig c = [[GlobalConfig shared] valueForKey:configKey].pointerValue;
            c.pressDuration = val;
            [[GlobalConfig shared] setValue:[NSValue valueWithBytes:&c objCType:@encode(MacroConfig)] forKey:configKey];
            [[GlobalConfig shared] save];
        };
        configRow.intervalSlider.onChange = ^(float val) {
            MacroConfig c = [[GlobalConfig shared] valueForKey:configKey].pointerValue;
            c.interval = val;
            [[GlobalConfig shared] setValue:[NSValue valueWithBytes:&c objCType:@encode(MacroConfig)] forKey:configKey];
            [[GlobalConfig shared] save];
        };
        
        [tab addSubview:configRow];
        y += [MacroConfigRow rowHeight] + 12;
    }
}

- (void)refresh {
    // 重新加载所有控件的状态
    [self.tabViews enumerateObjectsUsingBlock:^(UIView *tab, NSUInteger idx, BOOL *stop) {
        for (UIView *sub in tab.subviews) {
            if ([sub isKindOfClass:[SwitchRow class]]) {
                // 不需要重新设置，开关状态已经绑定
            }
        }
    }];
}

@end
