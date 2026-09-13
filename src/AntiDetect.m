// AntiDetect.m — 完整反检测（参考JuziHub安全方式：method swizzle + bundle ID伪装 + 录屏绕过）
#import "AntiDetect.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL g_recordingBypass = NO;
static BOOL g_isScreenCaptured = NO;

@implementation AntiDetect

+ (instancetype)sharedInstance {
    static AntiDetect *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (void)startProtect {
    [AntiDetect installAll];
}

+ (void)installAll {
    [self installJailbreakHide];       // 1. 越狱路径隐藏
    [self installBundleIdFake];        // 2. bundle ID伪装
    [self installRecordingBypass];      // 3. 录屏绕过
}

+ (BOOL)isScreenCaptured { return g_isScreenCaptured; }
+ (void)setRecordingBypass:(BOOL)enabled { g_recordingBypass = enabled; }

#pragma mark - 1. 越狱路径隐藏（NSFileManager swizzle，安全）

+ (void)installJailbreakHide {
    Method orig1 = class_getInstanceMethod([NSFileManager class], @selector(fileExistsAtPath:));
    Method new1 = class_getInstanceMethod([NSFileManager class], @selector(ad_fileExistsAtPath:));
    if (orig1 && new1) method_exchangeImplementations(orig1, new1);
    
    // 也隐藏 access 调用
    Method orig2 = class_getInstanceMethod([NSFileManager class], @selector(isReadableFileAtPath:));
    Method new2 = class_getInstanceMethod([NSFileManager class], @selector(ad_isReadableFileAtPath:));
    if (orig2 && new2) method_exchangeImplementations(orig2, new2);
}

@end

@implementation NSFileManager (AntiDetect)
- (BOOL)ad_fileExistsAtPath:(NSString *)path {
    if (!path) return NO;
    NSArray *jb = @[@"/Applications/Cydia.app", @"/Applications/Sileo.app",
                     @"/Library/MobileSubstrate", @"/bin/bash", @"/etc/apt",
                     @"/usr/sbin/sshd", @"/private/var/lib/apt"];
    for (NSString *p in jb) {
        if ([path containsString:p]) return NO;
    }
    return [self ad_fileExistsAtPath:path];
}
- (BOOL)ad_isReadableFileAtPath:(NSString *)path {
    if (!path) return NO;
    NSArray *jb = @[@"/Applications/Cydia.app", @"/Applications/Sileo.app",
                     @"/Library/MobileSubstrate", @"/bin/bash", @"/etc/apt"];
    for (NSString *p in jb) {
        if ([path containsString:p]) return NO;
    }
    return [self ad_isReadableFileAtPath:path];
}
@end

#pragma mark - 2. Bundle ID伪装（参考JuziHub R_a_xiNy_fake_bundleIdentifier）

@interface AntiDetect (BundleIdFake)
+ (void)installBundleIdFake;
@end

@implementation AntiDetect (BundleIdFake)

+ (void)installBundleIdFake {
    // 伪造 NSBundle bundleIdentifier
    Method orig = class_getInstanceMethod([NSBundle class], @selector(bundleIdentifier));
    Method new = class_getInstanceMethod([NSBundle class], @selector(ad_bundleIdentifier));
    if (orig && new) method_exchangeImplementations(orig, new);
    
    // 伪造 objectForInfoDictionaryKey（隐藏修改器相关的key）
    Method orig2 = class_getInstanceMethod([NSBundle class], @selector(objectForInfoDictionaryKey:));
    Method new2 = class_getInstanceMethod([NSBundle class], @selector(ad_objectForInfoDictionaryKey:));
    if (orig2 && new2) method_exchangeImplementations(orig2, new2);
}

@end

@implementation NSBundle (AntiDetect)
- (NSString *)ad_bundleIdentifier {
    NSString *real = [self ad_bundleIdentifier];
    // 如果是游戏主bundle，返回真实ID（不需要伪装）
    // 如果是修改器dylib的bundle，伪装成游戏的
    if ([real containsString:@"GameTweak"] || [real containsString:@"Tweak"]) {
        return @"com.juzi.balls";
    }
    return real;
}
- (id)ad_objectForInfoDictionaryKey:(NSString *)key {
    id val = [self ad_objectForInfoDictionaryKey:key];
    // 隐藏修改器相关的key
    if ([key containsString:@"Tweak"] || [key containsString:@"GameTweak"]) {
        return nil;
    }
    return val;
}
@end

#pragma mark - 3. 录屏绕过（参考JuziHub TBManager.setRecordingBypass:）

@interface AntiDetect (RecordingBypass)
+ (void)installRecordingBypass;
@end

@implementation AntiDetect (RecordingBypass)

+ (void)installRecordingBypass {
    // 监听录屏状态变化
    [[NSNotificationCenter defaultCenter] addObserverForName:UIScreenCapturedDidChangeNotification
                                                        object:nil
                                                         queue:[NSOperationQueue mainQueue]
                                                    usingBlock:^(NSNotification *note) {
        g_isScreenCaptured = [UIScreen mainScreen].isCaptured;
        // 发送通知，让UI层隐藏修改器界面
        [[NSNotificationCenter defaultCenter] postNotificationName:@"JHRecordingBypassChanged" object:nil];
    }];
}

@end
