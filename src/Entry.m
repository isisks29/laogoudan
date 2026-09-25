// Entry.m — 测试版本：只创建UI，不做任何其他操作
// 用来测试是不是UI被游戏检测到了

#import "UI/TweakUI.h"
#import "AntiDetect.h"

__attribute__((constructor))
static void TestEntry(void) {
    NSLog(@"[Test] TestEntry started!");
    
    // 只安装反检测
    [[AntiDetect sharedInstance] startProtect];
    
    // 只创建UI
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        NSLog(@"[Test] Showing UI...");
        [TweakUI showFloatingWindow];
        NSLog(@"[Test] UI shown!");
    });
}
