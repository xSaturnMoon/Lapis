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

// Based on PojavLauncher's dyld_bypass_validation.m
// https://github.com/PojavLauncherTeam/PojavLauncher_iOS
// Original source: https://blog.xpnsec.com/restoring-dyld-memory-loading

/// Initialize the dyld library validation bypass.
/// This MUST be called before any dlopen() on unsigned dylibs (JRE, GL4ES, etc.)
/// It hooks mmap and fcntl at the kernel level using ARM64 assembly patches.
void init_bypassDyldLibValidation(void);

#endif
