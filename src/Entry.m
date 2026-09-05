#include <dlfcn.h>
#import <Foundation/Foundation.h>
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
        [[AntiDetect sharedInstance] startProtect];
        [[GlobalConfig shared] load];
        [[FeatureManager sharedManager] setup];
        [[MacroManager shared] setup];
        dispatch_async(dispatch_get_main_queue(), ^{
            [TweakUI showFloatingWindow];
        });
    }
}
