//
//  Watchdog.h
//  MeloNX
//
//  Created by Stossy11 on 26/2/2026.
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Watchdog : NSObject

@property (class, nonatomic, readonly) Watchdog *shared;

- (void)start;
- (void)stop;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END