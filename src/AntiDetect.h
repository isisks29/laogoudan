#import <Foundation/Foundation.h>

#ifndef ANTI_DETECT_H
#define ANTI_DETECT_H

@interface AntiDetect : NSObject
+ (instancetype)sharedInstance;
- (void)startProtect;

+ (void)installAll;
+ (void)installPtraceHook;
+ (void)installSysctlHook;
+ (void)installDyldHide;
+ (void)installJailbreakHide;
@end

@interface AntiDetect (Injector)
+ (void)runInjectorScan;
+ (void)denyDebug;
@end

#endif //❗❗这个 #endif 千万不能丢，头文件保护闭合
