#include <dlfcn.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Config.h"
#import "AntiDetect.h"
#import "FeatureManager.h"
#import "MacroManager.h"
#import "PeelManager.h"
#import "UI/TweakUI.h"

static void doInitialize(void);

__attribute__((constructor))
void dylib_initialize(void)
{
    @autoreleasepool {
        [[GlobalConfig shared] load];
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
                        doInitialize();
                    }];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            if (observer) {
                [[NSNotificationCenter defaultCenter] removeObserver:observer];
                observer = nil;
                doInitialize();
            }
        });
    }
}

static void doInitialize(void) {
    @autoreleasepool {
        [[AntiDetect sharedInstance] startProtect];
        [[FeatureManager sharedManager] startLoop];  // 关键：启动循环写入+内存搜索
        [[MacroManager shared] setup];
        [TweakUI showFloatingWindow];
        if ([GlobalConfig shared].peelEnabled) {
            [[PeelManager shared] startPeel];
        }
    }
}
