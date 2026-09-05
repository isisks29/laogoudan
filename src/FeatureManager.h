// FeatureManager.h — 功能开关管理器
// 每帧循环检查所有功能开关，执行对应的内存修改或 IL2CPP 调用
#ifndef FEATURE_MANAGER_H
#define FEATURE_MANAGER_H

#import <Foundation/Foundation.h>

@interface FeatureManager : NSObject

+ (instancetype)shared;

// 启动主循环（在进入游戏时调用）
- (void)startLoop;
- (void)stopLoop;

// 手动触发一次功能应用（用于开关切换时立即生效）
- (void)applyFeatures;

// 重新搜索内存地址（游戏更新或地址变化时调用）
- (void)rescanMemory;

@end

#endif // FEATURE_MANAGER_H
