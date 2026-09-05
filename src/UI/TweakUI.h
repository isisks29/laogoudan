// TweakUI.h — 悬浮窗 UI（简约风格，三个标签页）
#ifndef TWEAK_UI_H
#define TWEAK_UI_H

#import <UIKit/UIKit.h>

@interface TweakUI : NSObject

+ (instancetype)shared;
+ (void)showFloatingWindow;
// 显示悬浮按钮
- (void)show;

// 隐藏整个 UI
- (void)hide;

// 刷新 UI（配置改变时调用）
- (void)refresh;

@end

#endif // TWEAK_UI_H
