// AntiDetect.m — 安全反检测（只保留验证过不闪退的hook，不用fishhook）
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
    [self installJailbreakHide];
    [self installBundleIdFake];
    [self installRecordingBypass];
}

+ (BOOL)isScreenCaptured { return g_isScreenCaptured; }
+ (void)setRecordingBypass:(BOOL)enabled { g_recordingBypass = enabled; }

#pragma mark - 1. 越狱路径隐藏

+ (void)installJailbreakHide {
    Method orig1 = class_getInstanceMethod([NSFileManager class], @selector(fileExistsAtPath:));
    Method new1 = class_getInstanceMethod([NSFileManager class], @selector(ad_fileExistsAtPath:));
    if (orig1 && new1) method_exchangeImplementations(orig1, new1);
    
    Method orig2 = class_getInstanceMethod([NSFileManager class], @selector(isReadableFileAtPath:));
    Method new2 = class_getInstanceMethod([NSFileManager class], @selector(ad_isReadableFileAtPath:));
    if (orig2 && new2) method_exchangeImplementations(orig2, new2);
}

#pragma mark - 2. Bundle ID伪装

+ (void)installBundleIdFake {
    Method orig = class_getInstanceMethod([NSBundle class], @selector(bundleIdentifier));
    Method new = class_getInstanceMethod([NSBundle class], @selector(ad_bundleIdentifier));
    if (orig && new) method_exchangeImplementations(orig, new);
    
    Method orig2 = class_getInstanceMethod([NSBundle class], @selector(objectForInfoDictionaryKey:));
    Method new2 = class_getInstanceMethod([NSBundle class], @selector(ad_objectForInfoDictionaryKey:));
    if (orig2 && new2) method_exchangeImplementations(orig2, new2);
}

#pragma mark - 3. 录屏状态监听

+ (void)installRecordingBypass {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIScreenCapturedDidChangeNotification
                                                        object:nil
                                                         queue:[NSOperationQueue mainQueue]
                                                    usingBlock:^(NSNotification *note) {
        g_isScreenCaptured = [UIScreen mainScreen].isCaptured;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"JHRecordingBypassChanged" object:nil];
    }];
}

@end

@implementation NSFileManager (AntiDetect)

- (BOOL)ad_fileExistsAtPath:(NSString *)path {
    if (!path) return NO;
    if ([path isEqualToString:@"/Applications/Cydia.app"] ||
        [path isEqualToString:@"/Applications/Sileo.app"] ||
        [path isEqualToString:@"/Applications/Zebra.app"] ||
        [path isEqualToString:@"/Library/MobileSubstrate"] ||
        [path isEqualToString:@"/usr/lib/substrate"] ||
        [path isEqualToString:@"/private/var/lib/apt"] ||
        [path isEqualToString:@"/bin/bash"] ||
        [path isEqualToString:@"/bin/sh"]) {
        return NO;
    }
    return [self ad_fileExistsAtPath:path];
}

- (BOOL)ad_isReadableFileAtPath:(NSString *)path {
    if (!path) return NO;
    if ([path isEqualToString:@"/Applications/Cydia.app"] ||
        [path isEqualToString:@"/Applications/Sileo.app"] ||
        [path isEqualToString:@"/Applications/Zebra.app"] ||
        [path isEqualToString:@"/Library/MobileSubstrate"] ||
        [path isEqualToString:@"/usr/lib/substrate"] ||
        [path isEqualToString:@"/private/var/lib/apt"]) {
        return NO;
    }
    return [self ad_isReadableFileAtPath:path];
}

@end

@implementation NSBundle (AntiDetect)

- (NSString *)ad_bundleIdentifier {
    NSString *real = [self ad_bundleIdentifier];
    if ([real isEqualToString:@"com.GameTweak.dylib"] ||
        [real hasSuffix:@".GameTweak"] ||
        [real hasSuffix:@".Inject"]) {
        return @"com.juzi.balls";
    }
    return real;
}

- (id)ad_objectForInfoDictionaryKey:(NSString *)key {
    return [self ad_objectForInfoDictionaryKey:key];
}

@end
