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

#import "ios_uikit_bridge.h"
#import "JavaLauncher.h"
#import "dyld_bypass.h"

JLI_Launch_func *pJLI_Launch;

int launchJVM(int argc, const char **argv, const char *jli_path) {
    NSLog(@"[JavaLauncher] Beginning JVM launch (Amethyst Core)");

    // Activate Library Validation bypass and hooks
    init_bypassDyldLibValidation();
    // Assuming main_hook initialization:
    extern void init_hookFunctions(void);
    init_hookFunctions();

    // Disable overloaded functions hack for Minecraft 1.17+
    setenv("LIBGL_NOINTOVLHACK", "1", 1);
    // Runs JVM in a separate thread
    setenv("HACK_IGNORE_START_ON_FIRST_THREAD", "1", 1);

    // Load java JLI
    setenv("INTERNAL_JLI_PATH", jli_path, 1);
    void* libjli = dlopen(jli_path, RTLD_GLOBAL);

    if (!libjli) {
        const char *error = dlerror();
        NSLog(@"[Init] JLI lib = NULL: %s", error);
        showDialog(@"Error", [NSString stringWithFormat:@"%s", error]);
        return 1;
    }

    pJLI_Launch = (JLI_Launch_func *)dlsym(libjli, "JLI_Launch");

    if (NULL == pJLI_Launch) {
        NSLog(@"[Init] JLI_Launch = NULL");
        return -2;
    }

    NSLog(@"[Init] Calling JLI_Launch");

    // Reset signal handler so that JVM can catch them
    signal(SIGSEGV, SIG_DFL);
    signal(SIGPIPE, SIG_DFL);
    signal(SIGBUS, SIG_DFL);
    signal(SIGILL, SIG_DFL);
    signal(SIGFPE, SIG_DFL);

    return pJLI_Launch(argc, argv,
                   0, NULL, 
                   0, NULL, 
                   "1.8.0-internal",
                   "1.8",
                   "java", "openjdk",
                   0, 1, 0, 1);
}
