// MacroManager.m — 宏操作管理器实现
#import "MacroManager.h"
#import "IL2CPPUtils.h"

// 宏按钮类：可拖动的圆形按钮
@interface MacroButton : UIView
@property (assign) NSInteger type;  // 0=16分, 1=吐球, 2=4分
@property (strong) UILabel *titleLabel;
@property (assign) BOOL isPressed;
@property (assign) CGPoint startPoint;
@property (copy) void (^onPress)(BOOL pressed);
@end

@implementation MacroButton

- (instancetype)initWithType:(NSInteger)type {
    self = [super init];
    if (self) {
        _type = type;
        _isPressed = NO;
        
        self.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.85];
        self.layer.cornerRadius = 0;  // 会在 layoutSubviews 中设置
        self.layer.borderWidth = 1.5;
        
        NSArray *titles = @[@"16", @"吐", @"4"];
        NSArray *colors = @[
            [UIColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:1.0],  // 16分-红
            [UIColor colorWithRed:0.4 green:0.8 blue:1.0 alpha:1.0],  // 吐球-蓝
            [UIColor colorWithRed:0.4 green:1.0 green:0.6 alpha:1.0],  // 4分-绿
        ];
        
        self.layer.borderColor = ((UIColor *)colors[type]).CGColor;
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.text = titles[type];
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.font = [UIFont boldSystemFontOfSize:14];
        [self addSubview:_titleLabel];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.cornerRadius = self.bounds.size.width / 2;
    self.titleLabel.frame = self.bounds;
}

- (void)setIsPressed:(BOOL)isPressed {
    _isPressed = isPressed;
    self.alpha = isPressed ? 0.6 : 1.0;
    self.transform = isPressed ? CGAffineTransformMakeScale(0.9, 0.9) : CGAffineTransformIdentity;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = touches.anyObject;
    self.startPoint = [touch locationInView:self];
    self.isPressed = YES;
    if (self.onPress) self.onPress(YES);
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = touches.anyObject;
    CGPoint pt = [touch locationInView:self];
    CGFloat dx = pt.x - self.startPoint.x;
    CGFloat dy = pt.y - self.startPoint.y;
    if (fabs(dx) > 5 || fabs(dy) > 5) {
        // 拖动模式：移动按钮
        CGPoint center = self.center;
        center.x += dx;
        center.y += dy;
        self.center = center;
        self.startPoint = pt;
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.isPressed = NO;
    if (self.onPress) self.onPress(NO);
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.isPressed = NO;
    if (self.onPress) self.onPress(NO);
}

@end

// ===== 宏管理器 =====
@interface MacroManager ()
@property (strong) MacroButton *shiliufenBtn;
@property (strong) MacroButton *tuqiuBtn;
@property (strong) MacroButton *sifenBtn;
@property (weak) UIWindow *gameWindow;

// 定时器
@property (strong) NSTimer *shiliufenTimer;
@property (strong) NSTimer *tuqiuTimer;

// 4分点击状态
@property (assign) NSInteger sifenClickCount;
@property (strong) NSTimer *sifenResetTimer;

@end

@implementation MacroManager

+ (instancetype)shared {
    static MacroManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[MacroManager alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _sifenClickCount = 0;
    }
    return self;
}

- (void)setupMacroButtonsInWindow:(UIWindow *)window {
    self.gameWindow = window;
    GlobalConfig *cfg = [GlobalConfig shared];
    
    // 16分按钮
    self.shiliufenBtn = [[MacroButton alloc] initWithType:0];
    [window addSubview:self.shiliufenBtn];
    __weak typeof(self) weakSelf = self;
    self.shiliufenBtn.onPress = ^(BOOL pressed) {
        [weakSelf handleShiliufen:pressed];
    };
    
    // 吐球按钮
    self.tuqiuBtn = [[MacroButton alloc] initWithType:1];
    [window addSubview:self.tuqiuBtn];
    self.tuqiuBtn.onPress = ^(BOOL pressed) {
        [weakSelf handleTuqiu:pressed];
    };
    
    // 4分按钮
    self.sifenBtn = [[MacroButton alloc] initWithType:2];
    [window addSubview:self.sifenBtn];
    self.sifenBtn.onPress = ^(BOOL pressed) {
        [weakSelf handleSifen:pressed];
    };
    
    [self updateButtonPositions];
    [self setMacroButtonsHidden:!cfg.menuVisible];
}

- (void)updateButtonPositions {
    GlobalConfig *cfg = [GlobalConfig shared];
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    
    // 16分
    CGFloat s16size = cfg.shiliufen.buttonSize * 2;
    self.shiliufenBtn.frame = CGRectMake(
        cfg.shiliufen.buttonX * screenSize.width - s16size/2,
        cfg.shiliufen.buttonY * screenSize.height - s16size/2,
        s16size, s16size
    );
    self.shiliufenBtn.hidden = !cfg.shiliufen.enabled;
    
    // 吐球
    CGFloat tqsize = cfg.tuqiu.buttonSize * 2;
    self.tuqiuBtn.frame = CGRectMake(
        cfg.tuqiu.buttonX * screenSize.width - tqsize/2,
        cfg.tuqiu.buttonY * screenSize.height - tqsize/2,
        tqsize, tqsize
    );
    self.tuqiuBtn.hidden = !cfg.tuqiu.enabled;
    
    // 4分
    CGFloat s4size = cfg.sifen.buttonSize * 2;
    self.sifenBtn.frame = CGRectMake(
        cfg.sifen.buttonX * screenSize.width - s4size/2,
        cfg.sifen.buttonY * screenSize.height - s4size/2,
        s4size, s4size
    );
    self.sifenBtn.hidden = !cfg.sifen.enabled;
}

- (void)setMacroButtonsHidden:(BOOL)hidden {
    GlobalConfig *cfg = [GlobalConfig shared];
    self.shiliufenBtn.hidden = hidden || !cfg.shiliufen.enabled;
    self.tuqiuBtn.hidden = hidden || !cfg.tuqiu.enabled;
    self.sifenBtn.hidden = hidden || !cfg.sifen.enabled;
}

#pragma mark - 16分宏（按住循环，高频率吐球）

- (void)handleShiliufen:(BOOL)pressed {
    if (pressed) {
        [self startShiliufenLoop];
    } else {
        [self stopShiliufenLoop];
        // 确保最后一次抬起
        [self setFeedPress:NO];
    }
}

- (void)startShiliufenLoop {
    GlobalConfig *cfg = [GlobalConfig shared];
    NSTimeInterval interval = (cfg.shiliufen.pressDuration + cfg.shiliufen.interval) / 1000.0;
    
    self.shiliufenTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                             target:self
                                                           selector:@selector(shiliufenTick)
                                                           userInfo:nil
                                                            repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.shiliufenTimer forMode:NSRunLoopCommonModes];
    [self shiliufenTick];  // 立即执行一次
}

- (void)shiliufenTick {
    GlobalConfig *cfg = [GlobalConfig shared];
    // 按下
    [self setFeedPress:YES];
    // pressDuration 毫秒后抬起
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, cfg.shiliufen.pressDuration * NSEC_PER_MSEC),
                   dispatch_get_main_queue(), ^{
        [self setFeedPress:NO];
    });
}

- (void)stopShiliufenLoop {
    [self.shiliufenTimer invalidate];
    self.shiliufenTimer = nil;
}

#pragma mark - 吐球宏（按住循环，正常频率吐球）

- (void)handleTuqiu:(BOOL)pressed {
    if (pressed) {
        [self startTuqiuLoop];
    } else {
        [self stopTuqiuLoop];
        [self setFeedPress:NO];
    }
}

- (void)startTuqiuLoop {
    GlobalConfig *cfg = [GlobalConfig shared];
    NSTimeInterval interval = (cfg.tuqiu.pressDuration + cfg.tuqiu.interval) / 1000.0;
    
    self.tuqiuTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                         target:self
                                                       selector:@selector(tuqiuTick)
                                                       userInfo:nil
                                                        repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.tuqiuTimer forMode:NSRunLoopCommonModes];
    [self tuqiuTick];
}

- (void)tuqiuTick {
    GlobalConfig *cfg = [GlobalConfig shared];
    [self setFeedPress:YES];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, cfg.tuqiu.pressDuration * NSEC_PER_MSEC),
                   dispatch_get_main_queue(), ^{
        [self setFeedPress:NO];
    });
}

- (void)stopTuqiuLoop {
    [self.tuqiuTimer invalidate];
    self.tuqiuTimer = nil;
}

#pragma mark - 4分宏（点击触发，点两次=分身）

- (void)handleSifen:(BOOL)pressed {
    if (!pressed) return;  // 只处理按下
    
    self.sifenClickCount++;
    [self triggerSplit];
    
    // 重置点击计数（interval 毫秒内没有第二次点击就重置）
    [self.sifenResetTimer invalidate];
    GlobalConfig *cfg = [GlobalConfig shared];
    self.sifenResetTimer = [NSTimer scheduledTimerWithTimeInterval:cfg.sifen.interval / 1000.0
                                                               target:self
                                                             selector:@selector(resetSifen)
                                                             userInfo:nil
                                                              repeats:NO];
}

- (void)triggerSplit {
    // 触发分身：调用游戏的分身键方法
    // 核心：直接调用 IL2CPP 方法，不模拟触摸
    [self setSplitPress:YES];
    GlobalConfig *cfg = [GlobalConfig shared];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, cfg.sifen.pressDuration * NSEC_PER_MSEC),
                   dispatch_get_main_queue(), ^{
        [self setSplitPress:NO];
    });
}

- (void)resetSifen {
    self.sifenClickCount = 0;
}

#pragma mark - 核心：直接调用游戏 IL2CPP 方法（不模拟触摸！）

// 这是宏不影响其他手指的根本原因：
// 我们不发送任何触摸事件，而是直接调用游戏内部的方法
// 游戏的逻辑层直接收到"按键按下"的状态，完全绕过触摸系统

- (void)setFeedPress:(BOOL)pressed {
    // 从 ballspt.dylib 分析出的 IL2CPP 方法名：
    //   set_skillFeedPress (bool)  — 吐球键按下状态
    //   set_BtnIsFeeding  (bool)  — 正在吐球标志
    // 这些方法属于 GameCoreCenter 或其管理的 SkillManager 对象
    //
    // 调用方式：通过 IL2CPP 反射获取方法，直接调用，不模拟触摸
    
    Il2CppObject *gameCore = [IL2CPPUtils getGameCore];
    if (!gameCore) return;
    
    // 方式1：如果 GameCore 直接有这些方法
    [IL2CPPUtils setBoolProperty:@"skillFeedPress" className:@"GameCoreCenter" instance:gameCore value:pressed];
    [IL2CPPUtils setBoolProperty:@"BtnIsFeeding" className:@"GameCoreCenter" instance:gameCore value:pressed];
    
    // 方式2：如果方法在 SkillManager 子对象上（取消注释并修改字段名）
    // Il2CppObject *skillMgr = [IL2CPPUtils getField:@"skillManager" instance:gameCore];
    // if (skillMgr) {
    //     [IL2CPPUtils setBoolProperty:@"skillFeedPress" className:@"SkillManager" instance:skillMgr value:pressed];
    //     [IL2CPPUtils setBoolProperty:@"BtnIsFeeding" className:@"SkillManager" instance:skillMgr value:pressed];
    // }
}

- (void)setSplitPress:(BOOL)pressed {
    // 从 ballspt.dylib 分析出的 IL2CPP 方法名：
    //   FreeTypePress (bool)  — 分身键按下（"FreeType"=自由类型=分身）
    //   FreeTypeClick (bool)  — 分身键点击
    // 4分宏用 FreeTypeClick（点击触发），持续按用 FreeTypePress
    
    Il2CppObject *gameCore = [IL2CPPUtils getGameCore];
    if (!gameCore) return;
    
    [IL2CPPUtils setBoolProperty:@"FreeTypePress" className:@"GameCoreCenter" instance:gameCore value:pressed];
    
    // 如果是点击触发（4分），还需要调用 Click
    // [IL2CPPUtils setBoolProperty:@"FreeTypeClick" className:@"GameCoreCenter" instance:gameCore value:pressed];
}

#pragma mark - 手动触发

- (void)triggerMacro:(NSInteger)type {
    switch (type) {
        case 0: [self handleShiliufen:YES];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC),
                           dispatch_get_main_queue(), ^{ [self handleShiliufen:NO]; });
            break;
        case 1: [self handleTuqiu:YES];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC),
                           dispatch_get_main_queue(), ^{ [self handleTuqiu:NO]; });
            break;
        case 2: [self handleSifen:YES]; break;
    }
}

@end
