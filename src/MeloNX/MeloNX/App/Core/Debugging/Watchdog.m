//
//  Watchdog.m
//  MeloNX
//
//  Created by Stossy11 on 26/2/2026.
//


#import "Watchdog.h"
#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIKit.h>
#import <mach/mach.h>
#import <pthread.h>
#import <stdatomic.h>
#import <fcntl.h>
#import <unistd.h>
#import "MachBacktracer.h"

static const int32_t kWatchdogHangThreshold = 3;
static const useconds_t kWatchdogPollInterval = 1000000;
static const NSTimeInterval kWatchdogGracePeriod = 5.0;

@implementation Watchdog {
    pthread_t _thread;
    mach_port_t _mainThreadPort;
    _Atomic(int32_t) _heartbeat;
    _Atomic(bool) _isRunning;
    _Atomic(bool) _isSuspended;
    int32_t _lastHeartbeat;
    int32_t _missCount;
    NSTimeInterval _startTime;
    id _foregroundObserver;
    id _backgroundObserver;
}

+ (instancetype)shared {
    static Watchdog *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[Watchdog alloc] _init];
    });
    return instance;
}

- (instancetype)_init {
    if (self = [super init]) {
        atomic_init(&_heartbeat, 0);
        atomic_init(&_isRunning, false);
        atomic_init(&_isSuspended, false);
        _lastHeartbeat = 0;
        _missCount = 0;
        _mainThreadPort = MACH_PORT_NULL;
    }
    return self;
}

- (void)start {
    NSAssert(NSThread.isMainThread, @"start must be called from the main thread");
    bool expected = false;
    if (!atomic_compare_exchange_strong(&_isRunning, &expected, true)) {
        return;
    }

    _mainThreadPort = pthread_mach_thread_np(pthread_self());
    _startTime = [NSDate timeIntervalSinceReferenceDate];

    __unsafe_unretained Watchdog *weakSelf = self;
    _backgroundObserver = [[NSNotificationCenter defaultCenter]
        addObserverForName:UIApplicationDidEnterBackgroundNotification
                    object:nil queue:nil
                usingBlock:^(NSNotification *note) {
                    atomic_store(&weakSelf->_isSuspended, true);
                }];
    _foregroundObserver = [[NSNotificationCenter defaultCenter]
        addObserverForName:UIApplicationDidBecomeActiveNotification
                    object:nil queue:nil
                usingBlock:^(NSNotification *note) {
                    atomic_store_explicit(&weakSelf->_heartbeat, 0, memory_order_relaxed);
                    weakSelf->_lastHeartbeat = 0;
                    weakSelf->_missCount = 0;
                    weakSelf->_startTime = [NSDate timeIntervalSinceReferenceDate];
                    atomic_store(&weakSelf->_isSuspended, false);
                }];

    CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(
        kCFAllocatorDefault,
        kCFRunLoopAllActivities,
        true, 0,
        ^(CFRunLoopObserverRef obs, CFRunLoopActivity activity) {
            atomic_fetch_add_explicit(&weakSelf->_heartbeat, 1, memory_order_relaxed);
        }
    );
    CFRunLoopAddObserver(CFRunLoopGetMain(), observer, kCFRunLoopCommonModes);
    CFRelease(observer);

    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
    pthread_create(&_thread, &attr, watchdogThreadEntry, (__bridge void *)self);
    pthread_attr_destroy(&attr);
}

- (void)stop {
    atomic_store(&_isRunning, false);
    if (_foregroundObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:_foregroundObserver];
        _foregroundObserver = nil;
    }
    if (_backgroundObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:_backgroundObserver];
        _backgroundObserver = nil;
    }
}

static void *watchdogThreadEntry(void *arg) {
    Watchdog *self = (__bridge Watchdog *)arg;
    [self watchdogLoop];
    return NULL;
}

- (void)watchdogLoop {
    while (true) {
        usleep(kWatchdogPollInterval);

        if (!atomic_load_explicit(&_isRunning, memory_order_relaxed)) {
            break;
        }

        if (atomic_load_explicit(&_isSuspended, memory_order_relaxed)) {
            continue;
        }
        NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - _startTime;
        if (elapsed < kWatchdogGracePeriod) {
            continue;
        }

        int32_t current = atomic_load_explicit(&_heartbeat, memory_order_relaxed);
        if (current == _lastHeartbeat) {
            _missCount++;
            if (_missCount >= kWatchdogHangThreshold) {
                [self handleEmergencyState];
                _missCount = 0;
            }
        } else {
            _missCount = 0;
        }
        _lastHeartbeat = current;
    }
}

- (void)handleEmergencyState {
    kern_return_t suspendResult = thread_suspend(_mainThreadPort);
    NSString *trace = [self captureMainThreadTrace];
    if (suspendResult == KERN_SUCCESS) {
        thread_resume(_mainThreadPort);
    }
    [self writeTrace:trace];
}

- (NSString *)captureMainThreadTrace {
    return [MachBacktracer captureMainThread];
}

- (void)writeTrace:(NSString *)trace {
    NSURL *documentsURL = [[[NSFileManager defaultManager]
        URLsForDirectory:NSDocumentDirectory
               inDomains:NSUserDomainMask] firstObject];

    NSString *documentsPath = [documentsURL path];
    
    NSString *logPath = [documentsPath
                         stringByAppendingPathComponent:@"main_hang.log"];
    int fd = open(logPath.fileSystemRepresentation,
                  O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd == -1) return;
    const char *header = "\n--- [WATCHDOG] MAIN THREAD HANG DETECTED ---\n";
    write(fd, header, strlen(header));
    const char *utf8 = trace.UTF8String;
    if (utf8) write(fd, utf8, strlen(utf8));
    close(fd);
}

@end
