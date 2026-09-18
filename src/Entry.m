#include <dlfcn.h>
#import <Foundation/Foundation.h>
#import "Config.h"

__attribute__((constructor))
void dylib_initialize(void)
{
    @autoreleasepool {
        NSLog(@"[GT] dylib constructor enter");
        [[GlobalConfig shared] load];
        NSLog(@"[GT] GlobalConfig load done");
    }
}
