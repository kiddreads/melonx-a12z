//
//  MachBacktracer.m
//  MeloNX
//
//  Created by Stossy11 on 29/1/2026.
//


#import "MachBacktracer.h"
#import <mach/mach.h>
#import <pthread.h>

#import <mach/mach.h>
#import <pthread.h>
#import <dlfcn.h>

@implementation MachBacktracer

static thread_t g_main_thread_port = 0;

+ (void)initialize {
    if (self == [MachBacktracer class]) {
        g_main_thread_port = mach_thread_self();
    }
}

+ (NSString *)captureMainThread {
    if (g_main_thread_port == 0) return @"Error: Port not initialized";

    char report[4096];
    int offset = 0;
    
    thread_suspend(g_main_thread_port);

#if defined(__arm64__)
    arm_thread_state64_t state;
    mach_msg_type_number_t count = ARM_THREAD_STATE64_COUNT;

    if (thread_get_state(g_main_thread_port, ARM_THREAD_STATE64, (thread_state_t)&state, &count) == KERN_SUCCESS) {
        
        uintptr_t fp = (uintptr_t)state.__fp;
        uintptr_t pc = (uintptr_t)state.__pc;

        offset += snprintf(report + offset, sizeof(report) - offset, "PC: 0x%lx\n", pc);

        for (int i = 0; i < 30 && fp != 0; i++) {
            uintptr_t frame[2]; // [0] = next FP, [1] = return address
            mach_msg_type_number_t size = sizeof(frame);
            
            // Safely read memory without crashing if the pointer is garbage
            kern_return_t kr = vm_read_overwrite(mach_task_self(), (mach_vm_address_t)fp, size, (mach_vm_address_t)frame, (mach_vm_size_t *)&size);
            
            if (kr != KERN_SUCCESS) break;

            uintptr_t nextFP = frame[0];
            uintptr_t returnAddr = frame[1];

            if (returnAddr == 0) break;

            offset += snprintf(report + offset, sizeof(report) - offset, "[%02d] 0x%lx\n", i, returnAddr);
            
            // Basic sanity check to prevent infinite loops on circular stacks
            if (nextFP <= fp) break;
            fp = nextFP;
        }
    }
#endif

    thread_resume(g_main_thread_port);
    
    return [NSString stringWithUTF8String:report];
}

@end
