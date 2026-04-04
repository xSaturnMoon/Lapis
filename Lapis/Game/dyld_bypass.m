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
#include <unistd.h>

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
    // Non modificare flags — lascia MAP_JIT intatto
    // Chiama l'originale direttamente
    return orig_mmap(addr, len, prot, flags, fd, offset);
}

static int (*orig_UIApplicationMain)(int argc, char *argv[], void *principalClassName, void *delegateClassName) = NULL;

static int my_UIApplicationMain(int argc, char *argv[], void *principalClassName, void *delegateClassName) {
    NSLog(@"[Lapis:Bypass] AVOIDED duplicate UIApplicationMain call from libjli/glfw!");
    // Block the thread forever, as the caller (OpenJDK/GLFW) expects this function to run the main GUI event loop
    // and never return. This allows the Java threads running in the background to continue executing normally.
    while (1) {
        sleep(1000);
    }
    return 0;
}

// ============================================================
// PUBLIC API
// ============================================================

void init_bypassDyldLibValidation(void) {
    static BOOL bypassed = NO;
    if (bypassed) return;
    bypassed = YES;

    NSLog(@"[Lapis:Bypass] Initializing dyld bypass via fishhook...");

    int result = rebind_symbols((struct rebinding[]){
        {"fcntl",  my_fcntl,  (void **)&orig_fcntl},
        {"mmap",   my_mmap,   (void **)&orig_mmap},
        {"UIApplicationMain", my_UIApplicationMain, (void **)&orig_UIApplicationMain},
    }, 3);

    if (result == 0) {
        NSLog(@"[Lapis:Bypass] ✅ dyld bypass initialized successfully");
    } else {
        NSLog(@"[Lapis:Bypass] ❌ fishhook rebind failed with code: %d", result);
    }
}

// Internal csops syscall
extern int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);
#define CS_DEBUGGED 0x10000000
#define CS_OPS_STATUS 0

bool LapisEngine_isJITEnabled(void) {
    // 1. Check if process is marked as debugged (AltJIT / SideStore method)
    int flags = 0;
    if (csops(getpid(), CS_OPS_STATUS, &flags, sizeof(flags)) == 0) {
        if (flags & CS_DEBUGGED) {
            return true;
        }
    }
    
    // 2. Direct memory allocation test (macOS / special entitlements)
    void *ptr = mmap(NULL, PAGE_SIZE, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_PRIVATE | MAP_ANON | MAP_JIT, -1, 0);
    if (ptr != MAP_FAILED) {
        munmap(ptr, PAGE_SIZE);
        return true;
    }
    
    return false;
}
