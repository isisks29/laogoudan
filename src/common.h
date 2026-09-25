#ifndef COMMON_H
#define COMMON_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>
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

// 日志宏
#ifdef DEBUG
#define LOG(fmt, ...) NSLog(@"[BallsBypass] " fmt, ##__VA_ARGS__)
#else
#define LOG(fmt, ...)
#endif

// 常用常量
#define PAGE_SIZE_ARM64 0x4000
#define MAX_PATH_LEN 1024

// 类型兼容（纯C环境）
#ifndef BOOL
typedef int BOOL;
#endif
#ifndef TRUE
#define TRUE 1
#endif
#ifndef FALSE
#define FALSE 0
#endif

// mach_page_size_t 兼容
#ifndef mach_page_size_t
#define mach_page_size_t size_t
#endif

#endif // COMMON_H
