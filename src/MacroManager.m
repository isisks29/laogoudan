#import "MacroManager.h"
#import "IL2CPPUtils.h"

@interface MacroButton : UIView
@property (assign) NSInteger type;
@property (strong) UILabel *titleLabel;
@property (assign, nonatomic) BOOL isPressed;
@property (assign) CGPoint startPoint;
@property (copy) void (^onPress)(BOOL pressed);
@end

@implementation MacroButton {
    BOOL _isDragging;
    BOOL _pressStarted;
}
- (instancetype)initWithType:(NSInteger)type {
    self = [super init];
    if (self) {
        _type = type;
        _isPressed = NO;
        _isDragging = NO;
        _pressStarted = NO;
        self.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.85];
        self.layer.borderWidth = 1.5;
        NSArray *titles = @[@"16", @"吐", @"4"];
        NSArray *colors = @[
            [UIColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:1.0],
            [UIColor colorWithRed:0.4 green:0.8 blue:1.0 alpha:1.0],
            [UIColor colorWithRed:0.4 green:1.0 blue:0.6 alpha:1.0],
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
    _isDragging = NO;
    _pressStarted = NO;

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.15 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        // 不要用weakSelf.xxx，直接访问ivar
        if (!weakSelf->_isDragging && !weakSelf->_pressStarted) {
            weakSelf->_pressStarted = YES;
            weakSelf.isPressed = YES;
            if (weakSelf.onPress) weakSelf.onPress(YES);
        }
    });
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (![GlobalConfig shared].debugMode) return;  // 调试模式关闭：固定位置，不可拖动
    UITouch *touch = touches.anyObject;
    CGPoint pt = [touch locationInView:self];
    CGFloat dx = pt.x - self.startPoint.x;
    CGFloat dy = pt.y - self.startPoint.y;

    if (fabs(dx) > 5 || fabs(dy) > 5) {
        _isDragging = YES;
        if (_pressStarted) {
            _pressStarted = NO;
            self.isPressed = NO;
            if (self.onPress) self.onPress(NO);
        }
        CGPoint center = self.center;
        center.x += dx;
        center.y += dy;
        self.center = center;
        self.startPoint = pt;
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (_pressStarted) {
        self.isPressed = NO;
        if (self.onPress) self.onPress(NO);
    }
    _pressStarted = NO;
    _isDragging = NO;
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (_pressStarted) {
        self.isPressed = NO;
        if (self.onPress) self.onPress(NO);
    }
    _pressStarted = NO;
    _isDragging = NO;
}

@end

@interface MacroManager ()
@property (strong) MacroButton *shiliufenBtn;
@property (strong) MacroButton *tuqiuBtn;
@property (strong) MacroButton *sifenBtn;
@property (weak) UIWindow *gameWindow;
@property (strong) NSTimer *shiliufenTimer;
@property (strong) NSTimer *tuqiuTimer;
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
    if (self) { _sifenClickCount = 0; }
    return self;
}

- (void)setup { }

- (void)setupMacroButtonsInWindow:(UIWindow *)window {
    if (self.shiliufenBtn) return;
    self.gameWindow = window;
    GlobalConfig *cfg = [GlobalConfig shared];

    self.shiliufenBtn = [[MacroButton alloc] initWithType:0];
    [window addSubview:self.shiliufenBtn];
    __weak typeof(self) weakSelf = self;
    self.shiliufenBtn.onPress = ^(BOOL pressed) { [weakSelf handleShiliufen:pressed]; };

    self.tuqiuBtn = [[MacroButton alloc] initWithType:1];
    [window addSubview:self.tuqiuBtn];
    self.tuqiuBtn.onPress = ^(BOOL pressed) { [weakSelf handleTuqiu:pressed]; };

    self.sifenBtn = [[MacroButton alloc] initWithType:2];
    [window addSubview:self.sifenBtn];
    self.sifenBtn.onPress = ^(BOOL pressed) { [weakSelf handleSifen:pressed]; };

    [self updateButtonPositions];
    [self setMacroButtonsHidden:!cfg.menuVisible];
}

- (void)updateButtonPositions {
    if (!self.shiliufenBtn) return;
    GlobalConfig *cfg = [GlobalConfig shared];
    CGSize screenSize = [UIScreen mainScreen].bounds.size;

    CGFloat s16size = cfg.shiliufen.buttonSize * 2;
    self.shiliufenBtn.frame = CGRectMake(
        cfg.shiliufen.buttonX * screenSize.width - s16size/2,
        cfg.shiliufen.buttonY * screenSize.height - s16size/2,
        s16size, s16size);
    self.shiliufenBtn.hidden = !cfg.shiliufen.enabled;

    CGFloat tqsize = cfg.tuqiu.buttonSize * 2;
    self.tuqiuBtn.frame = CGRectMake(
        cfg.tuqiu.buttonX * screenSize.width - tqsize/2,
        cfg.tuqiu.buttonY * screenSize.height - tqsize/2,
        tqsize, tqsize);
    self.tuqiuBtn.hidden = !cfg.tuqiu.enabled;

    CGFloat s4size = cfg.sifen.buttonSize * 2;
    self.sifenBtn.frame = CGRectMake(
        cfg.sifen.buttonX * screenSize.width - s4size/2,
        cfg.sifen.buttonY * screenSize.height - s4size/2,
        s4size, s4size);
    self.sifenBtn.hidden = !cfg.sifen.enabled;
}

- (void)setMacroButtonsHidden:(BOOL)hidden {
    if (!self.shiliufenBtn) return;
    GlobalConfig *cfg = [GlobalConfig shared];
    self.shiliufenBtn.hidden = hidden || !cfg.shiliufen.enabled;
    self.tuqiuBtn.hidden = hidden || !cfg.tuqiu.enabled;
    self.sifenBtn.hidden = hidden || !cfg.sifen.enabled;
}

#pragma mark - 16分宏
- (void)handleShiliufen:(BOOL)pressed {
    if (pressed) { [self startShiliufenLoop]; }
    else { [self stopShiliufenLoop]; [self setFeedPress:NO]; }
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
    [self shiliufenTick];
}
- (void)shiliufenTick {
    GlobalConfig *cfg = [GlobalConfig shared];
    [self setFeedPress:YES];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, cfg.shiliufen.pressDuration * NSEC_PER_MSEC),
                   dispatch_get_main_queue(), ^{ [self setFeedPress:NO]; });
}
- (void)stopShiliufenLoop {
    [self.shiliufenTimer invalidate];
    self.shiliufenTimer = nil;
}

#pragma mark - 吐球宏
- (void)handleTuqiu:(BOOL)pressed {
    if (pressed) { [self startTuqiuLoop]; }
    else { [self stopTuqiuLoop]; [self setFeedPress:NO]; }
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
                   dispatch_get_main_queue(), ^{ [self setFeedPress:NO]; });
}
- (void)stopTuqiuLoop {
    [self.tuqiuTimer invalidate];
    self.tuqiuTimer = nil;
}

#pragma mark - 4分宏
- (void)handleSifen:(BOOL)pressed {
    if (!pressed) return;
    self.sifenClickCount++;
    [self triggerSplit];
    [self.sifenResetTimer invalidate];
    GlobalConfig *cfg = [GlobalConfig shared];
    self.sifenResetTimer = [NSTimer scheduledTimerWithTimeInterval:cfg.sifen.interval / 1000.0
                                                               target:self
                                                             selector:@selector(resetSifen)
                                                             userInfo:nil
                                                              repeats:NO];
}
- (void)triggerSplit {
    [self setSplitPress:YES];
    GlobalConfig *cfg = [GlobalConfig shared];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, cfg.sifen.pressDuration * NSEC_PER_MSEC),
                   dispatch_get_main_queue(), ^{ [self setSplitPress:NO]; });
}
- (void)resetSifen { self.sifenClickCount = 0; }

#pragma mark - 核心：IL2CPP 调用（方法名对齐 ballspt.dylib）
- (void)setFeedPress:(BOOL)pressed {
    Il2CppObject *gameCore = [IL2CPPUtils getGameCore];
    if (!gameCore) return;
    // 对应 ballspt.dylib: set_skillFeedPress: / set_BtnIsFeeding:
    [IL2CPPUtils setBoolProperty:@"skillFeedPress" className:@"GameCoreCenter" instance:gameCore value:pressed];
    [IL2CPPUtils setBoolProperty:@"BtnIsFeeding" className:@"GameCoreCenter" instance:gameCore value:pressed];
}

- (void)setSplitPress:(BOOL)pressed {
    Il2CppObject *gameCore = [IL2CPPUtils getGameCore];
    if (!gameCore) return;
    // 对应 ballspt.dylib: FreeTypePress: （非 setter，直接调用）
    [IL2CPPUtils callBoolMethod:@"FreeTypePress" className:@"GameCoreCenter" instance:gameCore value:pressed];
}

#pragma mark - 手动触发
- (void)triggerMacro:(NSInteger)type {
    switch (type) {
        case 0: {
            [self handleShiliufen:YES];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC),
                           dispatch_get_main_queue(), ^{ [self handleShiliufen:NO]; });
            break;
        }
        case 1: {
            [self handleTuqiu:YES];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC),
                           dispatch_get_main_queue(), ^{ [self handleTuqiu:NO]; });
            break;
        }
        case 2: {
            [self handleSifen:YES];
            break;
        }
    }
}

@end
