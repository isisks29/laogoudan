// FeatureManager.h — 功能开关管理器
// 实现8种功能：双连点、解断吐、名字大小、粘合、解限、视野、灵敏、防录制
#ifndef FEATURE_MANAGER_H
#define FEATURE_MANAGER_H
#import <Foundation/Foundation.h>

@interface FeatureManager : NSObject
+ (instancetype)sharedManager;
+ (instancetype)shared;
- (void)setup;
// 启动主循环（在进入游戏时调用）
- (void)startLoop;
- (void)stopLoop;
// 手动触发一次功能应用（用于开关切换时立即生效）
- (void)applyFeatures;
// 重新搜索内存地址（游戏更新或地址变化时调用）
- (void)rescanMemory;

// 调试信息：每个功能搜到的地址数量（用于UI显示）
@property (assign, readonly) NSUInteger sldResultCount;   // 双连点
@property (assign, readonly) NSUInteger jdtResultCount;   // 解断吐
@property (assign, readonly) NSUInteger mzResultCount;    // 名字大小
@property (assign, readonly) NSUInteger nhResultCount;    // 粘合
@property (assign, readonly) NSUInteger jlmResultCount;   // 解限
@property (assign, readonly) NSUInteger syResultCount;    // 视野
@property (assign, readonly) NSUInteger lmResultCount;    // 灵敏
@end
#endif // FEATURE_MANAGER_H
