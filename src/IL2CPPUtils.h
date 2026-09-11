// IL2CPPUtils.h — Unity IL2CPP 方法调用工具
#ifndef IL2CPP_UTILS_H
#define IL2CPP_UTILS_H
#import <Foundation/Foundation.h>
#import <stdint.h>

typedef void Il2CppObject;
typedef void Il2CppClass;
typedef void MethodInfo;
typedef void Il2CppDomain;
typedef void Il2CppImage;

@interface IL2CPPUtils : NSObject
+ (NSString *)debugInfo;
+ (void)callVoidMethod:(NSString *)methodName className:(NSString *)className instance:(Il2CppObject *)instance;
+ (void)initialize;
+ (Il2CppDomain *)getDomain;
+ (Il2CppImage *)getImage:(NSString *)assemblyName;
+ (Il2CppClass *)findClass:(NSString *)className;
+ (Il2CppClass *)findClassInImage:(NSString *)imageNeedle className:(NSString *)className;
+ (Il2CppClass *)getClass:(NSString *)className namespace:(NSString *)ns;
+ (Il2CppClass *)getClass:(NSString *)className;
+ (const MethodInfo *)getMethod:(NSString *)methodName className:(NSString *)className argsCount:(int)args;
+ (const MethodInfo *)getMethod:(NSString *)methodName class:(Il2CppClass *)klass argsCount:(int)args;
+ (Il2CppObject *)callMethod:(const MethodInfo *)method instance:(Il2CppObject *)instance args:(void **)args;
+ (void)callMethod:(const MethodInfo *)method instance:(Il2CppObject *)instance args:(void **)args returnBuf:(void *)retBuf;
+ (Il2CppObject *)callStaticMethod:(const MethodInfo *)method args:(void **)args;
+ (BOOL)setBoolProperty:(NSString *)propertyName className:(NSString *)className instance:(Il2CppObject *)instance value:(BOOL)value;
+ (BOOL)callBoolMethod:(NSString *)methodName className:(NSString *)className instance:(Il2CppObject *)instance value:(BOOL)value;
+ (BOOL)setFloatProperty:(NSString *)propertyName className:(NSString *)className instance:(Il2CppObject *)instance value:(float)val;
+ (void *)getStaticFieldAddress:(NSString *)fieldName className:(NSString *)className;
+ (Il2CppObject *)getField:(NSString *)fieldName instance:(Il2CppObject *)instance;
+ (Il2CppObject *)getGameCore;
+ (Il2CppObject *)getSkillManager;
@end
#endif
