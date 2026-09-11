//
//  HookNSBundle.m
//  MeloNX
//
//  Created by Stossy11 on 24/10/2025.
//

#import "MeloNX-Swift.h"

__attribute__((constructor))
void EarlyInitConstructor(void) {
    
    [EarlyInit entryPoint];
}
