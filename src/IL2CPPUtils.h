// IL2CPPUtils.h — Unity IL2CPP 方法调用工具
// 实现 B 类功能（IL2CPP 方法调用型）和宏的基础设施
// 宏的核心：直接调用游戏的 IL2CPP 方法（如 set_skillFeedPress），而不是模拟触摸
#ifndef IL2CPP_UTILS_H
#define IL2CPP_UTILS_H

#import <Foundation/Foundation.h>
#import <stdint.h>

// IL2CPP 不透明类型
typedef void Il2CppObject;
typedef void Il2CppClass;
typedef void MethodInfo;
typedef void Il2CppDomain;
typedef void Il2CppImage;

@interface IL2CPPUtils : NSObject
+ (void)callVoidMethod:(NSString *)methodName className:(NSString *)className instance:(Il2CppObject *)instance;

// 初始化（获取 il2cpp 函数指针）
+ (void)initialize;

// 获取游戏的主域
+ (Il2CppDomain *)getDomain;

// 通过程序集名获取 Image
+ (Il2CppImage *)getImage:(NSString *)assemblyName;

// 通过类名和命名空间获取 Class
+ (Il2CppClass *)getClass:(NSString *)className namespace:(NSString *)ns;
+ (Il2CppClass *)getClass:(NSString *)className;  // 默认命名空间为空

// 通过方法名获取 MethodInfo
+ (const MethodInfo *)getMethod:(NSString *)methodName className:(NSString *)className argsCount:(int)args;
+ (const MethodInfo *)getMethod:(NSString *)methodName class:(Il2CppClass *)klass argsCount:(int)args;

// 调用实例方法（返回对象）
+ (Il2CppObject *)callMethod:(const MethodInfo *)method instance:(Il2CppObject *)instance args:(void **)args;

// 调用实例方法（返回值类型，如 int/float/bool）
+ (void)callMethod:(const MethodInfo *)method instance:(Il2CppObject *)instance args:(void **)args returnBuf:(void *)retBuf;

// 调用静态方法
+ (Il2CppObject *)callStaticMethod:(const MethodInfo *)method args:(void **)args;

// 便捷方法：调用 setter（设置 bool 属性，自动加 set_ 前缀）
+ (BOOL)setBoolProperty:(NSString *)propertyName className:(NSString *)className instance:(Il2CppObject *)instance value:(BOOL)value;
// 便捷方法：直接调用 bool 方法（不加 set_ 前缀，用于 FreeTypePress 这类非 setter 方法）
+ (BOOL)callBoolMethod:(NSString *)methodName className:(NSString *)className instance:(Il2CppObject *)instance value:(BOOL)value;

// 便捷方法：调用 setter（设置 float 属性）
+ (BOOL)setFloatProperty:(NSString *)propertyName className:(NSString *)className instance:(Il2CppObject *)instance value:(float)val;

// 获取类的静态字段地址
+ (void *)getStaticFieldAddress:(NSString *)fieldName className:(NSString *)className;

// 获取实例字段值
+ (Il2CppObject *)getField:(NSString *)fieldName instance:(Il2CppObject *)instance;

// 获取游戏核心对象（需要根据具体游戏修改）
+ (Il2CppObject *)getGameCore;
+ (Il2CppObject *)getSkillManager;  // 技能/按键管理器（宏的核心对象）

@end

#endif // IL2CPP_UTILS_H
