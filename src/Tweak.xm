// Tweak.xm — 主入口
// 整合：反检测 + 功能开关 + 宏操作 + UI
#import "AntiDetect.h"
#import "Config.h"
#import "FeatureManager.h"
#import "MacroManager.h"
#import "IL2CPPUtils.h"
#import "UI/TweakUI.h"

#import <UIKit/UIKit.h>

// ============================================================
// 构造函数：dylib 加载时执行
// ============================================================
%ctor {
    @autoreleasepool {
        // ===== 第一步：初始化反检测（必须最先）=====
        GlobalConfig *cfg = [GlobalConfig shared];
        if (cfg.antiDetectEnabled) {
            [AntiDetect installAll];
        }
        
        // ===== 第二步：初始化 IL2CPP 工具 =====
        [IL2CPPUtils initialize];
        
        // ===== 第三步：显示 UI（延迟到主线程）=====
        dispatch_async(dispatch_get_main_queue(), ^{
            [[TweakUI shared] show];
        });
        
        // ===== 第四步：监听游戏进入局内 =====
        // 通过 NSNotificationCenter 监听游戏的启动通知
        // 不同游戏的通知名不同，需要根据具体游戏修改
        [[NSNotificationCenter defaultCenter] addObserverForName:@"UIApplicationDidBecomeActiveNotification"
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            // 游戏启动后，延迟几秒让游戏初始化完成
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_MSEC),
                           dispatch_get_main_queue(), ^{
                [self onGameStarted];
            });
        }];
    }
}

// ============================================================
// 游戏启动后的初始化
// ============================================================
static void onGameStarted(void) {
    @autoreleasepool {
        // 启动功能管理器主循环
        [[FeatureManager shared] startLoop];
        
        // 设置宏按钮到游戏窗口
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        if (!keyWindow) {
            keyWindow = [[UIApplication sharedApplication].windows firstObject];
        }
        if (keyWindow) {
            [[MacroManager shared] setupMacroButtonsInWindow:keyWindow];
        }
    }
}

// ============================================================
// Hook 游戏的启动方法（可选，根据具体游戏修改）
// ============================================================
// 如果知道游戏的启动类和方法，可以直接 Hook，比监听通知更可靠
//
// %hook GameAppDelegate
// - (void)applicationDidBecomeActive:(UIApplication *)application {
//     %orig;
//     onGameStarted();
// }
// %end

// ============================================================
// Hook 游戏的进入局内方法（可选）
// ============================================================
// %hook GameSceneManager
// - (void)onEnterGame {
//     %orig;
//     [[FeatureManager shared] rescanMemory];
// }
// %end

// ============================================================
// 内存搜索触发（可选）
// ============================================================
// 当用户在 UI 中开启某个功能时，FeatureManager 会自动搜索内存
// 如果需要手动触发，可以调用：
// [[FeatureManager shared] rescanMemory];
