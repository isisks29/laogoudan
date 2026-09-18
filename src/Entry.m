#include <dlfcn.h>
#import <dlfcn.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Config.h"
#import "MacroManager.h"
#import "UI/TweakUI.h"

__attribute__((constructor))
void dylib_initialize(void)
{
    @autoreleasepool {
        [[GlobalConfig shared] load];
        [[MacroManager shared] setup];
        
        __block id noteObserver = nil;
        noteObserver = [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationDidFinishLaunchingNotification
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(NSNotification * _Nonnull note) {
            if(noteObserver){
                [[NSNotificationCenter defaultCenter] removeObserver:noteObserver];
                noteObserver = nil;
            }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSLog(@"[GT] try show floating ui");
                [TweakUI showFloatingWindow];
            });
        }];
    }
}
