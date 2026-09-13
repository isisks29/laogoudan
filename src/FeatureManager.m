// FeatureManager.m — 8种数值功能实现（参考JuziHub NCFCtrl架构：预热搜索+验证+高频冻结写入）
#import "FeatureManager.h"
#import "Config.h"
#import "MemoryUtils.h"
#import <UIKit/UIKit.h>

@interface FeatureManager ()
@property (strong) NSTimer *freezeTimer;      // 高频冻结写入定时器
@property (assign) BOOL isSearching;           // 是否正在搜索（防止重复搜索）

// 每个功能的目标地址数组（JuziHub方式：写入所有匹配地址）
@property (strong) NSMutableArray<NSNumber *> *sldAddrs;    // 双连点
@property (strong) NSMutableArray<NSNumber *> *jdtAddrs;    // 解断吐
@property (strong) NSMutableArray<NSNumber *> *mzAddrs;     // 名字大小
@property (strong) NSMutableArray<NSNumber *> *nhAddrs;     // 粘合
@property (strong) NSMutableArray<NSNumber *> *jlmAddrs;    // 解限
@property (strong) NSMutableArray<NSNumber *> *syAddrs;     // 视野
@property (strong) NSMutableArray<NSNumber *> *lmAddrs;     // 摇杆灵敏

// 地址是否已找到
@property (assign) BOOL sldReady;
@property (assign) BOOL jdtReady;
@property (assign) BOOL mzReady;
@property (assign) BOOL nhReady;
@property (assign) BOOL jlmReady;
@property (assign) BOOL syReady;
@property (assign) BOOL lmReady;
@end

@implementation FeatureManager

+ (instancetype)shared {
    static FeatureManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[FeatureManager alloc] init]; });
    return instance;
}

+ (instancetype)sharedManager { return [self shared]; }

- (instancetype)init {
    self = [super init];
    if (self) {
        _sldAddrs = [NSMutableArray array];
        _jdtAddrs = [NSMutableArray array];
        _mzAddrs = [NSMutableArray array];
        _nhAddrs = [NSMutableArray array];
        _jlmAddrs = [NSMutableArray array];
        _syAddrs = [NSMutableArray array];
        _lmAddrs = [NSMutableArray array];
    }
    return self;
}

- (void)setup { }

- (void)startLoop {
    if (self.freezeTimer) return;
    
    // 延迟1.5秒后在后台线程预热搜索（参考JuziHub prewarmWithRetries）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC),
                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self rescanMemory];
    });
    
    // 10ms高频冻结写入（100fps，足够让游戏无法恢复原值）
    self.freezeTimer = [NSTimer scheduledTimerWithTimeInterval:0.01
                                                           target:self
                                                         selector:@selector(applyFeatures)
                                                         userInfo:nil
                                                          repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.freezeTimer forMode:NSRunLoopCommonModes];
}

- (void)stopLoop {
    [self.freezeTimer invalidate];
    self.freezeTimer = nil;
}

#pragma mark - 预热搜索（参考JuziHub NCFCtrl.prewarmWithRetries）

- (void)rescanMemory {
    if (self.isSearching) return;
    self.isSearching = YES;
    
    GlobalConfig *cfg = [GlobalConfig shared];
    
    // 1. 双连点：搜索 0.05（dylib中仅出现2次，非常精确）
    if (cfg.shuangliandian && !self.sldReady) {
        NSArray *r = [MemoryUtils searchFloat:0.05f maxResults:10];
        if (r.count > 0) {
            self.sldAddrs = [r mutableCopy];
            self.sldReady = YES;
        }
    }
    
    // 2. 解断吐：搜索 0.02
    if (cfg.jieduantu && !self.jdtReady) {
        NSArray *r = [MemoryUtils searchFloat:0.02f maxResults:10];
        if (r.count > 0) {
            self.jdtAddrs = [r mutableCopy];
            self.jdtReady = YES;
        }
    }
    
    // 3. 名字大小：搜索 1.875（出现28次，限制结果数）
    if (cfg.mingzidaxiao && !self.mzReady) {
        NSArray *r = [MemoryUtils searchFloat:1.875f maxResults:20];
        if (r.count > 0) {
            self.mzAddrs = [r mutableCopy];
            self.mzReady = YES;
        }
    }
    
    // 4. 粘合：搜索 1.70（dylib中仅出现1次，非常精确）
    if (cfg.nianhe && !self.nhReady) {
        NSArray *r = [MemoryUtils searchFloat:1.70f maxResults:10];
        if (r.count > 0) {
            self.nhAddrs = [r mutableCopy];
            self.nhReady = YES;
        }
    }
    
    // 5. 解限：搜索 100（int），按int写入 2^32
    if (cfg.jielim && !self.jlmReady) {
        NSArray *r = [MemoryUtils searchInt:100];
        if (r.count > 0) {
            // 只取前5个地址（避免写入太多导致卡顿）
            NSRange range = NSMakeRange(0, MIN(5, r.count));
            self.jlmAddrs = [[r subarrayWithRange:range] mutableCopy];
            self.jlmReady = YES;
        }
    }
    
    // 6. 视野大小：搜索 1.0（出现太多，用容差+限制，只取前10个）
    if (cfg.shiyedaxiao && !self.syReady) {
        NSArray *r = [MemoryUtils searchFloat:1.0f tolerance:0.001f maxResults:10];
        if (r.count > 0) {
            self.syAddrs = [r mutableCopy];
            self.syReady = YES;
        }
    }
    
    // 7. 摇杆灵敏：搜索 0.01（dylib中仅出现2次），写入 0.0001
    if (cfg.lingmin && !self.lmReady) {
        NSArray *r = [MemoryUtils searchFloat:0.01f maxResults:10];
        if (r.count > 0) {
            self.lmAddrs = [r mutableCopy];
            self.lmReady = YES;
        }
    }
    
    self.isSearching = NO;
}

#pragma mark - 高频冻结写入（参考JuziHub NCFCtrl.startFreeze，写入所有匹配地址）

- (void)applyFeatures {
    GlobalConfig *cfg = [GlobalConfig shared];
    
    // 1. 双连点：写入 -9.0
    if (cfg.shuangliandian && self.sldReady) {
        for (NSNumber *addr in self.sldAddrs) {
            [MemoryUtils writeFloat:-9.0f at:addr.unsignedLongLongValue];
        }
    }
    
    // 2. 解断吐：写入 -9.0
    if (cfg.jieduantu && self.jdtReady) {
        for (NSNumber *addr in self.jdtAddrs) {
            [MemoryUtils writeFloat:-9.0f at:addr.unsignedLongLongValue];
        }
    }
    
    // 3. 名字大小：写入用户自定义值
    if (cfg.mingzidaxiao && self.mzReady) {
        float val = [cfg.mingziValue floatValue];
        for (NSNumber *addr in self.mzAddrs) {
            [MemoryUtils writeFloat:val at:addr.unsignedLongLongValue];
        }
    }
    
    // 4. 粘合：写入用户自定义值
    if (cfg.nianhe && self.nhReady) {
        float val = [cfg.nianheValue floatValue];
        for (NSNumber *addr in self.nhAddrs) {
            [MemoryUtils writeFloat:val at:addr.unsignedLongLongValue];
        }
    }
    
    // 5. 解限：写入 2^32（int）
    if (cfg.jielim && self.jlmReady) {
        int32_t val = (int32_t)[cfg.jielimWriteValue intValue];
        for (NSNumber *addr in self.jlmAddrs) {
            [MemoryUtils writeInt:val at:addr.unsignedLongLongValue];
        }
    }
    
    // 6. 视野大小：写入用户自定义值
    if (cfg.shiyedaxiao && self.syReady) {
        float val = [cfg.shiyeValue floatValue];
        for (NSNumber *addr in self.syAddrs) {
            [MemoryUtils writeFloat:val at:addr.unsignedLongLongValue];
        }
    }
    
    // 7. 摇杆灵敏：写入 0.0001
    if (cfg.lingmin && self.lmReady) {
        for (NSNumber *addr in self.lmAddrs) {
            [MemoryUtils writeFloat:0.0001f at:addr.unsignedLongLongValue];
        }
    }
    
    // 8. 防录制：通过NSNotification实现（在AntiDetect中）
}

@end
