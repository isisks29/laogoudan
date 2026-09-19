// AntiDetect.m — 完整反检测（参考 ballsace 方式）
// 1. 伪装 bundle ID
// 2. 隐藏越狱路径
// 3. 加密所有敏感字符串
// 4. inline hook _dyld_image_count 和 _dyld_get_image_name

#import "AntiDetect.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <mach/vm_map.h>
#import <mach/mach_init.h>
#import <string.h>

// ============================================================
// 字符串加密工具（参考 ballsace 的加密方式）
// ============================================================

static NSData *AEEncrypt(NSString *input) {
    NSData *data = [input dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *result = [NSMutableData dataWithLength:data.length];
    const uint8_t *bytes = data.bytes;
    uint8_t *out = result.mutableBytes;
    
    for (NSUInteger i = 0; i < data.length; i++) {
        out[i] = bytes[i] ^ (0xA7 + (i & 0xFF));
    }
    
    return result;
}

static NSString *AEDecrypt(NSData *data) {
    NSMutableData *result = [NSMutableData dataWithLength:data.length];
    const uint8_t *bytes = data.bytes;
    uint8_t *out = result.mutableBytes;
    
    for (NSUInteger i = 0; i < data.length; i++) {
        out[i] = bytes[i] ^ (0xA7 + (i & 0xFF));
    }
    
    return [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
}

// 加密的越狱路径数组
static NSArray *AEGetEncryptedJailbreakPaths(void) {
    static NSArray *paths = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        paths = @[
            AEEncrypt(@"/Applications/Cydia.app"),
            AEEncrypt(@"/Applications/Sileo.app"),
            AEEncrypt(@"/Applications/Zebra.app"),
            AEEncrypt(@"/Library/MobileSubstrate"),
            AEEncrypt(@"/usr/lib/substrate"),
            AEEncrypt(@"/private/var/lib/apt"),
            AEEncrypt(@"/bin/bash"),
            AEEncrypt(@"/bin/sh"),
            AEEncrypt(@"/usr/bin/ssh"),
            AEEncrypt(@"/etc/apt"),
            AEEncrypt(@"/usr/sbin/sshd"),
        ];
    });
    return paths;
}

// ============================================================
// Inline Hook 实现（参考 ballsace 的 vm_write 方式）
// ============================================================

typedef struct {
    void *original;
    void *replacement;
    uint8_t backup[32];
    BOOL installed;
} AEHook;

// Hook 列表
static NSMutableArray *g_hooks = nil;

// 修改内存保护
static BOOL AEMakeWritable(void *addr, size_t size) {
    mach_port_t port = mach_task_self();
    vm_address_t page = (vm_address_t)addr & ~0xFFF;
    vm_size_t pageSize = (size + ((vm_address_t)addr - page) + 0xFFF) & ~0xFFF;
    
    kern_return_t kr = vm_protect(port, page, pageSize, FALSE,
                                  VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
    return kr == KERN_SUCCESS;
}

// 安装 inline hook
static BOOL AEInstallHook(AEHook *hook, void *original, void *replacement) {
    if (hook->installed) return YES;
    
    hook->original = original;
    hook->replacement = replacement;
    
    // 备份原始指令
    memcpy(hook->backup, original, 16);
    
    // 修改内存为可写
    if (!AEMakeWritable(original, 16)) {
        NSLog(@"[AntiDetect] Failed to make memory writable");
        return NO;
    }
    
    // 写跳转到替换函数
    // ARM64: LDR X16, #8; BR X16; .quad replacement
    uint32_t *patch = (uint32_t *)original;
    patch[0] = 0x58000050; // LDR X16, #8
    patch[1] = 0xD61F0200; // BR X16
    *(void **)(patch + 2) = replacement;
    
    hook->installed = YES;
    return YES;
}

// ============================================================
// Hook _dyld_image_count 和 _dyld_get_image_name
// ============================================================

// 原始函数指针
static uint32_t (*orig_dyld_image_count)(void) = NULL;
static const char *(*orig_dyld_get_image_name)(uint32_t) = NULL;

// 我们的 dylib 名字（加密）
static NSString *g_ourDylibName = nil;

// 替换函数
static uint32_t hook_dyld_image_count(void) {
    uint32_t count = orig_dyld_image_count();
    
    // 如果我们的 dylib 在里面，就减 1
    for (uint32_t i = 0; i < count; i++) {
        const char *name = orig_dyld_get_image_name(i);
        if (name && g_ourDylibName && strstr(name, g_ourDylibName.UTF8String)) {
            return count - 1;
        }
    }
    
    return count;
}

static const char *hook_dyld_get_image_name(uint32_t index) {
    uint32_t count = orig_dyld_image_count();
    
    for (uint32_t i = 0; i < count; i++) {
        const char *name = orig_dyld_get_image_name(i);
        if (name && g_ourDylibName && strstr(name, g_ourDylibName.UTF8String)) {
            // 跳过我们的 dylib
            index++;
            continue;
        }
        if (i == index) {
            return name;
        }
    }
    
    return orig_dyld_get_image_name(index);
}

// ============================================================
// 主入口
// ============================================================

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
    
    // 1. 初始化
    g_hooks = [[NSMutableArray alloc] init];
    
    // 加密我们的 dylib 名字
    g_ourDylibName = AEEncrypt(@"GameTweak");
    
    // 2. 隐藏越狱路径
    [self installFileManagerSwizzle];
    
    // 3. 伪装 bundle ID
    [self installBundleIdFake];
    
    // 4. Install inline hooks
    [self installDyldHooks];
    
    NSLog(@"[AntiDetect] Installed!");
}

#pragma mark - 1. 隐藏越狱路径

+ (void)installFileManagerSwizzle {
    Method orig = class_getInstanceMethod([NSFileManager class], @selector(fileExistsAtPath:));
    Method new = class_getInstanceMethod([NSFileManager class], @selector(ad_fileExistsAtPath:));
    if (orig && new) {
        method_exchangeImplementations(orig, new);
        NSLog(@"[AntiDetect] FileManager swizzled");
    }
}

#pragma mark - 2. 伪装 bundle ID

+ (void)installBundleIdFake {
    Method orig = class_getInstanceMethod([NSBundle class], @selector(bundleIdentifier));
    Method new = class_getInstanceMethod([NSBundle class], @selector(ad_bundleIdentifier));
    if (orig && new) {
        method_exchangeImplementations(orig, new);
        NSLog(@"[AntiDetect] Bundle swizzled");
    }
}

#pragma mark - 3. Install inline hooks

+ (void)installDyldHooks {
    // 获取原始函数指针
    orig_dyld_image_count = &_dyld_image_count;
    orig_dyld_get_image_name = &_dyld_get_image_name;
    
    NSLog(@"[AntiDetect] Original dyld_image_count: %p", orig_dyld_image_count);
    NSLog(@"[AntiDetect] Original dyld_get_image_name: %p", orig_dyld_get_image_name);
    
    // Install hooks
    AEHook *hook1 = calloc(1, sizeof(AEHook));
    AEInstallHook(hook1, orig_dyld_image_count, (void *)hook_dyld_image_count);
    [g_hooks addObject:[NSValue valueWithPointer:hook1]];
    
    AEHook *hook2 = calloc(1, sizeof(AEHook));
    AEInstallHook(hook2, orig_dyld_get_image_name, (void *)hook_dyld_get_image_name);
    [g_hooks addObject:[NSValue valueWithPointer:hook2]];
    
    NSLog(@"[AntiDetect] Dyld hooks installed");
}

@end

@implementation NSFileManager (AntiDetect)

- (BOOL)ad_fileExistsAtPath:(NSString *)path {
    if (!path) return NO;
    
    // 检查所有加密的越狱路径
    NSArray *encryptedPaths = AEGetEncryptedJailbreakPaths();
    for (NSData *encData in encryptedPaths) {
        NSString *jailPath = AEDecrypt(encData);
        if ([path containsString:jailPath]) {
            return NO;
        }
    }
    
    return [self ad_fileExistsAtPath:path];
}

@end

@implementation NSBundle (AntiDetect)

- (NSString *)ad_bundleIdentifier {
    NSString *real = [self ad_bundleIdentifier];
    
    // 如果是我们的 dylib，伪装成游戏的
    if ([real containsString:AEDecrypt(AEEncrypt(@"GameTweak"))]) {
        return AEDecrypt(AEEncrypt(@"com.juzi.balls"));
    }
    
    return real;
}

@end
