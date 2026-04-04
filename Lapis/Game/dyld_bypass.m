// dyld_bypass.m — Bypass iOS dyld library validation
// Adapted to use fishhook for dynamic symbol rebinding
//
// This patches mmap() and fcntl() so that dlopen() can load unsigned .dylib files on iOS.

#import "dyld_bypass.h"
#import "fishhook.h"
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <stdarg.h>
#include <sys/mman.h>

static int (*orig_fcntl)(int fd, int cmd, ...) = NULL;

static int my_fcntl(int fd, int cmd, ...) {
    va_list args;
    va_start(args, cmd);
    void *arg = va_arg(args, void *);
    va_end(args);
    
    // Bypass F_CHECK_LV (98) — Library Validation check
    if (cmd == F_CHECK_LV) {
        return 0; // Simulate success without doing the check
    }
    
    // Also bypass F_ADDFILESIGS_RETURN if needed, though fishhook handles most cases
    if (cmd == F_ADDFILESIGS_RETURN) {
        const char *homeDir = getenv("LAPIS_HOME");
        if (!homeDir) homeDir = getenv("POJAV_HOME");
        if (homeDir) {
            char filePath[PATH_MAX];
            bzero(filePath, sizeof(filePath));
            if (orig_fcntl(fd, F_GETPATH, filePath) != -1) {
                if (!strncmp(filePath, homeDir, strlen(homeDir))) {
                    // Let's assume fsignatures_t structure is passed
                    // Since we removed its definition from our header to avoid conflict,
                    // we can just cast it to an off_t pointer if we need to modify it,
                    // or better yet, since the iOS SDK defines fsignatures_t as an anonymous
                    // struct bound to fsignatures_t, we can just cast it directly.
                    // The first field is fs_file_start which is off_t.
                    off_t *fs_file_start = (off_t *)arg;
                    *fs_file_start = 0xFFFFFFFF;
                    return 0;
                }
            }
        }
    }
    
    return orig_fcntl(fd, cmd, arg);
}

static void* (*orig_mmap)(void *addr, size_t len, int prot, int flags, int fd, off_t offset) = NULL;

static void* my_mmap(void *addr, size_t len, int prot, int flags, int fd, off_t offset) {
    // Remove MAP_JIT restriction if present (MAP_JIT = 0x0800 on macOS/iOS)
    flags &= ~0x800;
    
    void *map = orig_mmap(addr, len, prot, flags, fd, offset);
    if (map == MAP_FAILED && fd && (prot & PROT_EXEC)) {
        // Workaround: map RW, copy, then mprotect to desired prot
        map = orig_mmap(addr, len, PROT_READ | PROT_WRITE,
                        flags | MAP_PRIVATE | MAP_ANON, 0, 0);
        void *tmp = orig_mmap(NULL, len, PROT_READ, MAP_PRIVATE, fd, offset);
        if (map != MAP_FAILED && tmp != MAP_FAILED) {
            memcpy(map, tmp, len);
            munmap(tmp, len); // munmap uses the original unless we hooked it too
            mprotect(map, len, prot);
        }
    }
    return map;
}

// ============================================================
// PUBLIC API
// ============================================================

void init_bypassDyldLibValidation(void) {
    static BOOL bypassed = NO;
    if (bypassed) return;
    bypassed = YES;

    NSLog(@"[Lapis:Bypass] Initializing dyld bypass via fishhook...");

    rebind_symbols((struct rebinding[]){
        {"fcntl", my_fcntl, (void **)&orig_fcntl},
        {"mmap",  my_mmap,  (void **)&orig_mmap},
    }, 2);

    NSLog(@"[Lapis:Bypass] dyld bypass initialized successfully");
}
