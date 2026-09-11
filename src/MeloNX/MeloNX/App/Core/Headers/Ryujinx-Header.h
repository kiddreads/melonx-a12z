//
//  Ryujinx-Header.h
//  MeloNX
//
//  Created by Stossy11 on 3/11/2024.
//

#define DRM 0
#define CS_DEBUGGED 0x10000000

#ifndef RyujinxHeader
#define RyujinxHeader


#include <SDL2/SDL.h>
#include <SDL2/SDL_syswm.h>
#include "MobileGestalt.h"
#include "HookNSBundle.h"



#ifdef __cplusplus
extern "C" {
#endif


struct GameInfo {
    long FileSize;
    char TitleName[512];
    char TitleId[32];
    char Developer[256];
    char Version[16];
    unsigned char* ImageData;
    unsigned int ImageSize;
};

struct DlcNcaListItem {
    char Path[256];
    unsigned long TitleId;
};

struct DlcNcaList {
    bool success;
    unsigned int size;
    struct DlcNcaListItem* items;
};

struct AvatarInfo
{
    unsigned char* ImageData;
    int ImageSize;
    char* FileName;
};

struct AvatarArray
{
    int Count;
    struct AvatarInfo* Avatars;
};

typedef void (^SwiftCallback)(NSString *result);
typedef void (^SwiftCallback2)(NSData *result);

void RegisterCallback(NSString *identifier, SwiftCallback callback);
void RegisterCallbackWithData(NSString *identifier, SwiftCallback2 callback);

__attribute__((noinline,optnone,naked))
void BreakSendJITScript(char* script, size_t len) {
    asm("mov x16, #2 \n"
        "brk #0xf00d \n"
        "ret");
}

__attribute__((noinline,optnone,naked))
bool BreakTestJITScript() {
    asm("mov x16, #3 \n"
        "brk #0xf00d \n"
        "ret");
}

#ifdef __cplusplus
}
#endif

#endif /* RyujinxSDL_h */

