// IL2CPPUtils.m — Unity IL2CPP 方法调用实现
#import "IL2CPPUtils.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>

// IL2CPP 函数指针
static void *(*il2cpp_domain_get)(void) = NULL;
static void *(*il2cpp_domain_get_assemblies)(void *domain, size_t *size) = NULL;
static void *(*il2cpp_assembly_get_image)(void *assembly) = NULL;
static void *(*il2cpp_class_from_name)(void *image, const char *namespace, const char *name) = NULL;
static void *(*il2cpp_class_get_method_from_name)(void *klass, const char *name, int argsCount) = NULL;
static void *(*il2cpp_runtime_invoke)(const void *method, void *obj, void **params, void **exc) = NULL;
static void *(*il2cpp_class_get_field_from_name)(void *klass, const char *name) = NULL;
static void *(*il2cpp_field_get_value)(void *obj, void *field) = NULL;
static void *(*il2cpp_field_static_get_value)(void *field, void *value) = NULL;
static void *(*il2cpp_image_get_name)(void *image) = NULL;
// 新增：JuziHub也用这两个
static void (*il2cpp_runtime_class_init)(void *klass) = NULL;
static void *(*il2cpp_class_get_static_field_data)(void *klass) = NULL;

@implementation IL2CPPUtils

+ (void)initialize {
    static BOOL initialized = NO;
    if (initialized) return;
    initialized = YES;

    void *handle = dlopen("/System/Library/Frameworks/UnityFramework.framework/UnityFramework", RTLD_LAZY);
    if (!handle) handle = RTLD_DEFAULT;

    #define LOAD_SYM(name) name = (void *)dlsym(handle, #name)
    LOAD_SYM(il2cpp_domain_get);
    LOAD_SYM(il2cpp_domain_get_assemblies);
    LOAD_SYM(il2cpp_assembly_get_image);
    LOAD_SYM(il2cpp_class_from_name);
    LOAD_SYM(il2cpp_class_get_method_from_name);
    LOAD_SYM(il2cpp_runtime_invoke);
    LOAD_SYM(il2cpp_class_get_field_from_name);
    LOAD_SYM(il2cpp_field_get_value);
    LOAD_SYM(il2cpp_field_static_get_value);
    LOAD_SYM(il2cpp_image_get_name);
    LOAD_SYM(il2cpp_runtime_class_init);
    LOAD_SYM(il2cpp_class_get_static_field_data);
    #undef LOAD_SYM
}

+ (Il2CppDomain *)getDomain {
    if (!il2cpp_domain_get) [self initialize];
    return il2cpp_domain_get ? il2cpp_domain_get() : NULL;
}

+ (Il2CppImage *)getImage:(NSString *)assemblyName {
    if (!il2cpp_domain_get_assemblies || !il2cpp_assembly_get_image) [self initialize];
    Il2CppDomain *domain = [self getDomain];
    if (!domain) return NULL;
    size_t size = 0;
    void **assemblies = il2cpp_domain_get_assemblies(domain, &size);
    if (!assemblies) return NULL;
    for (size_t i = 0; i < size; i++) {
        void *image = il2cpp_assembly_get_image(assemblies[i]);
        if (image && il2cpp_image_get_name) {
            const char *name = il2cpp_image_get_name(image);
            if (name && [[NSString stringWithUTF8String:name] containsString:assemblyName]) {
                return image;
            }
        }
    }
    return NULL;
}

+ (Il2CppClass *)findClass:(NSString *)className {
    if (!il2cpp_domain_get || !il2cpp_domain_get_assemblies || !il2cpp_assembly_get_image || !il2cpp_class_from_name) [self initialize];
    void *domain = il2cpp_domain_get();
    if (!domain) return NULL;
    size_t size = 0;
    void **assemblies = il2cpp_domain_get_assemblies(domain, &size);
    if (!assemblies) return NULL;
    for (size_t i = 0; i < size; i++) {
        void *image = il2cpp_assembly_get_image(assemblies[i]);
        if (!image) continue;
        void *klass = il2cpp_class_from_name(image, "", className.UTF8String);
        if (klass) return klass;
    }
    return NULL;
}

+ (Il2CppClass *)findClassInImage:(NSString *)imageNeedle className:(NSString *)className {
    if (!il2cpp_domain_get || !il2cpp_domain_get_assemblies || !il2cpp_assembly_get_image || !il2cpp_image_get_name || !il2cpp_class_from_name) [self initialize];
    void *domain = il2cpp_domain_get();
    if (!domain) return NULL;
    size_t size = 0;
    void **assemblies = il2cpp_domain_get_assemblies(domain, &size);
    if (!assemblies) return NULL;
    for (size_t i = 0; i < size; i++) {
        void *image = il2cpp_assembly_get_image(assemblies[i]);
        if (!image) continue;
        const char *name = il2cpp_image_get_name(image);
        if (name && [[NSString stringWithUTF8String:name] containsString:imageNeedle]) {
            void *klass = il2cpp_class_from_name(image, "", className.UTF8String);
            if (klass) return klass;
        }
    }
    return NULL;
}

+ (Il2CppClass *)getClass:(NSString *)className namespace:(NSString *)ns {
    if (!il2cpp_class_from_name) [self initialize];
    return [self findClass:className];
}

+ (Il2CppClass *)getClass:(NSString *)className {
    return [self getClass:className namespace:@""];
}

+ (const MethodInfo *)getMethod:(NSString *)methodName className:(NSString *)className argsCount:(int)args {
    Il2CppClass *klass = [self getClass:className];
    return [self getMethod:methodName class:klass argsCount:args];
}

+ (const MethodInfo *)getMethod:(NSString *)methodName class:(Il2CppClass *)klass argsCount:(int)args {
    if (!il2cpp_class_get_method_from_name) [self initialize];
    if (!klass) return NULL;
    return il2cpp_class_get_method_from_name(klass, methodName.UTF8String, args);
}

+ (Il2CppObject *)callMethod:(const MethodInfo *)method instance:(Il2CppObject *)instance args:(void **)args {
    if (!il2cpp_runtime_invoke) [self initialize];
    if (!method) return NULL;
    void *exc = NULL;
    return il2cpp_runtime_invoke(method, instance, args ? args : NULL, &exc);
}

+ (void)callMethod:(const MethodInfo *)method instance:(Il2CppObject *)instance args:(void **)args returnBuf:(void *)retBuf {
    if (!il2cpp_runtime_invoke) [self initialize];
    if (!method || !retBuf) return;
    void *exc = NULL;
    void *ret = il2cpp_runtime_invoke(method, instance, args, &exc);
    if (ret) memcpy(retBuf, ret, sizeof(uintptr_t));
}

+ (Il2CppObject *)callStaticMethod:(const MethodInfo *)method args:(void **)args {
    return [self callMethod:method instance:NULL args:args];
}

+ (BOOL)setBoolProperty:(NSString *)propertyName className:(NSString *)className instance:(Il2CppObject *)instance value:(BOOL)value {
    NSString *setterName = [NSString stringWithFormat:@"set_%@", propertyName];
    const MethodInfo *method = [self getMethod:setterName className:className argsCount:1];
    if (!method) return NO;
    BOOL val = value;
    void *args[1] = { &val };
    [self callMethod:method instance:instance args:args];
    return YES;
}

+ (BOOL)callBoolMethod:(NSString *)methodName className:(NSString *)className instance:(Il2CppObject *)instance value:(BOOL)value {
    const MethodInfo *method = [self getMethod:methodName className:className argsCount:1];
    if (!method) return NO;
    BOOL val = value;
    void *args[1] = { &val };
    [self callMethod:method instance:instance args:args];
    return YES;
}

+ (void)callVoidMethod:(NSString *)methodName className:(NSString *)className instance:(Il2CppObject *)instance {
    const MethodInfo *method = [self getMethod:methodName className:className argsCount:0];
    if (!method || !instance) return;
    [self callMethod:method instance:instance args:NULL];
}

+ (BOOL)setFloatProperty:(NSString *)propertyName className:(NSString *)className instance:(Il2CppObject *)instance value:(float)val {
    NSString *setterName = [NSString stringWithFormat:@"set_%@", propertyName];
    const MethodInfo *method = [self getMethod:setterName className:className argsCount:1];
    if (!method) return NO;
    void *args[1] = { &val };
    [self callMethod:method instance:instance args:args];
    return YES;
}

+ (void *)getStaticFieldAddress:(NSString *)fieldName className:(NSString *)className {
    if (!il2cpp_class_get_field_from_name || !il2cpp_field_static_get_value) [self initialize];
    Il2CppClass *klass = [self getClass:className];
    if (!klass) return NULL;
    void *field = il2cpp_class_get_field_from_name(klass, fieldName.UTF8String);
    if (!field) return NULL;
    static uint8_t valueBuf[256];
    il2cpp_field_static_get_value(field, valueBuf);
    return *(void **)valueBuf;
}

+ (Il2CppObject *)getField:(NSString *)fieldName instance:(Il2CppObject *)instance {
    if (!il2cpp_class_get_field_from_name || !il2cpp_field_get_value) [self initialize];
    if (!instance) return NULL;
    Il2CppClass *klass = *(Il2CppClass **)instance;
    if (!klass) return NULL;
    void *field = il2cpp_class_get_field_from_name(klass, fieldName.UTF8String);
    if (!field) return NULL;
    return il2cpp_field_get_value(instance, field);
}

#pragma mark - 游戏核心对象（照搬JuziHub架构）

+ (Il2CppObject *)getGameCore {
    static Il2CppObject *cached = NULL;
    if (cached) return cached;  // 成功后缓存，失败不缓存（下次还能重试）

    if (!il2cpp_class_from_name || !il2cpp_class_get_method_from_name || !il2cpp_runtime_invoke) [self initialize];

    // 优先在 BobPlugins.dll（游戏主程序集）里找
    Il2CppClass *klass = [self findClassInImage:@"BobPlugins" className:@"GameCoreCenter"];
    if (!klass) klass = [self findClass:@"GameCoreCenter"];
    if (!klass) return NULL;

    // 关键1：先初始化类（JuziHub也用il2cpp_runtime_class_init）
    if (il2cpp_runtime_class_init) {
        il2cpp_runtime_class_init(klass);
    }

    // 关键2：调用 get_instance 静态方法（调试确认是小写get_instance，无参）
    NSArray *getters = @[@"get_instance", @"get_Instance"];
    for (NSString *getter in getters) {
        const MethodInfo *method = il2cpp_class_get_method_from_name(klass, getter.UTF8String, 0);
        if (method) {
            void *exc = NULL;
            Il2CppObject *result = il2cpp_runtime_invoke(method, NULL, NULL, &exc);
            if (result && !exc) {
                cached = result;
                return cached;
            }
        }
    }

    // 关键3：备用 — 直接读取静态字段数据区域（JuziHub用il2cpp_class_get_static_field_data）
    if (il2cpp_class_get_static_field_data) {
        void *staticData = il2cpp_class_get_static_field_data(klass);
        if (staticData) {
            void **ptr = (void **)staticData;
            for (int i = 0; i < 32; i++) {
                void *obj = ptr[i];
                if (obj && ((uintptr_t)obj & 0x7) == 0 && (uintptr_t)obj > 0x10000) {
                    cached = obj;
                    return cached;
                }
            }
        }
    }

    return NULL;  // 失败返回NULL，不缓存，下次调用还能重试
}

+ (Il2CppObject *)getSkillManager {
    static Il2CppObject *cached = NULL;
    if (cached) return cached;
    Il2CppObject *core = [self getGameCore];
    if (!core) return NULL;
    cached = [self getField:@"skillManager" instance:core];
    return cached;
}

#pragma mark - 调试信息

+ (NSString *)debugInfo {
    NSMutableString *info = [NSMutableString string];
    [info appendString:@"=== IL2CPP 函数指针 ===\n"];
    [info appendFormat:@"domain_get: %@\n", il2cpp_domain_get ? @"✓" : @"✗"];
    [info appendFormat:@"class_from_name: %@\n", il2cpp_class_from_name ? @"✓" : @"✗"];
    [info appendFormat:@"runtime_invoke: %@\n", il2cpp_runtime_invoke ? @"✓" : @"✗"];
    [info appendFormat:@"runtime_class_init: %@\n", il2cpp_runtime_class_init ? @"✓" : @"✗"];
    [info appendFormat:@"static_field_data: %@\n", il2cpp_class_get_static_field_data ? @"✓" : @"✗"];

    Il2CppObject *core = [self getGameCore];
    [info appendFormat:@"\n=== GameCore实例 ===\n%@\n", core ? @"✓ 已获取" : @"✗ 未获取（重试中）"];

    Il2CppClass *klass = [self findClass:@"GameCoreCenter"];
    [info appendFormat:@"\n=== 类查找 ===\nGameCoreCenter: %@\n", klass ? @"✓" : @"✗"];

    if (klass) {
        [info appendString:@"\n=== Getter方法 ===\n"];
        NSArray *getters = @[@"get_instance", @"get_Instance"];
        for (NSString *g in getters) {
            const MethodInfo *m = il2cpp_class_get_method_from_name(klass, g.UTF8String, 0);
            if (m) [info appendFormat:@"%@: ✓\n", g];
        }
                [info appendString:@"\n=== 业务方法(0参/1参) ===\n"];
        NSArray *methods = @[@"FreeTypePress", @"FreeTypeClick",
                             @"set_BtnIsFeeding", @"get_BtnIsFeeding",
                             @"set_FeedBtnUp", @"get_FeedBtnUp",
                             @"set_skillFeedPress"];
        for (NSString *mname in methods) {
            const MethodInfo *m0 = il2cpp_class_get_method_from_name(klass, mname.UTF8String, 0);
            const MethodInfo *m1 = il2cpp_class_get_method_from_name(klass, mname.UTF8String, 1);
            if (m0 || m1) [info appendFormat:@"%@(0%@ 1%@)\n", mname, m0?@"✓":@"✗", m1?@"✓":@"✗"];
        }

        // 检查 UITouchControl 类（按键控制可能在这个类）
        Il2CppClass *touchKlass = [self findClass:@"UITouchControl"];
        [info appendFormat:@"\n=== UITouchControl类 ===\n%@\n", touchKlass ? @"✓ 存在" : @"✗ 不存在"];
        if (touchKlass) {
            NSArray *touchMethods = @[@"OnPress", @"OnDragOver", @"ResetJoystick", @"set_JostickDir", @"SendMove"];
            for (NSString *tm in touchMethods) {
                const MethodInfo *tm0 = il2cpp_class_get_method_from_name(touchKlass, tm.UTF8String, 0);
                const MethodInfo *tm1 = il2cpp_class_get_method_from_name(touchKlass, tm.UTF8String, 1);
                const MethodInfo *tm2 = il2cpp_class_get_method_from_name(touchKlass, tm.UTF8String, 2);
                if (tm0 || tm1 || tm2) [info appendFormat:@"%@(0%@ 1%@ 2%@)\n", tm, tm0?@"✓":@"✗", tm1?@"✓":@"✗", tm2?@"✓":@"✗"];
            }
        }
    return info;
}

@end
