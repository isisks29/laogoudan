// MemoryUtils.h — 内存搜索与写入工具
// 实现 A 类功能（内存搜改型）的基础设施
#ifndef MEMORY_UTILS_H
#define MEMORY_UTILS_H

#import <Foundation/Foundation.h>
#import <mach/mach.h>

@interface MemoryUtils : NSObject

// 搜索内存中值为 target 的 float 地址
+ (NSArray<NSNumber *> *)searchFloat:(float)target;

// 搜索内存中值为 target 的 int 地址
+ (NSArray<NSNumber *> *)searchInt:(int32_t)target;

// 同时搜索 float 和 int（并行搜索，提高定位精度）
+ (NSArray<NSNumber *> *)searchFloat:(float)fval andInt:(int32_t)ival;

// 在指定地址附近搜索（缩小范围）
+ (NSArray<NSNumber *> *)searchNear:(uintptr_t)base radius:(size_t)radius value:(float)target;

// 向指定地址写入 float
+ (BOOL)writeFloat:(float)value at:(uintptr_t)addr;

// 向指定地址写入 int
+ (BOOL)writeInt:(int32_t)value at:(uintptr_t)addr;

// 从指定地址读取 float
+ (float)readFloatAt:(uintptr_t)addr;

// 从指定地址读取 int
+ (int32_t)readIntAt:(uintptr_t)addr;

// 获取进程任务端口
+ (mach_port_t)taskPort;

@end

#endif // MEMORY_UTILS_H
