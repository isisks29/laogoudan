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

// ===== 功能开关（8种数值功能）=====
@property (assign) BOOL shuangliandian;   // 双连点
@property (assign) BOOL jieduantu;        // 解断吐
@property (assign) BOOL mingzidaxiao;     // 名字大小
@property (assign) BOOL nianhe;           // 粘合
@property (assign) BOOL jielim;           // 解限
@property (assign) BOOL shiyedaxiao;      // 视野大小
@property (assign) BOOL fangluzhi;        // 防录制
@property (assign) BOOL lingmin;          // 摇杆灵敏

// ===== 次要功能（暂不实现）=====
@property (assign) BOOL qiutineixian;     // 球体内显
@property (assign) BOOL yaoganhuitan;     // 摇杆回弹

// ===== 美化功能 =====
@property (assign) BOOL peelEnabled;       // 去皮
@property (assign) BOOL debugMode;         // 调试模式

// ===== 功能数值（用户自定义）=====
@property (strong) NSString *mingziValue;  // 名字大小值（默认1.875）
@property (strong) NSString *nianheValue;  // 粘合值（默认1.7）
@property (strong) NSString *shiyeValue;   // 视野值（默认1.0）

// ===== 解限配置 =====
@property (strong) NSString *jielimWriteValue;   // 解限写入值
@property (assign) BOOL jielimWriteAsInt;        // 按int写入（NO=float）
@property (strong) NSString *jielimSearchValue;  // 解限搜索值

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
