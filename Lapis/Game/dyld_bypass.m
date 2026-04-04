// dyld_bypass.m — Bypass iOS dyld library validation
// Based on PojavLauncher's dyld_bypass_validation.m
// Original: https://blog.xpnsec.com/restoring-dyld-memory-loading
// https://github.com/xpn/DyldDeNeuralyzer/blob/main/DyldDeNeuralyzer/DyldPatch/dyldpatch.m
//
// This file patches mmap() and fcntl() at the kernel level using ARM64
// assembly so that dlopen() can load unsigned .dylib files (JRE, GL4ES, etc.)
// Without this, iOS will SIGKILL the process when loading any non-Apple dylib.

#import "dyld_bypass.h"
#import <Foundation/Foundation.h>
#include <mach/mach.h>
#include <mach-o/dyld_images.h>
#include <sys/mman.h>
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <string.h>
#include <stdarg.h>
#include <unistd.h>

#define ASM(...) __asm__(#__VA_ARGS__)

// ldr x8, value; br x8; value: .ascii "\x41\x42\x43\x44\x45\x46\x47\x48"
static char patch[] = {
    0x88,0x00,0x00,0x58,
    0x00,0x01,0x1f,0xd6,
    0x1f,0x20,0x03,0xd5,
    0x1f,0x20,0x03,0xd5,
    0x41,0x41,0x41,0x41,
    0x41,0x41,0x41,0x41
};

// Signatures to search for in dyld
static char mmapSig[] = {0xB0, 0x18, 0x80, 0xD2, 0x01, 0x10, 0x00, 0xD4};
static char fcntlSig[] = {0x90, 0x0B, 0x80, 0xD2, 0x01, 0x10, 0x00, 0xD4};

// External private symbols from libsystem_kernel
extern void* __mmap(void *addr, size_t len, int prot, int flags, int fd, off_t offset);
extern int __fcntl(int fildes, int cmd, void* param);

// Since we're patching libsystem_kernel, we must avoid calling to its functions
static void builtin_memcpy(char *target, char *source, size_t size) {
    for (int i = 0; i < size; i++) {
        target[i] = source[i];
    }
}

// Direct syscall for vm_protect — avoids calling patched libsystem_kernel
kern_return_t builtin_vm_protect(mach_port_name_t task, mach_vm_address_t address,
                                  mach_vm_size_t size, boolean_t set_max, vm_prot_t new_prot);
ASM(_builtin_vm_protect: \n
    mov x16, #-0xe       \n
    svc #0x80            \n
    ret
);

static bool redirectFunction(const char *name, void *patchAddr, void *target) {
    kern_return_t kret = builtin_vm_protect(
        mach_task_self(), (vm_address_t)patchAddr, sizeof(patch),
        false, PROT_READ | PROT_WRITE | VM_PROT_COPY
    );
    if (kret != KERN_SUCCESS) {
        NSLog(@"[Lapis:DyldBypass] vm_protect(RW) failed for %s: %d", name, kret);
        return false;
    }

    builtin_memcpy((char *)patchAddr, patch, sizeof(patch));
    *(void **)((char*)patchAddr + 16) = target;

    kret = builtin_vm_protect(
        mach_task_self(), (vm_address_t)patchAddr, sizeof(patch),
        false, PROT_READ | PROT_EXEC
    );
    if (kret != KERN_SUCCESS) {
        NSLog(@"[Lapis:DyldBypass] vm_protect(RX) failed for %s: %d", name, kret);
        return false;
    }

    NSLog(@"[Lapis:DyldBypass] Hooked %s successfully", name);
    return true;
}

static bool searchAndPatch(const char *name, char *base, char *signature, int length, void *target) {
    char *patchAddr = NULL;

    for (int i = 0; i < 0x100000; i++) {
        if (base[i] == signature[0] && memcmp(base+i, signature, length) == 0) {
            patchAddr = base + i;
            break;
        }
    }

    if (patchAddr == NULL) {
        NSLog(@"[Lapis:DyldBypass] Could not find %s signature", name);
        return false;
    }

    NSLog(@"[Lapis:DyldBypass] Found %s at %p", name, patchAddr);
    return redirectFunction(name, patchAddr, target);
}

static void *getDyldBase(void) {
    struct task_dyld_info dyld_info;
    mach_msg_type_number_t count = TASK_DYLD_INFO_COUNT;

    kern_return_t ret = task_info(
        mach_task_self_,
        TASK_DYLD_INFO,
        (task_info_t)&dyld_info,
        &count
    );

    if (ret != KERN_SUCCESS) {
        NSLog(@"[Lapis:DyldBypass] task_info failed: %d", ret);
        return NULL;
    }

    struct dyld_all_image_infos *infos =
        (struct dyld_all_image_infos *)dyld_info.all_image_info_addr;
    return (void *)infos->dyldImageLoadAddress;
}

// Hooked mmap: bypass code signing for file-backed executable mappings
static void* hooked_mmap(void *addr, size_t len, int prot, int flags, int fd, off_t offset) {
    // Reject MAP_JIT to avoid legacy codepath issues
    if (flags & MAP_JIT) {
        errno = EINVAL;
        return MAP_FAILED;
    }

    void *map = __mmap(addr, len, prot, flags, fd, offset);
    if (map == MAP_FAILED && fd && (prot & PROT_EXEC)) {
        // File-backed executable mapping failed (code signing)
        // Workaround: map as RW, copy content, then mprotect to desired protection
        map = __mmap(addr, len, PROT_READ | PROT_WRITE, flags | MAP_PRIVATE | MAP_ANON, 0, 0);
        void *memoryLoadedFile = __mmap(NULL, len, PROT_READ, MAP_PRIVATE, fd, offset);
        memcpy(map, memoryLoadedFile, len);
        munmap(memoryLoadedFile, len);
        mprotect(map, len, prot);
    }
    return map;
}

// Hooked fcntl: bypass F_ADDFILESIGS_RETURN and F_CHECK_LV
static int hooked___fcntl(int fildes, int cmd, void *param) {
    if (cmd == F_ADDFILESIGS_RETURN) {
        const char *homeDir = getenv("LAPIS_HOME");
        if (!homeDir) homeDir = getenv("POJAV_HOME");
        if (homeDir) {
            char filePath[PATH_MAX];
            bzero(filePath, sizeof(filePath));
            if (__fcntl(fildes, F_GETPATH, filePath) != -1) {
                if (!strncmp(filePath, homeDir, strlen(homeDir))) {
                    fsignatures_t *fsig = (fsignatures_t*)param;
                    fsig->fs_file_start = 0xFFFFFFFF;
                    return 0;
                }
            }
        }
    }
    else if (cmd == F_CHECK_LV) {
        // Library validation check — always pass
        return 0;
    }
    return __fcntl(fildes, cmd, param);
}

static int hooked_fcntl(int fildes, int cmd, ...) {
    va_list ap;
    va_start(ap, cmd);
    void *param = va_arg(ap, void *);
    va_end(ap);
    return hooked___fcntl(fildes, cmd, param);
}

// ============================================================
// PUBLIC API
// ============================================================

void init_bypassDyldLibValidation(void) {
    static BOOL bypassed = NO;
    if (bypassed) return;
    bypassed = YES;

    NSLog(@"[Lapis:DyldBypass] Initializing dyld library validation bypass...");

    // Modifying exec pages during execution may cause SIGBUS, so ignore it now
    // Before calling JLI_Launch, this will be set back to SIG_DFL
    signal(SIGBUS, SIG_IGN);

    char *dyldBase = getDyldBase();
    if (!dyldBase) {
        NSLog(@"[Lapis:DyldBypass] ERROR: Could not find dyld base address!");
        return;
    }

    redirectFunction("mmap", mmap, hooked_mmap);
    redirectFunction("fcntl", fcntl, hooked_fcntl);
    searchAndPatch("dyld_mmap", dyldBase, mmapSig, sizeof(mmapSig), hooked_mmap);
    searchAndPatch("dyld_fcntl", dyldBase, fcntlSig, sizeof(fcntlSig), hooked___fcntl);

    NSLog(@"[Lapis:DyldBypass] Bypass initialized successfully!");
}
