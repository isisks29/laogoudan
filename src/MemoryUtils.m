// MemoryUtils.m — 内存搜索与写入实现
#import "MemoryUtils.h"
#import <mach/vm_map.h>
#import <mach/vm_statistics.h>
#import <sys/mman.h>

@implementation MemoryUtils

+ (mach_port_t)taskPort {
    static mach_port_t port = MACH_PORT_NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        port = mach_task_self();
    });
    return port;
}

// 枚举所有可读写的内存区域
+ (void)enumerateRegions:(void (^)(uintptr_t start, size_t size, BOOL *stop))block {
    mach_port_t task = [self taskPort];
    vm_address_t address = 0;
    vm_size_t size = 0;
    natural_t depth = 0;
    struct vm_region_submap_info_64 info;
    mach_msg_type_number_t count = VM_REGION_SUBMAP_INFO_COUNT_64;

    while (YES) {
        count = VM_REGION_SUBMAP_INFO_COUNT_64;
        kern_return_t kr = vm_region_recurse_64(task, &address, &size, &depth,
                                                   (vm_region_recurse_info_t)&info, &count);
        if (kr != KERN_SUCCESS) break;

        if (depth == 0) {
            if (info.protection & VM_PROT_WRITE) {
                BOOL stop = NO;
                block(address, size, &stop);
                if (stop) break;
            }
            address += size;
        }
    }
}

+ (NSArray<NSNumber *> *)searchFloat:(float)target {
    return [self searchFloat:target tolerance:0.0f];
}

+ (NSArray<NSNumber *> *)searchFloat:(float)target tolerance:(float)tolerance {
    NSMutableArray *results = [NSMutableArray array];

    [self enumerateRegions:^(uintptr_t start, size_t size, BOOL *stop) {
        vm_offset_t data = 0;
        mach_msg_type_number_t dataSize = 0;
        kern_return_t kr = vm_read([self taskPort], start, (vm_size_t)size, &data, &dataSize);
        if (kr != KERN_SUCCESS) return;

        float *ptr = (float *)data;
        size_t count = dataSize / sizeof(float);
        for (size_t i = 0; i < count; i++) {
            if (tolerance > 0) {
                if (fabsf(ptr[i] - target) <= tolerance) {
                    [results addObject:@(start + i * sizeof(float))];
                }
            } else {
                if (ptr[i] == target) {
                    [results addObject:@(start + i * sizeof(float))];
                }
            }
        }
        vm_deallocate([self taskPort], data, dataSize);
    }];

    return results;
}

+ (NSArray<NSNumber *> *)searchInt:(int32_t)target {
    NSMutableArray *results = [NSMutableArray array];

    [self enumerateRegions:^(uintptr_t start, size_t size, BOOL *stop) {
        vm_offset_t data = 0;
        mach_msg_type_number_t dataSize = 0;
        kern_return_t kr = vm_read([self taskPort], start, (vm_size_t)size, &data, &dataSize);
        if (kr != KERN_SUCCESS) return;

        int32_t *ptr = (int32_t *)data;
        size_t count = dataSize / sizeof(int32_t);
        for (size_t i = 0; i < count; i++) {
            if (ptr[i] == target) {
                [results addObject:@(start + i * sizeof(int32_t))];
            }
        }
        vm_deallocate([self taskPort], data, dataSize);
    }];

    return results;
}

+ (BOOL)writeFloat:(float)value at:(uintptr_t)addr {
    return [self writeData:[NSData dataWithBytes:&value length:sizeof(float)] at:addr];
}

+ (BOOL)writeInt:(int32_t)value at:(uintptr_t)addr {
    return [self writeData:[NSData dataWithBytes:&value length:sizeof(int32_t)] at:addr];
}

+ (BOOL)writeData:(NSData *)data at:(uintptr_t)addr {
    kern_return_t kr = vm_write([self taskPort], addr,
                                  (vm_offset_t)data.bytes, (mach_msg_type_number_t)data.length);
    return kr == KERN_SUCCESS;
}

+ (float)readFloatAt:(uintptr_t)addr {
    float value = 0;
    vm_offset_t data = 0;
    mach_msg_type_number_t dataSize = 0;
    kern_return_t kr = vm_read([self taskPort], addr, sizeof(float), &data, &dataSize);
    if (kr == KERN_SUCCESS) {
        memcpy(&value, (void *)data, sizeof(float));
        vm_deallocate([self taskPort], data, dataSize);
    }
    return value;
}

@end
