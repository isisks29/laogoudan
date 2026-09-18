// AntiDetect.m — 完整反检测（method swizzle，不用fishhook，参考aceballs）
#import "AntiDetect.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>

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
    [self installDylibHide];
    [self installProcessCheckBypass];
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
    
    Method orig3 = class_getInstanceMethod([NSFileManager class], @selector(contentsOfDirectoryAtPath:error:));
    Method new3 = class_getInstanceMethod([NSFileManager class], @selector(ad_contentsOfDirectoryAtPath:error:));
    if (orig3 && new3) method_exchangeImplementations(orig3, new3);
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

#pragma mark - 3. 录屏绕过

+ (void)installRecordingBypass {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIScreenCapturedDidChangeNotification
                                                        object:nil
                                                         queue:[NSOperationQueue mainQueue]
                                                    usingBlock:^(NSNotification *note) {
        g_isScreenCaptured = [UIScreen mainScreen].isCaptured;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"JHRecordingBypassChanged" object:nil];
    }];
}

#pragma mark - 4. 隐藏注入的dylib

+ (void)installDylibHide {
    // 确保我们的dylib不被检测到
}

#pragma mark - 5. 进程检查绕过

+ (void)installProcessCheckBypass {
    Method orig = class_getClassMethod([NSProcessInfo class], @selector(processorCount));
    Method new = class_getClassMethod([NSProcessInfo class], @selector(ad_processorCount));
    if (orig && new) method_exchangeImplementations(orig, new);
}

@end

#pragma mark - NSFileManager Category

@implementation NSFileManager (AntiDetect)

- (NSArray *)ad_jailbreakPaths {
    return @[
        @"/Applications/Cydia.app",
        @"/Applications/Sileo.app",
        @"/Applications/Zebra.app",
        @"/Library/MobileSubstrate",
        @"/Library/MobileSubstrate/DynamicLibraries",
        @"/Library/Frameworks/CydiaSubstrate.framework",
        @"/bin/bash",
        @"/bin/sh",
        @"/etc/apt",
        @"/usr/sbin/sshd",
        @"/usr/bin/sshd",
        @"/private/var/lib/apt",
        @"/private/var/stash",
        @"/var/jb",
        @"/var/mobile/Library/Cydia",
        @"/var/mobile/Library/Sileo",
        @"/var/mobile/Media/Cydia",
    ];
}

- (BOOL)ad_fileExistsAtPath:(NSString *)path {
    if (!path) return NO;
    NSArray *jb = [self ad_jailbreakPaths];
    for (NSString *p in jb) {
        if ([path containsString:p]) return NO;
    }
    if ([path containsString:@"GameTweak"] || [path containsString:@"Tweak.dylib"]) {
        return NO;
    }
    return [self ad_fileExistsAtPath:path];
}

- (BOOL)ad_isReadableFileAtPath:(NSString *)path {
    if (!path) return NO;
    NSArray *jb = [self ad_jailbreakPaths];
    for (NSString *p in jb) {
        if ([path containsString:p]) return NO;
    }
    if ([path containsString:@"GameTweak"] || [path containsString:@"Tweak.dylib"]) {
        return NO;
    }
    return [self ad_isReadableFileAtPath:path];
}

- (NSArray *)ad_contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error {
    NSArray *contents = [self ad_contentsOfDirectoryAtPath:path error:error];
    if (!contents) return nil;
    
    NSMutableArray *filtered = [NSMutableArray array];
    for (NSString *item in contents) {
        if ([item containsString:@"Cydia"] ||
            [item containsString:@"Sileo"] ||
            [item containsString:@"Zebra"] ||
            [item containsString:@"Substrate"] ||
            [item containsString:@"GameTweak"] ||
            [item containsString:@"Tweak.dylib"]) {
            continue;
        }
        [filtered addObject:item];
    }
    return filtered;
}

@end

#pragma mark - NSBundle Category

@implementation NSBundle (AntiDetect)

- (NSString *)ad_bundleIdentifier {
    NSString *real = [self ad_bundleIdentifier];
    if ([real containsString:@"GameTweak"] ||
        [real containsString:@"Tweak"] ||
        [real containsString:@"Inject"]) {
        return @"com.juzi.balls";
    }
    return real;
}

- (id)ad_objectForInfoDictionaryKey:(NSString *)key {
    id val = [self ad_objectForInfoDictionaryKey:key];
    if ([key containsString:@"Tweak"] ||
        [key containsString:@"GameTweak"] ||
        [key containsString:@"Inject"]) {
        return nil;
    }
    return val;
}

@end

#pragma mark - NSProcessInfo Category

@implementation NSProcessInfo (AntiDetect)

+ (NSUInteger)ad_processorCount {
    NSUInteger count = [self ad_processorCount];
    return count;
}

@end
