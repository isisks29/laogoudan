// AntiDetect.m — 反检测（安全版：仅 NSFileManager 越狱路径隐藏）
#import "AntiDetect.h"
#import <Foundation/Foundation.h>
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
    [self installJailbreakHide];
}

+ (void)installJailbreakHide {
    Method orig1 = class_getInstanceMethod([NSFileManager class], @selector(fileExistsAtPath:));
    Method new1 = class_getInstanceMethod([NSFileManager class], @selector(ad_fileExistsAtPath:));
    if (orig1 && new1) method_exchangeImplementations(orig1, new1);
}

@end

@implementation NSFileManager (AntiDetect)
- (BOOL)ad_fileExistsAtPath:(NSString *)path {
    if (!path) return NO;
    NSArray *jb = @[@"/Applications/Cydia.app", @"/Library/MobileSubstrate", @"/bin/bash", @"/etc/apt"];
    for (NSString *p in jb) {
        if ([path containsString:p]) return NO;
    }
    return [self ad_fileExistsAtPath:path];
}
@end
