#import <Foundation/Foundation.h>
#ifndef ANTI_DETECT_H
#define ANTI_DETECT_H
@interface AntiDetect : NSObject
+ (instancetype)sharedInstance;
- (void)startProtect;
+ (void)installAll;
@end
#endif
