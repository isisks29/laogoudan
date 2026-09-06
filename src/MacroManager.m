#import "MacroManager.h"
#import "IL2CPPUtils.h"

@interface MacroButton : UIView
@property (copy) void (^onDragEnd)(CGPoint center);
@property (assign) NSInteger type;
@property (strong) UILabel *titleLabel;
@property (assign, nonatomic) BOOL isPressed;
@property (assign) CGPoint startPoint;
@property (copy) void (^onPress)(BOOL pressed);
@end

@implementation MacroButton {
    BOOL _isDragging;
    BOOL _pressStarted;
    CGPoint _startCenter;   // 新增：记录拖动开始时的中心位置
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
    self.alpha = isPressed ? 0.5 : 1.0;
    // 去掉transform缩放，之前0.9缩放导致长按时视觉跳动
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = touches.anyObject;
    self.startPoint = [touch locationInView:self.superview];  // 改：用superview坐标
    _startCenter = self.center;                                  // 新增：记录初始中心
    _isDragging = NO;
    _pressStarted = NO;

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.15 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        MacroButton *strongSelf = weakSelf;
        if (!strongSelf) return;
        if (!strongSelf->_isDragging && !strongSelf->_pressStarted) {
            strongSelf->_pressStarted = YES;
            strongSelf.isPressed = YES;
            if (strongSelf.onPress) strongSelf.onPress(YES);
        }
    });
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (![GlobalConfig shared].debugMode) return;
    UITouch *touch = touches.anyObject;
    CGPoint pt = [touch locationInView:self.superview];  // 改：用superview坐标
    CGFloat dx = pt.x - self.startPoint.x;
    CGFloat dy = pt.y - self.startPoint.y;

    if (fabs(dx) > 5 || fabs(dy) > 5) {
        _isDragging = YES;
        if (_pressStarted) {
            _pressStarted = NO;
            self.isPressed = NO;
            if (self.onPress) self.onPress(NO);
        }
        // 改：用初始中心+总位移，不要每次累加center，不要更新startPoint
        self.center = CGPointMake(_startCenter.x + dx, _startCenter.y + dy);
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (_pressStarted) {
        self.isPressed = NO;
        if (self.onPress) self.onPress(NO);
    }
    BOOL wasDragging = _isDragging;
    _pressStarted = NO;
    _isDragging = NO;
    // 拖动结束：通知外部保存新位置
    if (wasDragging && self.onDragEnd) {
        self.onDragEnd(self.center);
    }
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
    if (self) {  }
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
    self.shiliufenBtn.onDragEnd = ^(CGPoint center) { [weakSelf saveButtonPosition:0 center:center]; };

    self.tuqiuBtn = [[MacroButton alloc] initWithType:1];
    [window addSubview:self.tuqiuBtn];
    self.tuqiuBtn.onPress = ^(BOOL pressed) { [weakSelf handleTuqiu:pressed]; };
    self.tuqiuBtn.onDragEnd = ^(CGPoint center) { [weakSelf saveButtonPosition:1 center:center]; };

    self.sifenBtn = [[MacroButton alloc] initWithType:2];
    [window addSubview:self.sifenBtn];
    self.sifenBtn.onPress = ^(BOOL pressed) { [weakSelf handleSifen:pressed]; };
    self.sifenBtn.onDragEnd = ^(CGPoint center) { [weakSelf saveButtonPosition:2 center:center]; };

    [self updateButtonPositions];
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
- (void)saveButtonPosition:(NSInteger)type center:(CGPoint)center {
    GlobalConfig *cfg = [GlobalConfig shared];
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    CGFloat relX = center.x / screenSize.width;
    CGFloat relY = center.y / screenSize.height;

    NSString *key = nil;
    MacroConfig mc;
    if (type == 0) { mc = cfg.shiliufen; mc.buttonX = relX; mc.buttonY = relY; cfg.shiliufen = mc; }
    else if (type == 1) { mc = cfg.tuqiu; mc.buttonX = relX; mc.buttonY = relY; cfg.tuqiu = mc; }
    else if (type == 2) { mc = cfg.sifen; mc.buttonX = relX; mc.buttonY = relY; cfg.sifen = mc; }
    [cfg save];
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
    else { [self stopShiliufenLoop]; [self setSplitPress:NO]; }
}
- (void)startShiliufenLoop {
    [self stopShiliufenLoop];
    GlobalConfig *cfg = [GlobalConfig shared];
    NSTimeInterval interval = (cfg.shiliufen.pressDuration + cfg.shiliufen.interval) / 1000.0;
    self.shiliufenTimer = [NSTimer timerWithTimeInterval:interval
                                                    target:self
                                                  selector:@selector(shiliufenTick)
                                                  userInfo:nil
                                                   repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.shiliufenTimer forMode:NSRunLoopCommonModes];
    [self shiliufenTick];
}
- (void)shiliufenTick {
    [self setSplitPress:YES];
    GlobalConfig *cfg = [GlobalConfig shared];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, cfg.shiliufen.pressDuration * NSEC_PER_MSEC),
                   dispatch_get_main_queue(), ^{ [self setSplitPress:NO]; });
}
- (void)stopShiliufenLoop {
    [self.shiliufenTimer invalidate];
    self.shiliufenTimer = nil;
    [self setSplitPress:NO];
}
#pragma mark - 吐球宏
- (void)handleTuqiu:(BOOL)pressed {
    if (pressed) { [self startTuqiuLoop]; }
    else { [self stopTuqiuLoop]; [self setFeedPress:NO]; }
}
- (void)startTuqiuLoop {
    [self stopTuqiuLoop];
    GlobalConfig *cfg = [GlobalConfig shared];
    NSTimeInterval interval = (cfg.tuqiu.pressDuration + cfg.tuqiu.interval) / 1000.0;
    self.tuqiuTimer = [NSTimer timerWithTimeInterval:interval
                                                target:self
                                              selector:@selector(tuqiuTick)
                                              userInfo:nil
                                               repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.tuqiuTimer forMode:NSRunLoopCommonModes];
    [self tuqiuTick];
}
- (void)tuqiuTick {
    [self setFeedPress:YES];
    GlobalConfig *cfg = [GlobalConfig shared];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, cfg.tuqiu.pressDuration * NSEC_PER_MSEC),
                   dispatch_get_main_queue(), ^{ [self setFeedPress:NO]; });
}
- (void)stopTuqiuLoop {
    [self.tuqiuTimer invalidate];
    self.tuqiuTimer = nil;
    [self setFeedPress:NO];
}

#pragma mark - 4分宏
- (void)handleSifen:(BOOL)pressed {
    if (!pressed) return;
    [self triggerFreeTypeClick];
}
- (void)triggerFreeTypeClick {
    Il2CppObject *gameCore = [IL2CPPUtils getGameCore];
    if (!gameCore) return;
    // 4分是单次点击，用 FreeTypeClick（无参方法），不是 FreeTypePress
    const MethodInfo *method = [IL2CPPUtils getMethod:@"FreeTypeClick" className:@"GameCoreCenter" argsCount:0];
    if (method) {
        void *args[1] = { NULL };
        [IL2CPPUtils callMethod:method instance:gameCore args:args];
    }
}

#pragma mark - 核心：IL2CPP 调用（方法名对齐 ballspt.dylib）
- (void)setFeedPress:(BOOL)pressed {
    Il2CppObject *gameCore = [IL2CPPUtils getGameCore];
    if (!gameCore) {
        // 调试：获取不到GameCore时按钮边框闪红
        self.shiliufenBtn.layer.borderColor = [UIColor redColor].CGColor;
        self.tuqiuBtn.layer.borderColor = [UIColor redColor].CGColor;
        return;
    }
    [IL2CPPUtils callBoolMethod:@"set_BtnIsFeeding" className:@"GameCoreCenter" instance:gameCore value:pressed];
    [IL2CPPUtils callBoolMethod:@"set_skillFeedPress" className:@"GameCoreCenter" instance:gameCore value:pressed];
}

- (void)setSplitPress:(BOOL)pressed {
    Il2CppObject *gameCore = [IL2CPPUtils getGameCore];
    if (!gameCore) return;
    // 方式1：带1个BOOL参数（按下/抬起状态）
    const MethodInfo *method = [IL2CPPUtils getMethod:@"FreeTypePress" className:@"GameCoreCenter" argsCount:1];
    if (method) {
        BOOL val = pressed;
        void *args[1] = { &val };
        [IL2CPPUtils callMethod:method instance:gameCore args:args];
        return;
    }
    // 方式2：无参方法（调用一次触发一次分身，仅按下时调用）
    if (pressed) {
        const MethodInfo *method2 = [IL2CPPUtils getMethod:@"FreeTypePress" className:@"GameCoreCenter" argsCount:0];
        if (method2) {
            void *args[1] = { NULL };
            [IL2CPPUtils callMethod:method2 instance:gameCore args:args];
        }
    }
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
