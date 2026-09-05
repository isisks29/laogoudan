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
            // 只处理可写的、非系统的内存区域
            if ((info.protection & VM_PROT_WRITE) && 
                !(info.protection)) {
                BOOL stop = NO;
                block(address, size, &stop);
                if (stop) break;
            }
            address += size;
        }
    }
}

+ (NSArray<NSNumber *> *)searchFloat:(float)target {
    NSMutableArray *results = [NSMutableArray array];
    uint32_t targetBits;
    memcpy(&targetBits, &target, sizeof(float));
    
    [self enumerateRegions:^(uintptr_t start, size_t size, BOOL *stop) {
        vm_offset_t data = 0;
        mach_msg_type_number_t dataSize = 0;
        kern_return_t kr = vm_read([self taskPort], start, (vm_size_t)size, &data, &dataSize);
        if (kr != KERN_SUCCESS) return;
        
        uint32_t *ptr = (uint32_t *)data;
        size_t count = dataSize / sizeof(uint32_t);
        for (size_t i = 0; i < count; i++) {
            if (ptr[i] == targetBits) {
                [results addObject:@(start + i * sizeof(uint32_t))];
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

+ (NSArray<NSNumber *> *)searchFloat:(float)fval andInt:(int32_t)ival {
    // 先搜 float，再在 float 结果附近搜 int，取交集
    NSArray *floatResults = [self searchFloat:fval];
    if (floatResults.count == 0) return @[];
    
    NSMutableArray *final = [NSMutableArray array];
    NSSet *floatSet = [NSSet setWithArray:floatResults];
    
    // 搜索 int，然后看附近有没有 float 结果
    [self enumerateRegions:^(uintptr_t start, size_t size, BOOL *stop) {
        vm_offset_t data = 0;
        mach_msg_type_number_t dataSize = 0;
        kern_return_t kr = vm_read([self taskPort], start, (vm_size_t)size, &data, &dataSize);
        if (kr != KERN_SUCCESS) return;
        
        int32_t *ptr = (int32_t *)data;
        size_t count = dataSize / sizeof(int32_t);
        for (size_t i = 0; i < count; i++) {
            if (ptr[i] == ival) {
                uintptr_t intAddr = start + i * sizeof(int32_t);
                // 检查附近（前后 256 字节内）是否有 float 结果
                for (NSNumber *fAddr in floatSet) {
                    uintptr_t fa = fAddr.unsignedLongLongValue;
                    if (fa > intAddr - 256 && fa < intAddr + 256) {
                        [final addObject:@(fa)];
                        break;
                    }
                }
            }
        }
        vm_deallocate([self taskPort], data, dataSize);
    }];
    
    return final;
}

+ (NSArray<NSNumber *> *)searchNear:(uintptr_t)base radius:(size_t)radius value:(float)target {
    NSMutableArray *results = [NSMutableArray array];
    uint32_t targetBits;
    memcpy(&targetBits, &target, sizeof(float));
    
    uintptr_t start = base - radius;
    size_t size = radius * 2;
    
    vm_offset_t data = 0;
    mach_msg_type_number_t dataSize = 0;
    kern_return_t kr = vm_read([self taskPort], start, (vm_size_t)size, &data, &dataSize);
    if (kr != KERN_SUCCESS) return @[];
    
    uint32_t *ptr = (uint32_t *)data;
    size_t count = dataSize / sizeof(uint32_t);
    for (size_t i = 0; i < count; i++) {
        if (ptr[i] == targetBits) {
            [results addObject:@(start + i * sizeof(uint32_t))];
        }
    }
    vm_deallocate([self taskPort], data, dataSize);
    
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

+ (int32_t)readIntAt:(uintptr_t)addr {
    int32_t value = 0;
    vm_offset_t data = 0;
    mach_msg_type_number_t dataSize = 0;
    kern_return_t kr = vm_read([self taskPort], addr, sizeof(int32_t), &data, &dataSize);
    if (kr == KERN_SUCCESS) {
        memcpy(&value, (void *)data, sizeof(int32_t));
        vm_deallocate([self taskPort], data, dataSize);
    }
    return value;
}

@end
