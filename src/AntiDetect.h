// AntiDetect.h — 反检测总入口（合并 ptrace/sysctl/dyld隐藏/越狱反制/注入器感知）
#ifndef ANTI_DETECT_H
#define ANTI_DETECT_H

#import <Foundation/Foundation.h>

@interface AntiDetect : NSObject

// 安装所有反检测 Hook（在 constructor 中调用）
+ (void)installAll;

// 单独安装各层
+ (void)installPtraceHook;      // Hook ptrace
+ (void)installSysctlHook;      // Hook sysctl（清除 P_TRACED）
+ (void)installDyldHide;        // dyld 镜像隐藏
+ (void)installJailbreakHide;   // 越狱检测反制
+ (void)runInjectorScan;        // 注入器环境感知

// 主动反调试
+ (void)denyDebug;               // ptrace(PT_DENY_ATTACH)

@end

#endif // ANTI_DETECT_H
