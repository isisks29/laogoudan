#include <dlfcn.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Config.h"
#import "AntiDetect.h"
#import "FeatureManager.h"
#import "MacroManager.h"
#import "PeelManager.h"
#import "UI/TweakUI.h"

__attribute__((constructor))
void dylib_initialize(void)
{
    @autoreleasepool {
        // 加载配置（纯 NSUserDefaults，constructor 里安全）
        [[GlobalConfig shared] load];

        // 等游戏启动完成后再初始化（避免 constructor 阶段 fishhook 崩溃）
        __block id observer = nil;
        observer = [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationDidFinishLaunchingNotification
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(NSNotification *note) {
                        if (observer) {
                            [[NSNotificationCenter defaultCenter] removeObserver:observer];
                            observer = nil;
                        }
                        [self doInitialize];
                    }];

        // fallback：3秒后还没收到通知就直接执行
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            if (observer) {
                [[NSNotificationCenter defaultCenter] removeObserver:observer];
                observer = nil;
                [self doInitialize];
            }
        });
    }
}

static void doInitialize(void) {
    @autoreleasepool {
        // 反检测：后台静默启用，不需要 UI 开关
        [[AntiDetect sharedInstance] startProtect];

        // 功能管理器
        [[FeatureManager sharedManager] setup];

        // 宏管理器
        [[MacroManager shared] setup];

        // 悬浮 UI
        [TweakUI showFloatingWindow];

        // 如果配置里开了去皮（默认关），自动启动
        if ([GlobalConfig shared].peelEnabled) {
            [[PeelManager shared] startPeel];
        }
    }
}
