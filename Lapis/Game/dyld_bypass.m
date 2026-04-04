// dyld_bypass.m — Bypass iOS dyld library validation
// Based on PojavLauncher's dyld_bypass_validation.m
// Original: https://blog.xpnsec.com/restoring-dyld-memory-loading
//
// This patches mmap() and fcntl() at the kernel level using ARM64
// assembly so that dlopen() can load unsigned .dylib files on iOS.

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

// ARM64 trampoline: ldr x8, value; br x8; value: <8-byte target address>
static char patch[] = {
    0x88, 0x00, 0x00, 0x58,  // ldr x8, #16
    0x00, 0x01, 0x1f, 0xd6,  // br x8
    0x1f, 0x20, 0x03, 0xd5,  // nop
    0x1f, 0x20, 0x03, 0xd5,  // nop
    0x41, 0x41, 0x41, 0x41,  // target address (low)
    0x41, 0x41, 0x41, 0x41   // target address (high)
};

// Byte signatures for mmap and fcntl syscalls in libsystem_kernel
static char mmapSig[] = {0xB0, 0x18, 0x80, 0xD2, 0x01, 0x10, 0x00, 0xD4};
static char fcntlSig[] = {0x90, 0x0B, 0x80, 0xD2, 0x01, 0x10, 0x00, 0xD4};

// Private kernel symbols (from libsystem_kernel)
extern void* __mmap(void *addr, size_t len, int prot, int flags, int fd, off_t offset);
extern int __fcntl(int fildes, int cmd, void* param);

// Custom memcpy that doesn't use libsystem_kernel (since we're patching it)
static void safe_memcpy(char *target, char *source, size_t size) {
    for (size_t i = 0; i < size; i++) {
        target[i] = source[i];
    }
}

// Direct syscall for vm_protect — bypasses libsystem_kernel entirely
// This is ARM64 assembly: mov x16, #-14; svc #0x80; ret
// Syscall -14 = _kernelrpc_mach_vm_protect_trap
__attribute__((naked))
static kern_return_t direct_vm_protect(mach_port_name_t task __attribute__((unused)),
                                        mach_vm_address_t address __attribute__((unused)),
                                        mach_vm_size_t size __attribute__((unused)),
                                        boolean_t set_max __attribute__((unused)),
                                        vm_prot_t new_prot __attribute__((unused))) {
    __asm__ volatile(
        "mov x16, #-0xe\n"
        "svc #0x80\n"
        "ret\n"
    );
}

static bool redirectFunction(const char *name, void *patchAddr, void *target) {
    kern_return_t kret = direct_vm_protect(
        mach_task_self(), (mach_vm_address_t)patchAddr, sizeof(patch),
        false, PROT_READ | PROT_WRITE | VM_PROT_COPY
    );
    if (kret != KERN_SUCCESS) {
        NSLog(@"[Lapis:DyldBypass] vm_protect(RW) failed for %s: %d", name, kret);
        return false;
    }

    safe_memcpy((char *)patchAddr, patch, sizeof(patch));
    *(void **)((char *)patchAddr + 16) = target;

    kret = direct_vm_protect(
        mach_task_self(), (mach_vm_address_t)patchAddr, sizeof(patch),
        false, PROT_READ | PROT_EXEC
    );
    if (kret != KERN_SUCCESS) {
        NSLog(@"[Lapis:DyldBypass] vm_protect(RX) failed for %s: %d", name, kret);
        return false;
    }

    NSLog(@"[Lapis:DyldBypass] Hooked %s OK", name);
    return true;
}

static bool searchAndPatch(const char *name, char *base, char *signature, int length, void *target) {
    char *patchAddr = NULL;

    for (int i = 0; i < 0x100000; i++) {
        if (base[i] == signature[0] && memcmp(base + i, signature, length) == 0) {
            patchAddr = base + i;
            break;
        }
    }

    if (patchAddr == NULL) {
        NSLog(@"[Lapis:DyldBypass] Signature not found: %s", name);
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

// Hooked mmap — bypasses code signing for file-backed executable mappings
static void *hooked_mmap(void *addr, size_t len, int prot, int flags, int fd, off_t offset) {
    if (flags & MAP_JIT) {
        errno = EINVAL;
        return MAP_FAILED;
    }

    void *map = __mmap(addr, len, prot, flags, fd, offset);
    if (map == MAP_FAILED && fd && (prot & PROT_EXEC)) {
        // Workaround: map RW, copy, then mprotect to desired prot
        map = __mmap(addr, len, PROT_READ | PROT_WRITE,
                     flags | MAP_PRIVATE | MAP_ANON, 0, 0);
        void *tmp = __mmap(NULL, len, PROT_READ, MAP_PRIVATE, fd, offset);
        if (map != MAP_FAILED && tmp != MAP_FAILED) {
            memcpy(map, tmp, len);
            munmap(tmp, len);
            mprotect(map, len, prot);
        }
    }
    return map;
}

// Hooked fcntl — bypasses library validation checks
static int hooked___fcntl(int fildes, int cmd, void *param) {
    if (cmd == F_ADDFILESIGS_RETURN) {
        const char *homeDir = getenv("LAPIS_HOME");
        if (!homeDir) homeDir = getenv("POJAV_HOME");
        if (homeDir) {
            char filePath[PATH_MAX];
            bzero(filePath, sizeof(filePath));
            if (__fcntl(fildes, F_GETPATH, filePath) != -1) {
                if (!strncmp(filePath, homeDir, strlen(homeDir))) {
                    fsignatures_t *fsig = (fsignatures_t *)param;
                    fsig->fs_file_start = 0xFFFFFFFF;
                    return 0;
                }
            }
        }
    } else if (cmd == F_CHECK_LV) {
        return 0;  // Always pass library validation
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

    NSLog(@"[Lapis:DyldBypass] Initializing...");

    // Ignore SIGBUS while patching exec pages
    signal(SIGBUS, SIG_IGN);

    char *dyldBase = getDyldBase();
    if (!dyldBase) {
        NSLog(@"[Lapis:DyldBypass] ERROR: Could not find dyld base!");
        return;
    }

    NSLog(@"[Lapis:DyldBypass] dyld base: %p", dyldBase);

    redirectFunction("mmap", mmap, hooked_mmap);
    redirectFunction("fcntl", fcntl, hooked_fcntl);
    searchAndPatch("dyld_mmap", dyldBase, mmapSig, sizeof(mmapSig), hooked_mmap);
    searchAndPatch("dyld_fcntl", dyldBase, fcntlSig, sizeof(fcntlSig), hooked___fcntl);

    NSLog(@"[Lapis:DyldBypass] Bypass active!");
}
