// MacroManager.h — 宏操作管理器
// 核心原理：直接调用游戏的 IL2CPP 方法（如 set_skillFeedPress），
// 而不是模拟触摸事件，所以完全不影响其他手指的操作
//
// 三个宏：
//   16分  - 按住循环（高频率连续吐球）
//   吐球  - 按住循环（正常频率连续吐球）
//   4分   - 点击触发（点两次，触发分身）
//
// 每个宏都可以设置：按钮大小、位置、点击间隔、单次点击时长
#ifndef MACRO_MANAGER_H
#define MACRO_MANAGER_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Config.h"

@interface MacroManager : NSObject

+ (instancetype)shared;

// 创建所有宏按钮（添加到游戏窗口上）
- (void)setupMacroButtonsInWindow:(UIWindow *)window;

// 显示/隐藏所有宏按钮
- (void)setMacroButtonsHidden:(BOOL)hidden;

// 更新按钮位置（配置改变时调用）
- (void)updateButtonPositions;

// 手动触发宏（用于 UI 测试）
- (void)triggerMacro:(NSInteger)type;  // 0=16分, 1=吐球, 2=4分

@end

#endif // MACRO_MANAGER_H
