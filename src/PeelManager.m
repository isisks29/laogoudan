#import "PeelManager.h"
#import <objc/runtime.h>

@interface PeelManager ()
@property (assign) BOOL peeling;
@end

@implementation PeelManager

+ (instancetype)shared {
    static PeelManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[PeelManager alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) { _peeling = NO; }
    return self;
}

- (void)startPeel {
    if (self.peeling) return;
    self.peeling = YES;
    [self swizzleNSData];
}

- (void)stopPeel {
    self.peeling = NO;
    // 不做 unswizzle（保持简单），peeling=NO 后 hook 方法直接放行
}

#pragma mark - 判断是否为皮肤资源
+ (BOOL)isSkinResourceURL:(NSURL *)url {
    if (!url) return NO;
    NSString *urlStr = url.absoluteString ?: @"";
    NSString *path = url.path ?: @"";
    return [self isSkinResourceString:urlStr] || [self isSkinResourceString:path];
}

+ (BOOL)isSkinResourcePath:(NSString *)path {
    if (!path) return NO;
    return [self isSkinResourceString:path];
}

+ (BOOL)isSkinResourceString:(NSString *)s {
    if (!s || s.length == 0) return NO;
    NSString *lower = s.lowercaseString;
    // 皮肤配置 ID（JuziHub 中的 keyskin_xxxx）
    if ([lower containsString:@"keyskin_"]) return YES;
    // 球材质资源
    if ([lower containsString:@"/ballmaterial/"]) return YES;
    if ([lower containsString:@"alltextures/ballmaterial"]) return YES;
    // 孢子/刺球特效（ciqiu = 刺球，球球大作战的孢子特效）
    if ([lower containsString:@"ingameeffect"] && [lower containsString:@"ciqiu"]) return YES;
    // 皮肤配置文件
    if ([lower containsString:@"skin"] && ([lower containsString:@".plist"] ||
        [lower containsString:@".json"] || [lower containsString:@".dat"] ||
        [lower containsString:@".bytes"])) return YES;
    // 关键词/孢子配置
    if (([lower containsString:@"keyword"] || [lower containsString:@"spore"]) &&
        ([lower containsString:@".plist"] || [lower containsString:@".json"] ||
         [lower containsString:@".dat"] || [lower containsString:@".bytes"])) return YES;
    return NO;
}

#pragma mark - method swizzle
- (void)swizzleNSData {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = [NSData class];

        // +dataWithContentsOfURL:
        Method orig1 = class_getClassMethod(cls, @selector(dataWithContentsOfURL:));
        Method new1 = class_getClassMethod(cls, @selector(peel_dataWithContentsOfURL:));
        if (orig1 && new1) method_exchangeImplementations(orig1, new1);

        // +dataWithContentsOfURL:options:error:
        Method orig2 = class_getClassMethod(cls, @selector(dataWithContentsOfURL:options:error:));
        Method new2 = class_getClassMethod(cls, @selector(peel_dataWithContentsOfURL:options:error:));
        if (orig2 && new2) method_exchangeImplementations(orig2, new2);

        // +dataWithContentsOfFile:
        Method orig3 = class_getClassMethod(cls, @selector(dataWithContentsOfFile:));
        Method new3 = class_getClassMethod(cls, @selector(peel_dataWithContentsOfFile:));
        if (orig3 && new3) method_exchangeImplementations(orig3, new3);

        // +dataWithContentsOfFile:options:error:
        Method orig4 = class_getClassMethod(cls, @selector(dataWithContentsOfFile:options:error:));
        Method new4 = class_getClassMethod(cls, @selector(peel_dataWithContentsOfFile:options:error:));
        if (orig4 && new4) method_exchangeImplementations(orig4, new4);
    });
}

#pragma mark - Hook 方法
+ (NSData *)peel_dataWithContentsOfURL:(NSURL *)url {
    if ([PeelManager shared].peeling && [PeelManager isSkinResourceURL:url]) {
        return nil;  // 拦截皮肤资源，游戏加载失败回退默认皮肤
    }
    return [self peel_dataWithContentsOfURL:url];  // 已交换，调用原始实现
}

+ (NSData *)peel_dataWithContentsOfURL:(NSURL *)url options:(NSDataReadingOptions)mask error:(NSError **)error {
    if ([PeelManager shared].peeling && [PeelManager isSkinResourceURL:url]) {
        if (error) *error = [NSError errorWithDomain:@"PeelManager" code:-1 userInfo:@{NSLocalizedDescriptionKey:@"skin resource blocked"}];
        return nil;
    }
    return [self peel_dataWithContentsOfURL:url options:mask error:error];
}

+ (NSData *)peel_dataWithContentsOfFile:(NSString *)path {
    if ([PeelManager shared].peeling && [PeelManager isSkinResourcePath:path]) {
        return nil;
    }
    return [self peel_dataWithContentsOfFile:path];
}

+ (NSData *)peel_dataWithContentsOfFile:(NSString *)path options:(NSDataReadingOptions)mask error:(NSError **)error {
    if ([PeelManager shared].peeling && [PeelManager isSkinResourcePath:path]) {
        if (error) *error = [NSError errorWithDomain:@"PeelManager" code:-1 userInfo:@{NSLocalizedDescriptionKey:@"skin resource blocked"}];
        return nil;
    }
    return [self peel_dataWithContentsOfFile:path options:mask error:error];
}

@end
