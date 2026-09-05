// Config.h — 全局配置（所有开关、数值、UI状态）
// 所有功能的开关和参数都存在这里，UI 只改配置，逻辑只读配置
#ifndef CONFIG_H
#define CONFIG_H

#import <Foundation/Foundation.h>

// 宏配置结构体
typedef struct {
    BOOL enabled;           // 是否启用
    float buttonX;          // 按钮位置 X（屏幕坐标，0-1 比例）
    float buttonY;          // 按钮位置 Y
    float buttonSize;       // 按钮大小（半径，pt）
    float pressDuration;    // 单次点击时长（毫秒）
    float interval;         // 点击间隔（毫秒）
} MacroConfig;

// 全局配置
@interface Config : NSObject
+ (instancetype)shared;
- (void)loadConfig;
@end
@interface GlobalConfig : NSObject

+ (instancetype)shared;

// ===== 反检测 =====
@property (assign) BOOL antiDetectEnabled;     // 总开关
@property (assign) BOOL ptraceHook;            // ptrace Hook
@property (assign) BOOL sysctlHook;            // sysctl Hook
@property (assign) BOOL dyldHide;              // dyld 镜像隐藏
@property (assign) BOOL jailbreakHide;         // 越狱检测反制
@property (assign) BOOL injectorDetect;        // 注入器感知

// ===== 功能开关 =====
@property (assign) BOOL shuangliandian;        // 双连点
@property (assign) BOOL jielim;                // 解限
@property (assign) BOOL lingmin;               // 灵敏
@property (assign) BOOL jieduan;               // 解断
@property (assign) BOOL mingzidaxiao;          // 名字大小
@property (assign) BOOL nianhe;                // 粘合
@property (assign) BOOL shiyedaxiao;           // 视野大小
@property (assign) BOOL qiutineixian;          // 球体内显
@property (assign) BOOL fangluzhi;             // 防录制
@property (assign) BOOL yaoganhuitan;          // 摇杆回弹

// ===== 功能数值（NSString存储，用户可输入任意值，应用时转为float/int）=====
@property (strong) NSString *mingziValue;       // 名字大小（用户输入字符串）
@property (strong) NSString *nianheValue;       // 粘合大小
@property (strong) NSString *shiyeValue;        // 视野大小
@property (strong) NSString *huitanValue;       // 摇杆回弹

// ===== 解限特殊配置 =====
@property (strong) NSString *jielimWriteValue;  // 解限写入值（用户输入）
@property (assign) BOOL jielimWriteAsInt;       // YES=按int写入, NO=按float写入
@property (strong) NSString *jielimSearchValue; // 解限搜索值（默认100）

// ===== 宏配置 =====
@property (assign) MacroConfig shiliufen;       // 16分（按住循环）
@property (assign) MacroConfig tuqiu;           // 吐球（按住循环）
@property (assign) MacroConfig sifen;           // 4分（点击触发，点两次）

// ===== UI 状态 =====
@property (assign) BOOL menuVisible;             // 菜单是否显示
@property (assign) NSInteger currentTab;         // 当前标签页（0=反检测, 1=功能, 2=宏）

// 保存/加载
- (void)save;
- (void)load;
- (void)reset;

@end

#endif // CONFIG_H
