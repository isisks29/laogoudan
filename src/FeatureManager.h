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
@end
#endif // FEATURE_MANAGER_H
