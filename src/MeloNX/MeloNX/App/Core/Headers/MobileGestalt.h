//
//  MobileGestalt.h
//  MeloNX
//
//  Created by Stossy11 on 11/07/2025.
//

/*
 * libMobileGestalt header.
 * Mobile gestalt functions as a QA system. You ask it a question, and it gives you the answer! :)
 *
 * Copyright (c) 2013-2014 Cykey (David Murray)
 * Improved by @PoomSmart (2020)
 * All rights reserved.
 */

#ifndef LIBMOBILEGESTALT_H_
#define LIBMOBILEGESTALT_H_

#include <dlfcn.h>
#include <CoreFoundation/CoreFoundation.h>

#if __cplusplus
extern "C" {
#endif

#pragma mark - API

typedef CFPropertyListRef (*MGFuncType)(CFStringRef);

CFPropertyListRef CallMGCopyAnswer(CFStringRef key) {
    static MGFuncType fn = NULL;
    if (!fn) {
        void *handle = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
        if (!handle) return NULL;
        
        char decoded[] = { 'M','G','C','o','p','y','A','n','s','w','e','r', '\0' };
        fn = (MGFuncType)dlsym(handle, decoded);
    }
    
    return fn ? fn(key) : NULL;
}

#pragma mark - Device Information

static const CFStringRef kMGPhysicalHardwareNameString = CFSTR("PhysicalHardwareNameString");

#if __cplusplus
}
#endif

#endif /* LIBMOBILEGESTALT_H_ */
