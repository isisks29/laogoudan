// Config.m — 全局配置实现
#import "Config.h"

@implementation GlobalConfig

+ (instancetype)shared {
    static GlobalConfig *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[GlobalConfig alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self resetDefaults];
    }
    return self;
}

- (void)resetDefaults {
    // ===== 功能开关：全部默认关闭 =====
    _shuangliandian = NO;
    _jielim = NO;
    _lingmin = NO;
    _jieduan = NO;
    _mingzidaxiao = NO;
    _nianhe = NO;
    _shiyedaxiao = NO;
    _qiutineixian = NO;
    _fangluzhi = NO;
    _yaoganhuitan = NO;
    _peelEnabled = NO;
    _debugMode = NO;

    // 功能数值
    _mingziValue = @"1.5";
    _nianheValue = @"1.7";
    _shiyeValue = @"50";
    _huitanValue = @"1.0";

    // 解限
    _jielimWriteValue = @"10";
    _jielimWriteAsInt = NO;
    _jielimSearchValue = @"100";

    // 宏默认参数（位置/大小保留，enabled默认关）
    _shiliufen = (MacroConfig){NO, 0.85f, 0.75f, 35.0f, 47.0f, 20.0f};
    _tuqiu = (MacroConfig){NO, 0.75f, 0.85f, 40.0f, 50.0f, 30.0f};
    _sifen = (MacroConfig){NO, 0.90f, 0.65f, 30.0f, 30.0f, 100.0f};

    _menuVisible = NO;
    _currentTab = 0;
}

- (void)save {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

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
    [ud setBool:_peelEnabled forKey:@"f_peel"];
    [ud setBool:_debugMode forKey:@"debug_mode"];

    [ud setObject:_mingziValue forKey:@"v_mingzi"];
    [ud setObject:_nianheValue forKey:@"v_nianhe"];
    [ud setObject:_shiyeValue forKey:@"v_shiye"];
    [ud setObject:_huitanValue forKey:@"v_huitan"];

    [ud setObject:_jielimWriteValue forKey:@"jl_write"];
    [ud setBool:_jielimWriteAsInt forKey:@"jl_asint"];
    [ud setObject:_jielimSearchValue forKey:@"jl_search"];

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

    // 功能数值（保留用户设置）
    if ([ud objectForKey:@"v_mingzi"]) _mingziValue = [ud stringForKey:@"v_mingzi"];
    if ([ud objectForKey:@"v_nianhe"]) _nianheValue = [ud stringForKey:@"v_nianhe"];
    if ([ud objectForKey:@"v_shiye"]) _shiyeValue = [ud stringForKey:@"v_shiye"];
    if ([ud objectForKey:@"v_huitan"]) _huitanValue = [ud stringForKey:@"v_huitan"];

    if ([ud objectForKey:@"jl_write"]) _jielimWriteValue = [ud stringForKey:@"jl_write"];
    if ([ud objectForKey:@"jl_asint"]) _jielimWriteAsInt = [ud boolForKey:@"jl_asint"];
    if ([ud objectForKey:@"jl_search"]) _jielimSearchValue = [ud stringForKey:@"jl_search"];

    // 宏参数（位置大小保留，enabled强制关）
    _shiliufen = [self loadMacro:@"m_16" default:_shiliufen];
    _tuqiu = [self loadMacro:@"m_tq" default:_tuqiu];
    _sifen = [self loadMacro:@"m_4" default:_sifen];

    // ===== 关键：所有开关强制关闭，不记忆上次状态 =====
    _shuangliandian = NO;
    _jielim = NO;
    _lingmin = NO;
    _jieduan = NO;
    _mingzidaxiao = NO;
    _nianhe = NO;
    _shiyedaxiao = NO;
    _qiutineixian = NO;
    _fangluzhi = NO;
    _yaoganhuitan = NO;
    _peelEnabled = NO;
    _shiliufen.enabled = NO;
    _tuqiu.enabled = NO;
    _sifen.enabled = NO;
    _menuVisible = NO;
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
    [self resetDefaults];
    [self save];
}

@end
