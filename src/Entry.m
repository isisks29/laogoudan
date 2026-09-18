#include <dlfcn.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

__attribute__((constructor))
void dylib_initialize(void)
{
    NSLog(@"[GameTweak] dylib loaded!");
}
