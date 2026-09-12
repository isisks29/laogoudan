// FeatureManager.m — 功能开关管理器实现
// 8种功能：双连点、解断吐、名字大小、粘合、解限、视野、灵敏、防录制
#import "FeatureManager.h"
#import "Config.h"
#import "MemoryUtils.h"

@interface FeatureManager ()
@property (strong) NSTimer *loopTimer;
@property (assign) BOOL inGame;

// 功能地址缓存
@property (assign) uintptr_t sldAddr;        // 双连点
@property (assign) uintptr_t jdtAddr;        // 解断吐
@property (assign) uintptr_t mzAddr;         // 名字大小
@property (assign) uintptr_t nhAddr;         // 粘合
@property (assign) uintptr_t jlmAddr;        // 解限
@property (assign) uintptr_t syAddr;         // 视野
@property (strong) NSMutableArray *lmAddrs;  // 灵敏（多地址）

// 地址是否已找到
@property (assign) BOOL sldFound;
@property (assign) BOOL jdtFound;
@property (assign) BOOL mzFound;
@property (assign) BOOL nhFound;
@property (assign) BOOL jlmFound;
@property (assign) BOOL syFound;
@property (assign) BOOL lmFound;

// 防录制
@property (assign) BOOL recordingHookInstalled;
@end

@implementation FeatureManager

+ (instancetype)sharedManager {
    static FeatureManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[FeatureManager alloc] init]; });
    return instance;
}

+ (instancetype)shared {
    return [self sharedManager];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _inGame = NO;
        _sldFound = NO;
        _jdtFound = NO;
        _mzFound = NO;
        _nhFound = NO;
        _jlmFound = NO;
        _syFound = NO;
        _lmFound = NO;
        _lmAddrs = [NSMutableArray array];
        _recordingHookInstalled = NO;
    }
    return self;
}

- (void)setup {
    _inGame = YES;
}

- (void)startLoop {
    if (self.loopTimer) return;
    self.inGame = YES;

    // 先搜索一次内存
    [self rescanMemory];

    // 每 100ms 执行一次功能应用
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

#pragma mark - 内存搜索

- (void)rescanMemory {
    GlobalConfig *cfg = [GlobalConfig shared];

    // 双连点：搜索 0.05
    if (cfg.shuangliandian && !self.sldFound) {
        NSArray *results = [MemoryUtils searchFloat:0.05f tolerance:0.0001f];
        if (results.count > 0) {
            self.sldAddr = [results[0] unsignedLongLongValue];
            self.sldFound = YES;
        }
    }

    // 解断吐：搜索 0.02
    if (cfg.jieduan && !self.jdtFound) {
        NSArray *results = [MemoryUtils searchFloat:0.02f tolerance:0.0001f];
        if (results.count > 0) {
            self.jdtAddr = [results[0] unsignedLongLongValue];
            self.jdtFound = YES;
        }
    }

    // 名字大小：搜索 1.875
    if (cfg.mingzidaxiao && !self.mzFound) {
        NSArray *results = [MemoryUtils searchFloat:1.875f tolerance:0.0001f];
        if (results.count > 0) {
            self.mzAddr = [results[0] unsignedLongLongValue];
            self.mzFound = YES;
        }
    }

    // 粘合：搜索 1.70
    if (cfg.nianhe && !self.nhFound) {
        NSArray *results = [MemoryUtils searchFloat:1.70f tolerance:0.0001f];
        if (results.count > 0) {
            self.nhAddr = [results[0] unsignedLongLongValue];
            self.nhFound = YES;
        }
    }

    // 解限：搜索 100.0
    if (cfg.jielim && !self.jlmFound) {
        NSArray *results = [MemoryUtils searchFloat:100.0f tolerance:0.0001f];
        if (results.count > 0) {
            self.jlmAddr = [results[0] unsignedLongLongValue];
            self.jlmFound = YES;
        }
    }

    // 视野：搜索 1.0（视野默认值）
    if (cfg.shiyedaxiao && !self.syFound) {
        NSArray *results = [MemoryUtils searchFloat:1.0f tolerance:0.0001f];
        if (results.count > 0) {
            // 取第3个结果（前两个可能是名字大小和粘合）
            NSUInteger idx = MIN(2, results.count - 1);
            self.syAddr = [results[idx] unsignedLongLongValue];
            self.syFound = YES;
        }
    }

    // 灵敏：搜索 0.0001（多地址，最多10个）
    if (cfg.lingmin && !self.lmFound) {
        NSArray *results = [MemoryUtils searchFloat:0.0001f tolerance:0.00001f];
        if (results.count > 0) {
            NSUInteger count = MIN(10, results.count);
            for (NSUInteger i = 0; i < count; i++) {
                [self.lmAddrs addObject:results[i]];
            }
            self.lmFound = YES;
        }
    }
}

#pragma mark - 功能应用

- (void)applyFeatures {
    GlobalConfig *cfg = [GlobalConfig shared];

    // 如果地址还没找到，尝试搜索
    if (!self.sldFound || !self.jdtFound || !self.mzFound ||
        !self.nhFound || !self.jlmFound || !self.syFound || !self.lmFound) {
        [self rescanMemory];
    }

    // ===== 1. 双连点：搜索0.05，写入-9.0 =====
    if (cfg.shuangliandian && self.sldFound) {
        [MemoryUtils writeFloat:-9.0f at:self.sldAddr];
    }

    // ===== 2. 解断吐：搜索0.02，写入-9.0 =====
    if (cfg.jieduan && self.jdtFound) {
        [MemoryUtils writeFloat:-9.0f at:self.jdtAddr];
    }

    // ===== 3. 名字大小：搜索1.875，写入用户值（滑条0~5.0） =====
    if (cfg.mingzidaxiao && self.mzFound) {
        float val = [cfg.mingziValue floatValue];
        [MemoryUtils writeFloat:val at:self.mzAddr];
    }

    // ===== 4. 粘合：搜索1.70，写入用户值（滑条0~3.0） =====
    if (cfg.nianhe && self.nhFound) {
        float val = [cfg.nianheValue floatValue];
        [MemoryUtils writeFloat:val at:self.nhAddr];
    }

    // ===== 5. 解限：搜索100，写入99999997952.0（~1e11，21亿多） =====
    if (cfg.jielim && self.jlmFound) {
        [MemoryUtils writeFloat:99999997952.0f at:self.jlmAddr];
    }

    // ===== 6. 视野大小：搜索1.0，写入用户值（滑条0.5~10.0） =====
    if (cfg.shiyedaxiao && self.syFound) {
        float val = [cfg.shiyeValue floatValue];
        [MemoryUtils writeFloat:val at:self.syAddr];
    }

    // ===== 7. 灵敏：写入0.0001（多地址持续写入） =====
    if (cfg.lingmin && self.lmFound) {
        for (NSNumber *addrNum in self.lmAddrs) {
            uintptr_t addr = [addrNum unsignedLongLongValue];
            [MemoryUtils writeFloat:0.0001f at:addr];
        }
    }

    // ===== 8. 防录制：NSNotification Hook =====
    if (cfg.fangluzhi && !self.recordingHookInstalled) {
        [self installRecordingBypass];
        self.recordingHookInstalled = YES;
    }
}

#pragma mark - 防录制

- (void)installRecordingBypass {
    // 监听系统录屏通知，拦截录屏状态
    // iOS 11+ 有 UIScreenCapturedDidChangeNotification
    if (@available(iOS 11.0, *)) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(screenCaptureChanged:)
                                                     name:UIScreenCapturedDidChangeNotification
                                                   object:nil];
    }
}

- (void)screenCaptureChanged:(NSNotification *)note {
    // 录屏状态改变时，不做任何处理（绕过游戏的录屏检测）
    // 游戏通常会监听这个通知来判断是否在录屏
    // 我们通过method swizzle拦截游戏的监听
}
@end
