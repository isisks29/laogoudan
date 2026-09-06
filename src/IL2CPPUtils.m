// IL2CPPUtils.m — Unity IL2CPP 方法调用实
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
static void *(*il2cpp_class_get_static_field_value)(void *klass, void *field) = NULL;

@implementation IL2CPPUtils

+ (void)initialize {
    static BOOL initialized = NO;
    if (initialized) return;
    initialized = YES;
    
    // 从 UnityFramework 或主可执行文件中获取 il2cpp 函数
    // Unity 游戏的 il2cpp 通常在 UnityFramework.framework 中
    void *handle = NULL;
    
    // 尝试 UnityFramework
    handle = dlopen("/System/Library/Frameworks/UnityFramework.framework/UnityFramework", RTLD_LAZY);
    if (!handle) {
        // 尝试从主可执行文件获取
        handle = RTLD_DEFAULT;
    }
    
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
// 遍历所有程序集找类（不依赖Assembly-CSharp名称）
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
// 在指定程序集里找类（避免遍历所有程序集时找到错误的同名类）
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
    // 游戏没有 Assembly-CSharp.dll，直接遍历所有74个程序集找
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
    return il2cpp_runtime_invoke(method, (__bridge void *)instance ?: NULL, args ? args : NULL, &exc);
}

+ (void)callMethod:(const MethodInfo *)method instance:(Il2CppObject *)instance args:(void **)args returnBuf:(void *)retBuf {
    if (!il2cpp_runtime_invoke) [self initialize];
    if (!method || !retBuf) return;
    void *exc = NULL;
    void *ret = il2cpp_runtime_invoke(method, instance, args, &exc);
    if (ret) {
        // 对于值类型，返回值直接在 ret 指向的内存中
        // 这里简化处理，实际需要根据方法返回类型解析
        memcpy(retBuf, ret, sizeof(uintptr_t));
    }
}

+ (Il2CppObject *)callStaticMethod:(const MethodInfo *)method args:(void **)args {
    return [self callMethod:method instance:NULL args:args];
}

+ (BOOL)setBoolProperty:(NSString *)propertyName className:(NSString *)className instance:(Il2CppObject *)instance value:(BOOL)value {
    // setter 方法名通常是 set_XXX
    NSString *setterName = [NSString stringWithFormat:@"set_%@", propertyName];
    const MethodInfo *method = [self getMethod:setterName className:className argsCount:1];
    if (!method) return NO;
    
    BOOL val = value;
    void *args[1] = { &val };
    [self callMethod:method instance:instance args:args];
    return YES;
}

+ (BOOL)callBoolMethod:(NSString *)methodName className:(NSString *)className instance:(Il2CppObject *)instance value:(BOOL)value {
    // 直接调用方法名，不加 set_ 前缀（用于 FreeTypePress 这类非 setter 方法）
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
    void *args[1] = { NULL };
    [self callMethod:method instance:instance args:args];
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
    
    // 从对象获取类
    Il2CppClass *klass = *(Il2CppClass **)instance;
    if (!klass) return NULL;
    
    void *field = il2cpp_class_get_field_from_name(klass, fieldName.UTF8String);
    if (!field) return NULL;
    
    return il2cpp_field_get_value(instance, field);
}

#pragma mark - 游戏核心对象（需要根据具体游戏修改）

+ (Il2CppObject *)getGameCore {
    static Il2CppObject *cached = NULL;
    static BOOL hasTried = NO;
    if (hasTried) return cached;  // 只尝试一次，避免反复调用干扰游戏
    hasTried = YES;

    if (!il2cpp_class_from_name || !il2cpp_class_get_method_from_name || !il2cpp_runtime_invoke) [self initialize];

    // 优先在 BobPlugins.dll（游戏主程序集）里找，找不到再遍历所有程序集
    Il2CppClass *klass = [self findClassInImage:@"BobPlugins" className:@"GameCoreCenter"];
    if (!klass) klass = [self findClass:@"GameCoreCenter"];
    if (!klass) return cached;

    // 静态方法 getter（无参调用 args 传 NULL）
    NSArray *getters = @[@"get_instance", @"get_Instance", @"getSingleton", @"get_Singleton",
                          @"getCurrent", @"get_Current", @"getMain", @"get_Main"];
    for (NSString *getter in getters) {
        const MethodInfo *method = il2cpp_class_get_method_from_name(klass, getter.UTF8String, 0);
        if (method) {
            void *exc = NULL;
            Il2CppObject *result = il2cpp_runtime_invoke(method, NULL, NULL, &exc);
            if (result) { cached = result; return cached; }
        }
    }

    // 静态字段（更多可能的名字）
    if (il2cpp_class_get_field_from_name && il2cpp_field_static_get_value) {
        NSArray *fields = @[@"instance", @"Instance", @"_instance", @"_Instance",
                             @"s_instance", @"m_instance", @"__instance",
                             @"singleton", @"Singleton", @"_singleton",
                             @"current", @"Current", @"_current",
                             @"main", @"Main", @"_main", @"shared", @"Shared"];
        for (NSString *f in fields) {
            void *field = il2cpp_class_get_field_from_name(klass, f.UTF8String);
            if (field) {
                static uint8_t buf[256];
                il2cpp_field_static_get_value(field, buf);
                Il2CppObject *obj = *(Il2CppObject **)buf;
                if (obj) { cached = obj; return cached; }
            }
        }
    }
        // 方式3：直接读取静态字段数据区域，扫描非空对象指针
    if (il2cpp_class_get_static_field_data) {
        void *staticData = il2cpp_class_get_static_field_data(klass);
        if (staticData) {
            void **ptr = (void **)staticData;
            for (int i = 0; i < 24; i++) {
                void *obj = ptr[i];
                // 有效指针对齐检测：非空、4字节对齐、不是0xFFFFFFFF
                if (obj && ((uintptr_t)obj & 0x7) == 0 && (uintptr_t)obj > 0x10000) {
                    cached = obj;
                    return cached;
                }
            }
        }
    }

    return cached;
}
    return cached;
}
+ (NSString *)debugInfo {
    NSMutableString *info = [NSMutableString string];

    // 1. IL2CPP 函数指针状态
    [info appendString:@"=== IL2CPP 函数指针 ===\n"];
    [info appendFormat:@"domain_get: %@\n", il2cpp_domain_get ? @"✓" : @"✗"];
    [info appendFormat:@"class_from_name: %@\n", il2cpp_class_from_name ? @"✓" : @"✗"];
    [info appendFormat:@"class_get_method: %@\n", il2cpp_class_get_method_from_name ? @"✓" : @"✗"];
    [info appendFormat:@"runtime_invoke: %@\n", il2cpp_runtime_invoke ? @"✓" : @"✗"];
    [info appendFormat:@"field_static_get_value: %@\n", il2cpp_field_static_get_value ? @"✓" : @"✗"];

    // 2. 列出所有程序集
    if (il2cpp_domain_get && il2cpp_domain_get_assemblies && il2cpp_assembly_get_image && il2cpp_image_get_name) {
        void *domain = il2cpp_domain_get();
        size_t size = 0;
        void **assemblies = il2cpp_domain_get_assemblies(domain, &size);
        [info appendFormat:@"\n=== 程序集列表(共%zu个) ===\n", size];
        for (size_t i = 0; i < size && i < 25; i++) {
            void *image = il2cpp_assembly_get_image(assemblies[i]);
            if (image) {
                const char *name = il2cpp_image_get_name(image);
                if (name) [info appendFormat:@"%s\n", name];
            }
        }
    }

    // 3. 尝试找类
    [info appendString:@"\n=== 类查找 ===\n"];
    Il2CppClass *klass = [self findClass:@"GameCoreCenter"];
    [info appendFormat:@"GameCoreCenter: %@\n", klass ? @"✓" : @"✗"];
    Il2CppClass *klass2 = [self findClass:@"GameCore"];
    [info appendFormat:@"GameCore: %@\n", klass2 ? @"✓" : @"✗"];

    // 4. 如果找到 GameCoreCenter，列出所有可能的单例字段和方法
    if (klass) {
        [info appendString:@"\n=== 静态字段 ===\n"];
        NSArray *fields = @[@"Instance", @"instance", @"Singleton", @"singleton",
                             @"Current", @"current", @"Main", @"main",
                             @"_instance", @"_Instance", @"_singleton", @"shared", @"Shared"];
        for (NSString *f in fields) {
            void *field = il2cpp_class_get_field_from_name(klass, f.UTF8String);
            if (field) {
                [info appendFormat:@"%@: ✓", f];
                if (il2cpp_field_static_get_value) {
                    static uint8_t buf[256];
                    il2cpp_field_static_get_value(field, buf);
                    Il2CppObject *obj = *(Il2CppObject **)buf;
                    [info appendFormat:@" (值%@)", obj ? @"非空" : @"为空"];
                }
                [info appendString:@"\n"];
            }
        }
        [info appendString:@"\n=== Getter方法 ===\n"];
        NSArray *getters = @[@"get_Instance", @"get_instance", @"getSingleton", @"get_Singleton",
                              @"getCurrent", @"get_Current", @"getMain", @"get_Main",
                              @"get_shared", @"get_Shared", @"Instance", @"instance"];
        for (NSString *g in getters) {
            const MethodInfo *m = il2cpp_class_get_method_from_name(klass, g.UTF8String, 0);
            if (m) [info appendFormat:@"%@: ✓\n", g];
        }
        [info appendString:@"\n=== 业务方法 ===\n"];
        NSArray *methods = @[@"FreeTypePress", @"FreeTypeClick", @"set_BtnIsFeeding",
                              @"get_BtnIsFeeding", @"set_FeedBtnUp", @"set_skillFeedPress"];
        for (NSString *mname in methods) {
            const MethodInfo *m0 = il2cpp_class_get_method_from_name(klass, mname.UTF8String, 0);
            const MethodInfo *m1 = il2cpp_class_get_method_from_name(klass, mname.UTF8String, 1);
            if (m0 || m1) [info appendFormat:@"%@(0参%@ 1参%@)\n", mname, m0?@"✓":@"✗", m1?@"✓":@"✗"];
        }
    }

    return info;
}
+ (Il2CppObject *)getSkillManager {
    // 示例：从 GameCore 获取技能/按键管理器
    // 这是宏操作的核心对象，调用它的 set_skillFeedPress 等方法
    static Il2CppObject *cached = NULL;
    if (cached) return cached;
    
    Il2CppObject *core = [self getGameCore];
    if (!core) return NULL;
    
    // 通过字段获取 SkillManager
    cached = [self getField:@"skillManager" instance:core];
    return cached;
}

@end
