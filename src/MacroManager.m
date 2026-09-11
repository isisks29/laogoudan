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
    CGPoint _startCenter;
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
    // 不做任何视觉变化，保持原状
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = touches.anyObject;
    self.startPoint = [touch locationInView:self.superview];
    _startCenter = self.center;
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
    CGPoint pt = [touch locationInView:self.superview];
    CGFloat dx = pt.x - self.startPoint.x;
    CGFloat dy = pt.y - self.startPoint.y;
    if (fabs(dx) > 5 || fabs(dy) > 5) {
        _isDragging = YES;
        if (_pressStarted) {
            _pressStarted = NO;
            self.isPressed = NO;
            if (self.onPress) self.onPress(NO);
        }
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
    if (self) { }
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

#pragma mark - 核心：IL2CPP 实例方法调用（照搬JuziHub，需要GameCore实例）

- (void)setFeedPress:(BOOL)pressed {
    Il2CppObject *gameCore = [IL2CPPUtils getGameCore];
    if (!gameCore) return;
    const MethodInfo *method = [IL2CPPUtils getMethod:@"set_BtnIsFeeding" className:@"GameCoreCenter" argsCount:1];
    if (!method) return;
    int val = pressed ? 1 : 0;  // 关键：用int而不是BOOL
    void *args[1] = { &val };
    [IL2CPPUtils callMethod:method instance:gameCore args:args];
}

- (void)setSplitPress:(BOOL)pressed {
    Il2CppObject *gameCore = [IL2CPPUtils getGameCore];
    if (!gameCore) return;
    const MethodInfo *method = [IL2CPPUtils getMethod:@"FreeTypePress" className:@"GameCoreCenter" argsCount:1];
    if (!method) return;
    int val = pressed ? 1 : 0;  // 关键：用int而不是BOOL
    void *args[1] = { &val };
    [IL2CPPUtils callMethod:method instance:gameCore args:args];
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
    [self setFeedPress:YES];
    GlobalConfig *cfg = [GlobalConfig shared];
    NSTimeInterval interval = (cfg.tuqiu.pressDuration + cfg.tuqiu.interval) / 1000.0;
    self.tuqiuTimer = [NSTimer timerWithTimeInterval:interval
                                                target:self
                                              selector:@selector(tuqiuTick)
                                                userInfo:nil
                                                 repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.tuqiuTimer forMode:NSRunLoopCommonModes];
}

- (void)tuqiuTick {
    [self setFeedPress:YES];
}

- (void)stopTuqiuLoop {
    [self.tuqiuTimer invalidate];
    self.tuqiuTimer = nil;
}

#pragma mark - 4分宏

- (void)handleSifen:(BOOL)pressed {
    if (!pressed) return;
    Il2CppObject *gameCore = [IL2CPPUtils getGameCore];
    if (!gameCore) return;
    const MethodInfo *method = [IL2CPPUtils getMethod:@"FreeTypeClick" className:@"GameCoreCenter" argsCount:1];
    if (!method) return;
    int val = 1;  // 改为int
    void *args[1] = { &val };
    [IL2CPPUtils callMethod:method instance:gameCore args:args];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 50 * NSEC_PER_MSEC),
                   dispatch_get_main_queue(), ^{
                       Il2CppObject *gc = [IL2CPPUtils getGameCore];
                       if (!gc) return;
                       const MethodInfo *m2 = [IL2CPPUtils getMethod:@"FreeTypeClick" className:@"GameCoreCenter" argsCount:1];
                       if (m2) {
                           int v2 = 0;  // 改为int
                           void *a2[1] = { &v2 };
                           [IL2CPPUtils callMethod:m2 instance:gc args:a2];
                       }
                   });
}

#pragma mark - 手动触发

- (void)triggerMacro:(NSInteger)type {
    switch (type) {
        case 0: {
            [self handleShiliufen:YES];
            __weak typeof(self) weakSelf = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC),
                           dispatch_get_main_queue(), ^{ [weakSelf handleShiliufen:NO]; });
            break;
        }
        case 1: {
            [self handleTuqiu:YES];
            __weak typeof(self) weakSelf = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC),
                           dispatch_get_main_queue(), ^{ [weakSelf handleTuqiu:NO]; });
            break;
        }
        case 2: {
            [self handleSifen:YES];
            break;
        }
    }
}

@end
