#import <Foundation/Foundation.h>
#ifndef PEEL_MANAGER_H
#define PEEL_MANAGER_H
@interface PeelManager : NSObject
+ (instancetype)shared;
- (void)startPeel;
- (void)stopPeel;
@end
#endif
