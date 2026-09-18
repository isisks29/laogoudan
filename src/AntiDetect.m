// AntiDetect.m — 安全反检测（只保留最基础的 hook）
#import "AntiDetect.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL g_isScreenCaptured = NO;

@implementation AntiDetect

+ (instancetype)sharedInstance {
    static AntiDetect *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (void)startProtect {
    // 监听 UIApplicationDidFinishLaunchingNotification，延迟初始化
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                        object:nil
                                                         queue:[NSOperationQueue mainQueue]
                                                    usingBlock:^(NSNotification *note) {
        // 再延迟 1 秒，确保游戏完全启动
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            [AntiDetect installAll];
        });
    }];
}

+ (void)installAll {
    // 只 hook 最基础的，不要加太多
    [self installFileHide];
    [self installRecordingBypass];
}

+ (BOOL)isScreenCaptured { return g_isScreenCaptured; }

#pragma mark - 1. 文件检测绕过（只 hook 这两个）

+ (void)installFileHide {
    Method m1 = class_getInstanceMethod([NSFileManager class], @selector(fileExistsAtPath:));
    Method m2 = class_getInstanceMethod([NSFileManager class], @selector(ad_fileExistsAtPath:));
    if (m1 && m2) method_exchangeImplementations(m1, m2);
    
    Method m3 = class_getInstanceMethod([NSFileManager class], @selector(isReadableFileAtPath:));
    Method m4 = class_getInstanceMethod([NSFileManager class], @selector(ad_isReadableFileAtPath:));
    if (m3 && m4) method_exchangeImplementations(m3, m4);
}

#pragma mark - 2. 录屏状态监听

+ (void)installRecordingBypass {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIScreenCapturedDidChangeNotification
                                                        object:nil
                                                         queue:[NSOperationQueue mainQueue]
                                                    usingBlock:^(NSNotification *note) {
        g_isScreenCaptured = [UIScreen mainScreen].isCaptured;
    }];
}

@end

@implementation NSFileManager (AntiDetect)

- (BOOL)ad_fileExistsAtPath:(NSString *)path {
    if (!path) return NO;
    // 只拦截明确的越狱路径
    if ([path hasPrefix:@"/Applications/Cydia.app"] ||
        [path hasPrefix:@"/Applications/Sileo.app"] ||
        [path hasPrefix:@"/Library/MobileSubstrate"] ||
        [path hasPrefix:@"/usr/lib/substrate"]) {
        return NO;
    }
    return [self ad_fileExistsAtPath:path];
}

- (BOOL)ad_isReadableFileAtPath:(NSString *)path {
    if (!path) return NO;
    if ([path hasPrefix:@"/Applications/Cydia.app"] ||
        [path hasPrefix:@"/Applications/Sileo.app"] ||
        [path hasPrefix:@"/Library/MobileSubstrate"] ||
        [path hasPrefix:@"/usr/lib/substrate"]) {
        return NO;
    }
    return [self ad_isReadableFileAtPath:path];
}

@end
