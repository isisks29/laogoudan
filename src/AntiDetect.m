// AntiDetect.m — 完善反检测（严格按照 ballsace 方式）
#import "AntiDetect.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

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
    
    // 1. 伪装 bundle ID（最核心！）
    [self spoofBundleId];
    
    // 2. 隐藏越狱路径
    [self hideJailbreakPaths];
    
    NSLog(@"[AntiDetect] Install complete!");
}

#pragma mark - 1. Bundle ID 伪装（最核心！）

+ (void)spoofBundleId {
    // Swizzle NSBundle.bundleIdentifier
    Method origMethod = class_getInstanceMethod([NSBundle class], @selector(bundleIdentifier));
    IMP origImp = method_getImplementation(origMethod);
    
    IMP newImp = imp_implementationWithBlock(^NSString *(NSBundle *self) {
        NSString *orig = ((NSString *(*)(id, SEL))origImp)(self, @selector(bundleIdentifier));
        
        // 如果是主 bundle，返回正版 ID
        if (self == [NSBundle mainBundle]) {
            return @"com.juzi.balls";
        }
        return orig;
    });
    
    method_setImplementation(origMethod, newImp);
    
    // Swizzle NSBundle.objectForInfoDictionaryKey:
    Method origMethod2 = class_getInstanceMethod([NSBundle class], @selector(objectForInfoDictionaryKey:));
    IMP origImp2 = method_getImplementation(origMethod2);
    
    IMP newImp2 = imp_implementationWithBlock(^id(NSBundle *self, NSString *key) {
        id orig = ((id (*)(id, SEL, id))origImp2)(self, @selector(objectForInfoDictionaryKey:), key);
        
        // 如果是主 bundle，并且 key 是 CFBundleIdentifier
        if (self == [NSBundle mainBundle] && [key isEqualToString:@"CFBundleIdentifier"]) {
            return @"com.juzi.balls";
        }
        return orig;
    });
    
    method_setImplementation(origMethod2, newImp2);
    
    NSLog(@"[AntiDetect] Bundle ID spoofed!");
}

#pragma mark - 2. 隐藏越狱路径

+ (void)hideJailbreakPaths {
    Method origMethod = class_getInstanceMethod([NSFileManager class], @selector(fileExistsAtPath:));
    IMP origImp = method_getImplementation(origMethod);
    
    IMP newImp = imp_implementationWithBlock(^BOOL(NSFileManager *self, NSString *path) {
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
            @"/private/var/mobile/Library/SBSettings",
            @"/private/var/stash",
            @"/private/var/tmp/cydia.log",
            @"/private/var/tmp/cydia",
        ];
        
        for (NSString *jailPath in jailPaths) {
            if ([path hasPrefix:jailPath] || [path containsString:jailPath]) {
                return NO;
            }
        }
        
        return ((BOOL (*)(id, SEL, id))origImp)(self, @selector(fileExistsAtPath:), path);
    });
    
    method_setImplementation(origMethod, newImp);
    
    NSLog(@"[AntiDetect] Jailbreak paths hidden!");
}

@end
