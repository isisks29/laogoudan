// AntiDetect.h — 反检测（安全版：method swizzle，不用fishhook）
#import <Foundation/Foundation.h>

@interface AntiDetect : NSObject
+ (instancetype)sharedInstance;
- (void)startProtect;
+ (void)installAll;

// 录屏状态
+ (BOOL)isScreenCaptured;
+ (void)setRecordingBypass:(BOOL)enabled;
@end
