// AntiDetect.m — 完善反检测（参考 ballsace，不用 fishhook）
#import "AntiDetect.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
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
    // 延迟 2 秒再安装，确保 UIKit 完全初始化
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC), 
                   dispatch_get_main_queue(), ^{
        [AntiDetect installAll];
    });
}

+ (void)installAll {
    [self installFileHide];
    [self installBundleHide];
    [self installAppHide];
    [self installRecordingBypass];
}

+ (BOOL)isScreenCaptured { return g_isScreenCaptured; }
+ (void)setRecordingBypass:(BOOL)enabled { g_recordingBypass = enabled; }

#pragma mark - 1. 文件检测绕过

+ (void)installFileHide {
    // hook fileExistsAtPath:
    Method m1 = class_getInstanceMethod([NSFileManager class], @selector(fileExistsAtPath:));
    IMP imp1 = imp_implementationWithBlock(^BOOL(id self, SEL _cmd, NSString *path) {
        if ([path containsString:@"Cydia"] ||
            [path containsString:@"Sileo"] ||
            [path containsString:@"Zebra"] ||
            [path containsString:@"MobileSubstrate"] ||
            [path containsString:@"Substrate"] ||
            [path containsString:@"GameTweak"] ||
            [path containsString:@"Tweak.dylib"]) {
            return NO;
        }
        return ((BOOL (*)(id, SEL, NSString *))method_getImplementation(m1))(self, _cmd, path);
    });
    method_setImplementation(m1, imp1);
    
    // hook contentsOfDirectoryAtPath:error:
    Method m2 = class_getInstanceMethod([NSFileManager class], @selector(contentsOfDirectoryAtPath:error:));
    IMP imp2 = imp_implementationWithBlock(^NSArray *(id self, SEL _cmd, NSString *path, NSError **error) {
        NSArray *result = ((NSArray *(*)(id, SEL, NSString *, NSError **))method_getImplementation(m2))(self, _cmd, path, error);
        NSMutableArray *filtered = [NSMutableArray array];
        for (NSString *item in result) {
            if (![item containsString:@"Cydia"] &&
                ![item containsString:@"Sileo"] &&
                ![item containsString:@"Substrate"] &&
                ![item containsString:@"GameTweak"]) {
                [filtered addObject:item];
            }
        }
        return filtered;
    });
    method_setImplementation(m2, imp2);
}

#pragma mark - 2. Bundle 检测绕过

+ (void)installBundleHide {
    // hook bundleIdentifier
    Method m1 = class_getInstanceMethod([NSBundle class], @selector(bundleIdentifier));
    IMP imp1 = imp_implementationWithBlock(^NSString *(id self, SEL _cmd) {
        NSString *result = ((NSString *(*)(id, SEL))method_getImplementation(m1))(self, _cmd);
        if ([result containsString:@"GameTweak"] ||
            [result containsString:@"Tweak"]) {
            return @"com.juzi.balls";
        }
        return result;
    });
    method_setImplementation(m1, imp1);
    
    // hook infoDictionary
    Method m2 = class_getInstanceMethod([NSBundle class], @selector(infoDictionary));
    IMP imp2 = imp_implementationWithBlock(^NSDictionary *(id self, SEL _cmd) {
        NSDictionary *result = ((NSDictionary *(*)(id, SEL))method_getImplementation(m2))(self, _cmd);
        return result;
    });
    method_setImplementation(m2, imp2);
}

#pragma mark - 3. 应用检测绕过

+ (void)installAppHide {
    // hook sharedApplication
    Method m1 = class_getClassMethod([UIApplication class], @selector(sharedApplication));
    // 注意：class method 需要用 class_getClassMethod
    
    // hook applicationState
    Method m2 = class_getInstanceMethod([UIApplication class], @selector(applicationState));
    IMP imp2 = imp_implementationWithBlock(^UIApplicationState(id self, SEL _cmd) {
        return UIApplicationStateActive;
    });
    method_setImplementation(m2, imp2);
}

#pragma mark - 4. 录屏状态监听

+ (void)installRecordingBypass {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIScreenCapturedDidChangeNotification
                                                        object:nil
                                                         queue:[NSOperationQueue mainQueue]
                                                    usingBlock:^(NSNotification *note) {
        g_isScreenCaptured = [UIScreen mainScreen].isCaptured;
    }];
}

@end
