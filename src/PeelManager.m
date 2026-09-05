#import "PeelManager.h"
#import "IL2CPPUtils.h"
#import "Config.h"

@interface PeelManager ()
@property (strong) NSTimer *monitorTimer;
@property (assign) BOOL peeling;
@end

@implementation PeelManager

+ (instancetype)shared {
    static PeelManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[PeelManager alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) { _peeling = NO; }
    return self;
}

- (void)startPeel {
    if (self.peeling) return;
    self.peeling = YES;
    [self applyPeel];
    // 持续监控，防止游戏刷新皮肤后失效（对应 JuziHub startReapplyMonitor）
    self.monitorTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                           target:self
                                                         selector:@selector(applyPeel)
                                                         userInfo:nil
                                                          repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.monitorTimer forMode:NSRunLoopCommonModes];
}

- (void)stopPeel {
    self.peeling = NO;
    [self.monitorTimer invalidate];
    self.monitorTimer = nil;
}

- (void)applyPeel {
    if (!self.peeling) return;
    Il2CppObject *gameCore = [IL2CPPUtils getGameCore];
    if (!gameCore) return;

    // 方案：通过 GameCoreCenter 获取球列表，遍历每个球的渲染器，设置透明材质
    // 对应 JuziHub 的 kGCC_BallDic（球字典）和 _Ball0~_Ball57（球遮罩）

    // 尝试获取球管理器（不同游戏类名可能不同，这里用常见命名尝试）
    Il2CppClass *ballMgrClass = [IL2CPPUtils getClass:@"BallManager"];
    if (!ballMgrClass) ballMgrClass = [IL2CPPUtils getClass:@"BallSpawnManager"];
    if (!ballMgrClass) ballMgrClass = [IL2CPPUtils getClass:@"GameBallManager"];

    if (ballMgrClass) {
        // 尝试获取球管理器单例
        const MethodInfo *getInst = [IL2CPPUtils getMethod:@"get_Instance" class:ballMgrClass argsCount:0];
        if (!getInst) getInst = [IL2CPPUtils getMethod:@"get_instance" class:ballMgrClass argsCount:0];
        if (getInst) {
            Il2CppObject *ballMgr = [IL2CPPUtils callStaticMethod:getInst args:NULL];
            if (ballMgr) {
                [self peelBallsInManager:ballMgr];
                return;
            }
        }
    }

    // fallback：直接从 GameCoreCenter 尝试获取球列表字段
    NSArray *fieldNames = @[@"balls", @"ballList", @"_balls", @"m_balls", @"ballDic", @"allBalls"];
    for (NSString *fieldName in fieldNames) {
        Il2CppObject *ballsObj = [IL2CPPUtils getField:fieldName instance:gameCore];
        if (ballsObj) {
            [self peelBallObject:ballsObj];
        }
    }
}

- (void)peelBallsInManager:(Il2CppObject *)ballMgr {
    NSArray *fieldNames = @[@"balls", @"ballList", @"_balls", @"m_balls", @"activeBalls", @"allBalls"];
    for (NSString *fieldName in fieldNames) {
        Il2CppObject *ballsObj = [IL2CPPUtils getField:fieldName instance:ballMgr];
        if (ballsObj) {
            [self peelBallObject:ballsObj];
        }
    }
}

- (void)peelBallObject:(Il2CppObject *)ballOrList {
    // 尝试获取球的 GameObject / Renderer，设置透明
    // 对应 JuziHub 的 m_Skin（材质）和 _BallMask（遮罩）
    Il2CppObject *gameObj = [IL2CPPUtils getField:@"gameObject" instance:ballOrList];
    if (!gameObj) gameObj = [IL2CPPUtils getField:@"_gameObject" instance:ballOrList];

    if (gameObj) {
        // 获取 Transform → 找 Renderer 组件
        const MethodInfo *getTransform = [IL2CPPUtils getMethod:@"get_transform" className:@"GameObject" argsCount:0];
        if (getTransform) {
            Il2CppObject *transform = [IL2CPPUtils callMethod:getTransform instance:gameObj args:NULL];
            if (transform) {
                // 遍历子物体找 Renderer
                [self setTransparentOnTransform:transform];
            }
        }
    }

    // 直接尝试设置球的材质颜色为透明
    Il2CppObject *renderer = [IL2CPPUtils getField:@"renderer" instance:ballOrList];
    if (!renderer) renderer = [IL2CPPUtils getField:@"_renderer" instance:ballOrList];
    if (!renderer) renderer = [IL2CPPUtils getField:@"m_Renderer" instance:ballOrList];
    if (renderer) {
        [self setRendererTransparent:renderer];
    }
}

- (void)setTransparentOnTransform:(Il2CppObject *)transform {
    // 获取 childCount
    const MethodInfo *getChildCount = [IL2CPPUtils getMethod:@"get_childCount" className:@"Transform" argsCount:0];
    if (!getChildCount) return;

    int childCount = 0;
    void *retBuf = &childCount;
    [IL2CPPUtils callMethod:getChildCount instance:transform args:NULL returnBuf:retBuf];

    for (int i = 0; i < childCount; i++) {
        const MethodInfo *getChild = [IL2CPPUtils getMethod:@"GetChild" className:@"Transform" argsCount:1];
        if (!getChild) break;
        int idx = i;
        void *args[1] = { &idx };
        Il2CppObject *child = [IL2CPPUtils callMethod:getChild instance:transform args:args];
        if (child) {
            // 获取 child 的 GameObject → GetComponent(Renderer)
            const MethodInfo *getGO = [IL2CPPUtils getMethod:@"get_gameObject" className:@"Transform" argsCount:0];
            if (getGO) {
                Il2CppObject *childGO = [IL2CPPUtils callMethod:getGO instance:child args:NULL];
                if (childGO) {
                    const MethodInfo *getComp = [IL2CPPUtils getMethod:@"GetComponent" className:@"GameObject" argsCount:1];
                    // 简化：直接尝试设置材质
                }
            }
            [self setTransparentOnTransform:child];
        }
    }
}

- (void)setRendererTransparent:(Il2CppObject *)renderer {
    // 获取 material
    const MethodInfo *getMat = [IL2CPPUtils getMethod:@"get_material" className:@"Renderer" argsCount:0];
    if (!getMat) getMat = [IL2CPPUtils getMethod:@"get_sharedMaterial" className:@"Renderer" argsCount:0];
    if (!getMat) return;

    Il2CppObject *material = [IL2CPPUtils callMethod:getMat instance:renderer args:NULL];
    if (!material) return;

    // 设置材质颜色 alpha 为 0（透明）
    const MethodInfo *setColor = [IL2CPPUtils getMethod:@"set_color" className:@"Material" argsCount:1];
    if (setColor) {
        // Color 是值类型，需要在栈上构造
        float color[4] = {1.0f, 1.0f, 1.0f, 0.0f};  // RGBA，alpha=0
        void *args[1] = { color };
        [IL2CPPUtils callMethod:setColor instance:material args:args];
    }
}

@end
