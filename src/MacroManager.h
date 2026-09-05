#import <UIKit/UIKit.h>
#import "Config.h"
#ifndef MACRO_MANAGER_H
#define MACRO_MANAGER_H
@interface MacroManager : NSObject
+ (instancetype)shared;
- (void)setup;
- (void)setupMacroButtonsInWindow:(UIWindow *)window;
- (void)updateButtonPositions;
- (void)setMacroButtonsHidden:(BOOL)hidden;
- (void)triggerMacro:(NSInteger)type;
@end
#endif
