#include <dlfcn.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Config.h"
#import "AntiDetect.h"
#import "FeatureManager.h"
#import "MacroManager.h"
#import "UI/TweakUI.h"
#import "MethodSwap.h"

__attribute__((constructor))
void dylib_initialize(void)
{
    @autoreleasepool {
        // 先加载配置（纯 NSUserDefaults，constructor 里安全）
        [[GlobalConfig shared] load];

        // 等应用启动完成后再执行 fishhook 和 UI，避免 constructor 阶段崩溃
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
                        [[AntiDetect sharedInstance] startProtect];
                        [[FeatureManager sharedManager] setup];
                        [[MacroManager shared] setup];
                        [TweakUI showFloatingWindow];
                    }];

        // fallback：3秒后还没收到通知（注入较晚时），直接执行
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            if (observer) {
                [[NSNotificationCenter defaultCenter] removeObserver:observer];
                observer = nil;
                [[AntiDetect sharedInstance] startProtect];
                [[FeatureManager sharedManager] setup];
                [[MacroManager shared] setup];
                [TweakUI showFloatingWindow];
            }
        });
    }
}
