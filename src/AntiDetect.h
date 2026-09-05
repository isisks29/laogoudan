// AntiDetect.h — 反检测总入口（合并 ptrace/sysctl/dyld隐藏/越狱反制/注入器感知）
#ifndef ANTI_DETECT_H
#define ANTI_DETECT_H
#import <Foundation/Foundation.h>

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
