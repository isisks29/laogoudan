// Config.h — 全局配置
#ifndef CONFIG_H
#define CONFIG_H
#import <Foundation/Foundation.h>

typedef struct {
    BOOL enabled;
    float buttonX;
    float buttonY;
    float buttonSize;
    float pressDuration;
    float interval;
} MacroConfig;

@interface GlobalConfig : NSObject
+ (instancetype)shared;

// ===== 功能开关 =====
@property (assign) BOOL shuangliandian;
@property (assign) BOOL jielim;
@property (assign) BOOL lingmin;
@property (assign) BOOL jieduan;
@property (assign) BOOL mingzidaxiao;
@property (assign) BOOL nianhe;
@property (assign) BOOL shiyedaxiao;
@property (assign) BOOL qiutineixian;
@property (assign) BOOL fangluzhi;
@property (assign) BOOL yaoganhuitan;

// ===== 美化功能 =====
@property (assign) BOOL peelEnabled;        // 去皮

// ===== 功能数值 =====
@property (strong) NSString *mingziValue;
@property (strong) NSString *nianheValue;
@property (strong) NSString *shiyeValue;
@property (strong) NSString *huitanValue;

// ===== 解限配置 =====
@property (strong) NSString *jielimWriteValue;
@property (assign) BOOL jielimWriteAsInt;
@property (strong) NSString *jielimSearchValue;

// ===== 宏配置 =====
@property (assign) MacroConfig shiliufen;
@property (assign) MacroConfig tuqiu;
@property (assign) MacroConfig sifen;

// ===== UI 状态 =====
@property (assign) BOOL menuVisible;
@property (assign) NSInteger currentTab;

- (void)save;
- (void)load;
- (void)reset;
@end
#endif
