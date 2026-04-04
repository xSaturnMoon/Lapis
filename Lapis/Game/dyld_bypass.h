#ifndef DYLD_BYPASS_H
#define DYLD_BYPASS_H

#import <Foundation/Foundation.h>
#include <mach/mach.h>
#include <mach-o/dyld_images.h>
#include <sys/mman.h>
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>

// Private kernel definitions not in public SDK headers
#ifndef F_ADDFILESIGS_RETURN
#define F_ADDFILESIGS_RETURN 97
#endif

#ifndef F_CHECK_LV
#define F_CHECK_LV 98
#endif

// fsignatures_t from kernel headers
#ifndef _FSIGNATURES_T
#define _FSIGNATURES_T
typedef struct {
    off_t       fs_file_start;
    void        *fs_blob_start;
    size_t      fs_blob_size;
} fsignatures_t;
#endif

// Inline assembly macro for ARM64
#define LAPIS_ASM(...) __asm__(#__VA_ARGS__)

/// Initialize the dyld library validation bypass.
/// This MUST be called before any dlopen() on unsigned dylibs.
void init_bypassDyldLibValidation(void);

#endif
