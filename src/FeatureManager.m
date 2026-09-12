// FeatureManager.m — 功能开关管理器实现
// 8种功能：双连点、解断吐、名字大小、粘合、解限、视野、灵敏、防录制
// 改进：后台搜索、16ms快速写入、多地址写入、结果数量限制
#import "FeatureManager.h"
#import "Config.h"
#import "MemoryUtils.h"

@interface FeatureManager ()
@property (strong) NSTimer *loopTimer;
@property (assign) BOOL inGame;
@property (assign) BOOL searching;  // 是否正在搜索（避免重复搜索）

// 功能地址缓存（多地址，增加成功率）
@property (strong) NSMutableArray *sldAddrs;   // 双连点
@property (strong) NSMutableArray *jdtAddrs;   // 解断吐
@property (strong) NSMutableArray *mzAddrs;    // 名字大小
@property (strong) NSMutableArray *nhAddrs;    // 粘合
@property (strong) NSMutableArray *jlmAddrs;   // 解限
@property (strong) NSMutableArray *syAddrs;    // 视野
@property (strong) NSMutableArray *lmAddrs;    // 灵敏

// 地址是否已找到
@property (assign) BOOL sldFound;
@property (assign) BOOL jdtFound;
@property (assign) BOOL mzFound;
@property (assign) BOOL nhFound;
@property (assign) BOOL jlmFound;
@property (assign) BOOL syFound;
@property (assign) BOOL lmFound;
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
        _searching = NO;
        _sldFound = NO;
        _jdtFound = NO;
        _mzFound = NO;
        _nhFound = NO;
        _jlmFound = NO;
        _syFound = NO;
        _lmFound = NO;
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

- (void)setup {
    _inGame = YES;
}

- (void)startLoop {
    if (self.loopTimer) return;
    self.inGame = YES;

    // 后台线程搜索，避免UI卡顿
    [self rescanMemoryInBackground];

    // 每 16ms 执行一次（60fps，游戏每帧重置这些值）
    self.loopTimer = [NSTimer scheduledTimerWithTimeInterval:0.016
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

#pragma mark - 后台内存搜索

- (void)rescanMemoryInBackground {
    if (self.searching) return;
    self.searching = YES;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [self rescanMemory];
        self.searching = NO;
    });
}

- (void)rescanMemory {
    GlobalConfig *cfg = [GlobalConfig shared];
    const NSUInteger kMaxResults = 30;  // 限制结果数量，避免卡顿

    // 双连点：搜索 0.05
    if (cfg.shuangliandian && !self.sldFound) {
        NSArray *results = [MemoryUtils searchFloat:0.05f tolerance:0.0001f maxResults:kMaxResults];
        if (results.count > 0) {
            self.sldAddrs = [results mutableCopy];
            self.sldFound = YES;
        }
    }

    // 解断吐：搜索 0.02
    if (cfg.jieduan && !self.jdtFound) {
        NSArray *results = [MemoryUtils searchFloat:0.02f tolerance:0.0001f maxResults:kMaxResults];
        if (results.count > 0) {
            self.jdtAddrs = [results mutableCopy];
            self.jdtFound = YES;
        }
    }

    // 名字大小：搜索 1.875
    if (cfg.mingzidaxiao && !self.mzFound) {
        NSArray *results = [MemoryUtils searchFloat:1.875f tolerance:0.0001f maxResults:kMaxResults];
        if (results.count > 0) {
            self.mzAddrs = [results mutableCopy];
            self.mzFound = YES;
        }
    }

    // 粘合：搜索 1.70
    if (cfg.nianhe && !self.nhFound) {
        NSArray *results = [MemoryUtils searchFloat:1.70f tolerance:0.0001f maxResults:kMaxResults];
        if (results.count > 0) {
            self.nhAddrs = [results mutableCopy];
            self.nhFound = YES;
        }
    }

    // 解限：搜索 100.0
    if (cfg.jielim && !self.jlmFound) {
        NSArray *results = [MemoryUtils searchFloat:100.0f tolerance:0.0001f maxResults:kMaxResults];
        if (results.count > 0) {
            self.jlmAddrs = [results mutableCopy];
            self.jlmFound = YES;
        }
    }

    // 视野：搜索 1.0
    if (cfg.shiyedaxiao && !self.syFound) {
        NSArray *results = [MemoryUtils searchFloat:1.0f tolerance:0.0001f maxResults:kMaxResults];
        if (results.count > 0) {
            self.syAddrs = [results mutableCopy];
            self.syFound = YES;
        }
    }

    // 灵敏：搜索 0.0001（多地址）
    if (cfg.lingmin && !self.lmFound) {
        NSArray *results = [MemoryUtils searchFloat:0.0001f tolerance:0.00001f maxResults:kMaxResults];
        if (results.count > 0) {
            self.lmAddrs = [results mutableCopy];
            self.lmFound = YES;
        }
    }
}

#pragma mark - 功能应用（16ms循环，多地址写入）

- (void)applyFeatures {
    GlobalConfig *cfg = [GlobalConfig shared];

    // 如果地址还没找到，后台继续搜索
    if (!self.sldFound || !self.jdtFound || !self.mzFound ||
        !self.nhFound || !self.jlmFound || !self.syFound || !self.lmFound) {
        [self rescanMemoryInBackground];
    }

    // ===== 1. 双连点：写入-9.0（多地址） =====
    if (cfg.shuangliandian && self.sldFound) {
        for (NSNumber *addrNum in self.sldAddrs) {
            [MemoryUtils writeFloat:-9.0f at:[addrNum unsignedLongLongValue]];
        }
    }

    // ===== 2. 解断吐：写入-9.0（多地址） =====
    if (cfg.jieduan && self.jdtFound) {
        for (NSNumber *addrNum in self.jdtAddrs) {
            [MemoryUtils writeFloat:-9.0f at:[addrNum unsignedLongLongValue]];
        }
    }

    // ===== 3. 名字大小：写入用户值（多地址） =====
    if (cfg.mingzidaxiao && self.mzFound) {
        float val = [cfg.mingziValue floatValue];
        for (NSNumber *addrNum in self.mzAddrs) {
            [MemoryUtils writeFloat:val at:[addrNum unsignedLongLongValue]];
        }
    }

    // ===== 4. 粘合：写入用户值（多地址） =====
    if (cfg.nianhe && self.nhFound) {
        float val = [cfg.nianheValue floatValue];
        for (NSNumber *addrNum in self.nhAddrs) {
            [MemoryUtils writeFloat:val at:[addrNum unsignedLongLongValue]];
        }
    }

    // ===== 5. 解限：写入99999997952.0（多地址） =====
    if (cfg.jielim && self.jlmFound) {
        for (NSNumber *addrNum in self.jlmAddrs) {
            [MemoryUtils writeFloat:99999997952.0f at:[addrNum unsignedLongLongValue]];
        }
    }

    // ===== 6. 视野大小：写入用户值（多地址） =====
    if (cfg.shiyedaxiao && self.syFound) {
        float val = [cfg.shiyeValue floatValue];
        for (NSNumber *addrNum in self.syAddrs) {
            [MemoryUtils writeFloat:val at:[addrNum unsignedLongLongValue]];
        }
    }

    // ===== 7. 灵敏：写入0.0001（多地址） =====
    if (cfg.lingmin && self.lmFound) {
        for (NSNumber *addrNum in self.lmAddrs) {
            [MemoryUtils writeFloat:0.0001f at:[addrNum unsignedLongLongValue]];
        }
    }
}

@end
