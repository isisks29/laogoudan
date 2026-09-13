// FeatureManager.h — 功能开关管理器
#import <Foundation/Foundation.h>

@interface FeatureManager : NSObject
+ (instancetype)shared;
+ (instancetype)sharedManager;

- (void)setup;
- (void)startLoop;      // 启动功能循环（必须调用！）
- (void)stopLoop;
- (void)applyFeatures;  // 应用所有已开启的功能
- (void)rescanMemory;   // 重新搜索内存（预热）
@end
