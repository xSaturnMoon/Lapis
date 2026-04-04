#pragma once
#include <Foundation/Foundation.h>
typedef int JLI_Launch_func(int argc, const char ** argv,
        int jargc, const char** jargv,
        int appclassc, const char** appclassv,
        const char* fullversion,
        const char* dotversion,
        const char* pname,
        const char* lname,
        signed char javaargs,
        signed char cpwildcard,
        signed char javaw,
        int ergo
);

extern JLI_Launch_func *pJLI_Launch;

int launchJVM(int argc, const char **argv, const char *jli_path);
