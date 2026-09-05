// FeatureManager.m — 功能开关管理器实现
#import "FeatureManager.h"
#import "Config.h"
#import "MemoryUtils.h"
#import "IL2CPPUtils.h"

@interface FeatureManager ()
@property (strong) NSTimer *loopTimer;
@property (assign) BOOL inGame;

// A 类功能：内存搜改型的缓存地址
@property (assign) uintptr_t shuangliandianAddr;
@property (assign) uintptr_t jielimAddr;
@property (assign) uintptr_t mingziAddr;
@property (assign) uintptr_t nianheAddr;

// 地址是否已找到
@property (assign) BOOL sldFound;
@property (assign) BOOL jlmFound;
@property (assign) BOOL mzFound;
@property (assign) BOOL nhFound;

@end

@implementation FeatureManager
static FeatureManager *_inst = nil;
+ (instancetype)sharedManager {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        _inst = [[self alloc] init];
    });
    return _inst;
}
- (void)setup {
    //留空，后续写逻辑
}

+ (instancetype)shared {
    static FeatureManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[FeatureManager alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _inGame = NO;
        _sldFound = NO;
        _jlmFound = NO;
        _mzFound = NO;
        _nhFound = NO;
    }
    return self;
}

- (void)startLoop {
    if (self.loopTimer) return;
    self.inGame = YES;
    
    // 先搜索一次内存
    [self rescanMemory];
    
    // 每 100ms 执行一次功能应用（不需要每帧，10fps 足够）
    self.loopTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                       target:self
                                                     selector:@selector(applyFeatures)
                                                     userInfo:nil
                                                      repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.loopTimer forMode:NSRunLoopCommonModes];
}

- (void)stopLoop {
    [self.loopTimer invalidate];
    self.loopTimer = nil;
    self.inGame = NO;
}

- (void)rescanMemory {
    GlobalConfig *cfg = [GlobalConfig shared];
    
    // 双连点：搜索 0.01（float）
    if (cfg.shuangliandian && !self.sldFound) {
        NSArray *results = [MemoryUtils searchFloat:0.01f];
        if (results.count > 0) {
            // 取第一个结果（实际项目中应该用多值搜索精确定位）
            self.shuangliandianAddr = [results[0] unsignedLongLongValue];
            self.sldFound = YES;
        }
    }
    
    // 解限：搜索用户配置的搜索值（默认100.0）
    if (cfg.jielim && !self.jlmFound) {
        float searchVal = [cfg.jielimSearchValue floatValue];
        NSArray *results = [MemoryUtils searchFloat:searchVal];
        if (results.count > 0) {
            self.jielimAddr = [results[0] unsignedLongLongValue];
            self.jlmFound = YES;
        }
    }
    
    // 名字大小：搜索默认值 1.0（float）
    if (cfg.mingzidaxiao && !self.mzFound) {
        NSArray *results = [MemoryUtils searchFloat:1.0f];
        if (results.count > 0) {
            self.mingziAddr = [results[0] unsignedLongLongValue];
            self.mzFound = YES;
        }
    }
    
    // 粘合：搜索默认值 1.0（float）
    if (cfg.nianhe && !self.nhFound) {
        NSArray *results = [MemoryUtils searchFloat:1.0f];
        if (results.count > 1) {
            // 取第二个结果（区分名字大小）
            self.nianheAddr = [results[1] unsignedLongLongValue];
            self.nhFound = YES;
        }
    }
}

- (void)applyFeatures {
    GlobalConfig *cfg = [GlobalConfig shared];
    if (!self.inGame) return;
    
    // ===== A 类：内存搜改型 =====
    
    // 双连点：写入 0.462203
    if (cfg.shuangliandian && self.sldFound) {
        [MemoryUtils writeFloat:0.462203f at:self.shuangliandianAddr];
    }
    
    // 解限：写入用户配置的值，支持 int/float 切换
    if (cfg.jielim && self.jlmFound) {
        if (cfg.jielimWriteAsInt) {
            int32_t writeVal = (int32_t)[cfg.jielimWriteValue integerValue];
            [MemoryUtils writeInt:writeVal at:self.jielimAddr];
        } else {
            float writeVal = [cfg.jielimWriteValue floatValue];
            [MemoryUtils writeFloat:writeVal at:self.jielimAddr];
        }
    }
    
    // 名字大小：写入用户输入的值（从字符串解析为float）
    if (cfg.mingzidaxiao && self.mzFound) {
        float val = [cfg.mingziValue floatValue];
        [MemoryUtils writeFloat:val at:self.mingziAddr];
    }
    
    // 粘合：写入用户输入的值
    if (cfg.nianhe && self.nhFound) {
        float val = [cfg.nianheValue floatValue];
        [MemoryUtils writeFloat:val at:self.nianheAddr];
    }
    
    // ===== B 类：IL2CPP 方法调用型 =====
    // 这些功能通过调用游戏的 IL2CPP 方法修改参数
    // 需要根据具体游戏修改类名和方法名
    
    // 解断：修改摇杆中断参数
    if (cfg.jieduan) {
        [self applyJieduan];
    }
    
    // 灵敏：修改摇杆灵敏度
    if (cfg.lingmin) {
        [self applyLingmin];
    }
    
    // 视野大小：修改相机 OrthographicSize
    if (cfg.shiyedaxiao) {
        [self applyShiye];
    }
    
    // 球体内显：修改球体渲染参数
    if (cfg.qiutineixian) {
        [self applyNeixian];
    }
    
    // 防录制：设置游戏内部禁止录屏标志
    if (cfg.fangluzhi) {
        [self applyFangluzhi];
    }
    
    // 摇杆回弹：修改摇杆回弹速度
    if (cfg.yaoganhuitan) {
        [self applyHuitan];
    }
}

#pragma mark - B 类功能实现（需要根据具体游戏修改）

- (void)applyJieduan {
    // 示例：调用游戏方法解除摇杆中断
    // Il2CppObject *skillMgr = [IL2CPPUtils getSkillManager];
    // [IL2CPPUtils setBoolProperty:@"disableBreak" className:@"SkillManager" instance:skillMgr value:YES];
}

- (void)applyLingmin {
    // 示例：设置摇杆灵敏度
    // Il2CppObject *inputMgr = [IL2CPPUtils getGameCore];
    // [IL2CPPUtils setFloatProperty:@"sensitivity" className:@"InputManager" instance:inputMgr value:2.0f];
}

- (void)applyShiye {
    // 示例：设置相机视野大小
    // const MethodInfo *method = [IL2CPPUtils getMethod:@"set_orthographicSize" className:@"Camera" argsCount:1];
    // if (method) {
    //     Il2CppObject *camera = [IL2CPPUtils getGameCore];  // 需要获取相机对象
    //     float size = [GlobalConfig shared].shiyeValue;
    //     void *args[1] = { &size };
    //     [IL2CPPUtils callMethod:method instance:camera args:args];
    // }
}

- (void)applyNeixian {
    // 示例：修改球体材质渲染模式
    // Il2CppObject *ballMgr = [IL2CPPUtils getGameCore];
    // [IL2CPPUtils setBoolProperty:@"showInside" className:@"BallRenderer" instance:ballMgr value:YES];
}

- (void)applyFangluzhi {
    // 示例：设置游戏内部的禁止录屏标志
    // Il2CppObject *gameMgr = [IL2CPPUtils getGameCore];
    // [IL2CPPUtils setBoolProperty:@"disableRecording" className:@"GameManager" instance:gameMgr value:YES];
}

- (void)applyHuitan {
    // 示例：设置摇杆回弹速度
    // Il2CppObject *inputMgr = [IL2CPPUtils getGameCore];
    // float speed = [GlobalConfig shared].huitanValue;
    // [IL2CPPUtils setFloatProperty:@"returnSpeed" className:@"Joystick" instance:inputMgr value:speed];
}

@end
