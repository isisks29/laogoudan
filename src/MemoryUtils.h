// MemoryUtils.h — 内存搜索与写入工具
#ifndef MEMORY_UTILS_H
#define MEMORY_UTILS_H
#import <Foundation/Foundation.h>
#import <mach/mach.h>

@interface MemoryUtils : NSObject
// 搜索内存中值为 target 的 float 地址（带容差，限制结果数量，避免卡顿）
+ (NSArray<NSNumber *> *)searchFloat:(float)target tolerance:(float)tolerance maxResults:(NSUInteger)max;
// 向指定地址写入 float
+ (BOOL)writeFloat:(float)value at:(uintptr_t)addr;
// 从指定地址读取 float
+ (float)readFloatAt:(uintptr_t)addr;
// 获取进程任务端口
+ (mach_port_t)taskPort;
// 搜索内存中值为 target 的 float 地址（限制最大结果数，避免卡顿）
+ (NSArray<NSNumber *> *)searchFloat:(float)target maxResults:(NSUInteger)max;
+ (NSArray<NSNumber *> *)searchInt:(int32_t)target;
+ (BOOL)writeInt:(int32_t)value at:(uintptr_t)addr;

// 搜索内存中值为 target 的 float 地址（带容差）
+ (NSArray<NSNumber *> *)searchFloat:(float)target tolerance:(float)tolerance maxResults:(NSUInteger)max;
@end
#endif // MEMORY_UTILS_H
