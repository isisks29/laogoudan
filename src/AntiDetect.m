// AntiDetect.m — 反检测实现（五层合一）
#import "AntiDetect.h"
#import "fishhook/fishhook.h"
#import <sys/sysctl.h>
#import <unistd.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>

#ifndef PT_DENY_ATTACH
#define PT_DENY_ATTACH 31
#endif

// ===== 原始函数指针 =====
static int (*orig_ptrace)(int, pid_t, caddr_t, int);
static int (*orig_sysctl)(int *, u_int, void *, size_t *, void *, size_t);
static const char *(*orig_dyld_get_image_name)(uint32_t);
static FILE *(*orig_fopen)(const char *, const char *);
static int (*orig_access)(const char *, int);
static int (*orig_stat)(const char *, void *);

// ===== dyld 隐藏状态 =====
static char *g_own_path = NULL;
static char *g_fake_path = NULL;

#pragma mark - 第一层：ptrace Hook

static int hook_ptrace(int request, pid_t pid, caddr_t addr, int data) {
    if (request == PT_DENY_ATTACH) {
        return 0;  // 游戏试图阻止调试器，我们让它"成功"但不实际执行
    }
    return orig_ptrace ? orig_ptrace(request, pid, addr, data) : -1;
}

+ (void)installPtraceHook {
    struct rebinding r = {"ptrace", (void *)hook_ptrace, (void **)&orig_ptrace};
    rebind_symbols(&r, 1);
}

#pragma mark - 第二层：sysctl Hook（清除 P_TRACED）

static int hook_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    int ret = orig_sysctl ? orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen) : -1;
    if (namelen >= 3 && name[0] == CTL_KERN && name[1] == KERN_PROC &&
        name[2] == KERN_PROC_PID && oldp && oldlenp && *oldlenp >= sizeof(struct kinfo_proc)) {
        struct kinfo_proc *info = (struct kinfo_proc *)oldp;
        info->kp_proc.p_flag &= ~P_TRACED;  // 清除调试标志
    }
    return ret;
}

+ (void)installSysctlHook {
    struct rebinding r = {"sysctl", (void *)hook_sysctl, (void **)&orig_sysctl};
    rebind_symbols(&r, 1);
}

#pragma mark - 第三层：dyld 镜像隐藏

static const char *hook_dyld_get_image_name(uint32_t idx) {
    const char *name = orig_dyld_get_image_name(idx);
    if (name && g_own_path && strcmp(name, g_own_path) == 0) {
        return g_fake_path ?: "/usr/lib/libSystem.B.dylib";
    }
    return name;
}

static void detect_own_path(void) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && (strstr(name, "GameTweak") || strstr(name, "MyTweak") || strstr(name, "AntiDetect"))) {
            g_own_path = strdup(name);
            break;
        }
    }
    if (!g_own_path && count > 0) {
        const char *last = _dyld_get_image_name(count - 1);
        if (last) g_own_path = strdup(last);
    }
    // 找一个系统库路径作为假路径
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && (strstr(name, "libSystem") || strstr(name, "libobjc"))) {
            if (!g_own_path || strcmp(name, g_own_path) != 0) {
                g_fake_path = strdup(name);
                break;
            }
        }
    }
    if (!g_fake_path) g_fake_path = strdup("/usr/lib/libSystem.B.dylib");
}

+ (void)installDyldHide {
    detect_own_path();
    struct rebinding r = {"_dyld_get_image_name", (void *)hook_dyld_get_image_name, (void **)&orig_dyld_get_image_name};
    rebind_symbols(&r, 1);
}

#pragma mark - 第四层：越狱检测反制

static bool is_jb_path(const char *path) {
    if (!path) return false;
    const char *paths[] = {
        "/Applications/Cydia.app", "/Library/MobileSubstrate",
        "/bin/bash", "/usr/sbin/sshd", "/etc/apt",
        "/usr/bin/ssh", "/private/var/stash", NULL
    };
    for (int i = 0; paths[i]; i++) {
        if (strstr(path, paths[i])) return true;
    }
    return false;
}

static FILE *hook_fopen(const char *path, const char *mode) {
    if (is_jb_path(path)) { errno = ENOENT; return NULL; }
    return orig_fopen ? orig_fopen(path, mode) : NULL;
}

static int hook_access(const char *path, int mode) {
    if (is_jb_path(path)) { errno = ENOENT; return -1; }
    return orig_access ? orig_access(path, mode) : -1;
}

static int hook_stat(const char *path, void *buf) {
    if (is_jb_path(path)) { errno = ENOENT; return -1; }
    return orig_stat ? orig_stat(path, buf) : -1;
}

+ (void)installJailbreakHide {
    // Method Swizzling NSFileManager
    Method orig1 = class_getInstanceMethod([NSFileManager class], @selector(fileExistsAtPath:));
    Method new1 = class_getInstanceMethod([NSFileManager class], @selector(ad_fileExistsAtPath:));
    if (orig1 && new1) method_exchangeImplementations(orig1, new1);
    
    // fishhook C 函数
    struct rebinding rs[] = {
        {"fopen", (void *)hook_fopen, (void **)&orig_fopen},
        {"access", (void *)hook_access, (void **)&orig_access},
        {"stat", (void *)hook_stat, (void **)&orig_stat},
    };
    rebind_symbols(rs, 3);
}

@end

// NSFileManager 分类
@implementation NSFileManager (AntiDetect)
- (BOOL)ad_fileExistsAtPath:(NSString *)path {
    NSArray *jb = @[@"/Applications/Cydia.app", @"/Library/MobileSubstrate", @"/bin/bash", @"/etc/apt"];
    for (NSString *p in jb) {
        if ([path containsString:p]) return NO;
    }
    return [self ad_fileExistsAtPath:path];
}
@end

#pragma mark - 第五层：注入器环境感知

@implementation AntiDetect (Injector)

+ (void)runInjectorScan {
    const char *sigs[] = {"frida", "cycript", "substrate", "substitute", "libhooker", "debugserver", NULL};
    uint32_t count = _dyld_image_count();
    bool found = false;
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;
        char lower[512];
        size_t len = strlen(name);
        if (len >= sizeof(lower)) len = sizeof(lower) - 1;
        for (size_t j = 0; j < len; j++) lower[j] = (name[j] >= 'A' && name[j] <= 'Z') ? name[j] + 32 : name[j];
        lower[len] = 0;
        for (int k = 0; sigs[k]; k++) {
            if (strstr(lower, sigs[k])) { found = true; break; }
        }
        if (found) break;
    }
    if (found) {
        // 检测到注入器，执行更严格的隐藏（这里可以加额外逻辑）
        [self denyDebug];
    }
}

+ (void)denyDebug {
    ptrace(PT_DENY_ATTACH, 0, 0, 0);
}

+ (void)installAll {
    [self installPtraceHook];
    [self installSysctlHook];
    [self installDyldHide];
    [self installJailbreakHide];
    [self runInjectorScan];
    [self denyDebug];
}

@end
