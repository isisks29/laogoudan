// AntiDetect.m — 完整反检测（参考 ballsace 方式）
// 核心：伪装 bundle ID 为 com.juzi.balls
// 从 com.juzi.bals → com.juzi.balls

#import "AntiDetect.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static IMP orig_bundleIdentifier = NULL;
static IMP orig_objectForInfoDictionaryKey = NULL;

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
    NSLog(@"[AntiDetect] Installing...");
    
    // 1. 伪装 bundle ID（核心！）
    [self installBundleIdSpoof];
    
    // 2. 隐藏越狱路径（可选，但加上更安全）
    [self installJailbreakHide];
    
    NSLog(@"[AntiDetect] Install complete!");
}

#pragma mark - 1. Bundle ID 伪装（核心！）

+ (void)installBundleIdSpoof {
    // 第一个方法：bundleIdentifier
    Method m1 = class_getInstanceMethod([NSBundle class], @selector(bundleIdentifier));
    if (m1) {
        orig_bundleIdentifier = method_getImplementation(m1);
        method_setImplementation(m1, (IMP)new_bundleIdentifier);
        NSLog(@"[AntiDetect] Swizzled bundleIdentifier");
    }
    
    // 第二个方法：objectForInfoDictionaryKey:
    Method m2 = class_getInstanceMethod([NSBundle class], @selector(objectForInfoDictionaryKey:));
    if (m2) {
        orig_objectForInfoDictionaryKey = method_getImplementation(m2);
        method_setImplementation(m2, (IMP)new_objectForInfoDictionaryKey);
        NSLog(@"[AntiDetect] Swizzled objectForInfoDictionaryKey:");
    }
}

// 新的 bundleIdentifier 实现
NSString *new_bundleIdentifier(NSBundle *self, SEL _cmd) {
    NSString *orig = ((NSString *(*)(id, SEL))orig_bundleIdentifier)(self, _cmd);
    
    // 如果是主 bundle，返回正版 ID
    if (self == [NSBundle mainBundle]) {
        return @"com.juzi.balls";
    }
    
    return orig;
}

// 新的 objectForInfoDictionaryKey: 实现
id new_objectForInfoDictionaryKey(NSBundle *self, SEL _cmd, NSString *key) {
    id orig = ((id (*)(id, SEL, id))orig_objectForInfoDictionaryKey)(self, _cmd, key);
    
    // 如果是主 bundle，并且 key 是 CFBundleIdentifier
    if (self == [NSBundle mainBundle] && 
        [key isEqualToString:@"CFBundleIdentifier"]) {
        return @"com.juzi.balls";
    }
    
    return orig;
}

#pragma mark - 2. 隐藏越狱路径

+ (void)installJailbreakHide {
    Method orig = class_getInstanceMethod([NSFileManager class], @selector(fileExistsAtPath:));
    Method new = class_getInstanceMethod([NSFileManager class], @selector(ad_fileExistsAtPath:));
    if (orig && new) {
        method_exchangeImplementations(orig, new);
        NSLog(@"[AntiDetect] Swizzled fileExistsAtPath:");
    }
}

@end

@implementation NSFileManager (AntiDetect)

- (BOOL)ad_fileExistsAtPath:(NSString *)path {
    if (!path) return NO;
    
    // 隐藏常见越狱路径
    NSArray *jailPaths = @[
        @"/Applications/Cydia.app",
        @"/Applications/Sileo.app",
        @"/Applications/Zebra.app",
        @"/Library/MobileSubstrate",
        @"/usr/lib/substrate",
        @"/private/var/lib/apt",
        @"/bin/bash",
        @"/bin/sh",
        @"/usr/bin/ssh",
    ];
    
    for (NSString *jailPath in jailPaths) {
        if ([path containsString:jailPath]) {
            return NO;
        }
    }
    
    return [self ad_fileExistsAtPath:path];
}

@end
