#include <dirent.h>
#include <dlfcn.h>
#include <errno.h>
#include <libgen.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include "utils.h"

#import "ios_uikit_bridge.h"
#import "JavaLauncher.h"

#define fm NSFileManager.defaultManager

extern char **environ;

BOOL validateVirtualMemorySpace(size_t size) {
    size <<= 20; // convert to MB
    void *map = mmap(0, size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if(map == MAP_FAILED || munmap(map, size) != 0)
        return NO;
    return YES;
}

void init_loadDefaultEnv() {
    // Override OpenGL version to 4.1 for Zink
    setenv("MESA_GL_VERSION_OVERRIDE", "4.1", 1);
    // Runs JVM in a separate thread
    setenv("HACK_IGNORE_START_ON_FIRST_THREAD", "1", 1);
}

int LapisEngine_launchJVM(NSArray<NSString *> *args) {
    NSLog(@"[LapisEngine] Beginning JVM launch");

    init_loadDefaultEnv();

    BOOL requiresTXMWorkaround = DeviceHasJITFlags(JIT_FLAG_FORCE_MIRRORED | JIT_FLAG_HAS_TXM);
    if (requiresTXMWorkaround) {
        static void *result;
        if(!result) result = JIT26CreateRegionLegacy(getpagesize());
        if ((uint32_t)result != 0x690000E0) {
            munmap(result, getpagesize());
            NSLog(@"[LapisEngine] FATAL: Universal JIT26 script required but legacy detected!");
            return 1;
        }
        JIT26SendJITScript([NSString stringWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"UniversalJIT26Extension" ofType:@"js"]]);
        JIT26SetDetachAfterFirstBr(YES); // Default to YES since we don't have always attached toggle
        // make sure we don't get stuck in EXC_BAD_ACCESS
        task_set_exception_ports(mach_task_self(), EXC_MASK_BAD_ACCESS, 0, EXCEPTION_DEFAULT, MACHINE_THREAD_STATE);
    }
    
    if (!requiresTXMWorkaround) {
        // Activate Library Validation bypass
        init_bypassDyldLibValidation();
    } else {
        NSLog(@"[DyldLVBypass] Hook disabled! Loading unsigned dylib will cause code signature error.");
    }

    NSString *internalJLI = @(getenv("INTERNAL_JLI_PATH"));
    NSLog(@"[LapisEngine] Loading JLI from: %@", internalJLI);
    void* libjli = dlopen(internalJLI.UTF8String, RTLD_GLOBAL);

    if (!libjli) {
        const char *error = dlerror();
        NSLog(@"[LapisEngine] FATAL: JLI lib dlopen failed: %s", error);
        return 1;
    }

    int margc = args.count;
    const char **margv = malloc((margc + 1) * sizeof(char *));
    for (int i = 0; i < margc; i++) {
        margv[i] = strdup([args[i] UTF8String]);
    }
    margv[margc] = NULL;

    pJLI_Launch = (JLI_Launch_func *)dlsym(libjli, "JLI_Launch");

    if (NULL == pJLI_Launch) {
        NSLog(@"[LapisEngine] FATAL: JLI_Launch = NULL");
        return -2;
    }

    NSLog(@"[LapisEngine] Calling JLI_Launch");

    // Reset signal handler so that JVM can catch them
    signal(SIGSEGV, SIG_DFL);
    signal(SIGPIPE, SIG_DFL);
    signal(SIGBUS, SIG_DFL);
    signal(SIGILL, SIG_DFL);
    signal(SIGFPE, SIG_DFL);

    return pJLI_Launch(margc, margv,
                   0, NULL, 
                   0, NULL,
                   "1.8.0-internal",
                   "1.8",
                   "java", "openjdk",
                   JNI_FALSE, JNI_TRUE, JNI_FALSE, JNI_TRUE);
}
