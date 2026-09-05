// Config.m — 全局配置实现
#import "Config.h"

@implementation GlobalConfig

+ (instancetype)shared {
    static GlobalConfig *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[GlobalConfig alloc] init];
        [instance load];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // 默认值
        _antiDetectEnabled = YES;
        _ptraceHook = YES;
        _sysctlHook = YES;
        _dyldHide = YES;
        _jailbreakHide = YES;
        _injectorDetect = YES;
        
        // 功能数值（NSString，用户可输入任意值）
        _mingziValue = @"1.5";
        _nianheValue = @"1.7";
        _shiyeValue = @"50";
        _huitanValue = @"1.0";
        
        // 解限配置
        _jielimWriteValue = @"10";
        _jielimWriteAsInt = NO;  // 默认按float写入
        _jielimSearchValue = @"100";
        
        // 宏默认配置
        _shiliufen = (MacroConfig){NO, 0.85f, 0.75f, 35.0f, 47.0f, 20.0f};
        _tuqiu = (MacroConfig){NO, 0.75f, 0.85f, 40.0f, 50.0f, 30.0f};
        _sifen = (MacroConfig){NO, 0.90f, 0.65f, 30.0f, 30.0f, 100.0f};
        
        _menuVisible = NO;
        _currentTab = 1;
    }
    return self;
}

- (void)save {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    
    // 反检测
    [ud setBool:_antiDetectEnabled forKey:@"ad_enabled"];
    [ud setBool:_ptraceHook forKey:@"ad_ptrace"];
    [ud setBool:_sysctlHook forKey:@"ad_sysctl"];
    [ud setBool:_dyldHide forKey:@"ad_dyldhide"];
    [ud setBool:_jailbreakHide forKey:@"ad_jbhide"];
    [ud setBool:_injectorDetect forKey:@"ad_injector"];
    
    // 功能开关
    [ud setBool:_shuangliandian forKey:@"f_sld"];
    [ud setBool:_jielim forKey:@"f_jlm"];
    [ud setBool:_lingmin forKey:@"f_lm"];
    [ud setBool:_jieduan forKey:@"f_jd"];
    [ud setBool:_mingzidaxiao forKey:@"f_mzdx"];
    [ud setBool:_nianhe forKey:@"f_nh"];
    [ud setBool:_shiyedaxiao forKey:@"f_sydx"];
    [ud setBool:_qiutineixian forKey:@"f_qtnx"];
    [ud setBool:_fangluzhi forKey:@"f_flz"];
    [ud setBool:_yaoganhuitan forKey:@"f_yght"];
    
    // 功能数值
    [ud setObject:_mingziValue forKey:@"v_mingzi"];
    [ud setObject:_nianheValue forKey:@"v_nianhe"];
    [ud setObject:_shiyeValue forKey:@"v_shiye"];
    [ud setObject:_huitanValue forKey:@"v_huitan"];
    
    // 解限配置
    [ud setObject:_jielimWriteValue forKey:@"jl_write"];
    [ud setBool:_jielimWriteAsInt forKey:@"jl_asint"];
    [ud setObject:_jielimSearchValue forKey:@"jl_search"];
    
    // 宏配置
    [self saveMacro:_shiliufen forKey:@"m_16"];
    [self saveMacro:_tuqiu forKey:@"m_tq"];
    [self saveMacro:_sifen forKey:@"m_4"];
    
    [ud synchronize];
}

- (void)saveMacro:(MacroConfig)m forKey:(NSString *)key {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setBool:m.enabled forKey:[key stringByAppendingString:@"_en"]];
    [ud setFloat:m.buttonX forKey:[key stringByAppendingString:@"_x"]];
    [ud setFloat:m.buttonY forKey:[key stringByAppendingString:@"_y"]];
    [ud setFloat:m.buttonSize forKey:[key stringByAppendingString:@"_size"]];
    [ud setFloat:m.pressDuration forKey:[key stringByAppendingString:@"_press"]];
    [ud setFloat:m.interval forKey:[key stringByAppendingString:@"_int"]];
}

- (void)load {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    
    _antiDetectEnabled = [ud boolForKey:@"ad_enabled"];
    _ptraceHook = [ud boolForKey:@"ad_ptrace"];
    _sysctlHook = [ud boolForKey:@"ad_sysctl"];
    _dyldHide = [ud boolForKey:@"ad_dyldhide"];
    _jailbreakHide = [ud boolForKey:@"ad_jbhide"];
    _injectorDetect = [ud boolForKey:@"ad_injector"];
    
    _shuangliandian = [ud boolForKey:@"f_sld"];
    _jielim = [ud boolForKey:@"f_jlm"];
    _lingmin = [ud boolForKey:@"f_lm"];
    _jieduan = [ud boolForKey:@"f_jd"];
    _mingzidaxiao = [ud boolForKey:@"f_mzdx"];
    _nianhe = [ud boolForKey:@"f_nh"];
    _shiyedaxiao = [ud boolForKey:@"f_sydx"];
    _qiutineixian = [ud boolForKey:@"f_qtnx"];
    _fangluzhi = [ud boolForKey:@"f_flz"];
    _yaoganhuitan = [ud boolForKey:@"f_yght"];
    
    if ([ud objectForKey:@"v_mingzi"]) _mingziValue = [ud stringForKey:@"v_mingzi"];
    if ([ud objectForKey:@"v_nianhe"]) _nianheValue = [ud stringForKey:@"v_nianhe"];
    if ([ud objectForKey:@"v_shiye"]) _shiyeValue = [ud stringForKey:@"v_shiye"];
    if ([ud objectForKey:@"v_huitan"]) _huitanValue = [ud stringForKey:@"v_huitan"];
    
    if ([ud objectForKey:@"jl_write"]) _jielimWriteValue = [ud stringForKey:@"jl_write"];
    if ([ud objectForKey:@"jl_asint"]) _jielimWriteAsInt = [ud boolForKey:@"jl_asint"];
    if ([ud objectForKey:@"jl_search"]) _jielimSearchValue = [ud stringForKey:@"jl_search"];
    
    _shiliufen = [self loadMacro:@"m_16" default:_shiliufen];
    _tuqiu = [self loadMacro:@"m_tq" default:_tuqiu];
    _sifen = [self loadMacro:@"m_4" default:_sifen];
}

- (MacroConfig)loadMacro:(NSString *)key default:(MacroConfig)def {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    MacroConfig m = def;
    NSString *enKey = [key stringByAppendingString:@"_en"];
    if ([ud objectForKey:enKey]) {
        m.enabled = [ud boolForKey:enKey];
        m.buttonX = [ud floatForKey:[key stringByAppendingString:@"_x"]];
        m.buttonY = [ud floatForKey:[key stringByAppendingString:@"_y"]];
        m.buttonSize = [ud floatForKey:[key stringByAppendingString:@"_size"]];
        m.pressDuration = [ud floatForKey:[key stringByAppendingString:@"_press"]];
        m.interval = [ud floatForKey:[key stringByAppendingString:@"_int"]];
    }
    return m;
}

- (void)reset {
    // 重置为默认值（重新 init）
    GlobalConfig *fresh = [[GlobalConfig alloc] init];
    [self setValuesForKeysWithDictionary:@{
        @"antiDetectEnabled": @(fresh.antiDetectEnabled),
        @"mingziValue": fresh.mingziValue,
        @"nianheValue": fresh.nianheValue,
        @"shiyeValue": fresh.shiyeValue,
        @"huitanValue": fresh.huitanValue,
        @"jielimWriteValue": fresh.jielimWriteValue,
        @"jielimWriteAsInt": @(fresh.jielimWriteAsInt),
        @"jielimSearchValue": fresh.jielimSearchValue,
    }];
    _shiliufen = fresh.shiliufen;
    _tuqiu = fresh.tuqiu;
    _sifen = fresh.sifen;
    [self save];
}

@end
