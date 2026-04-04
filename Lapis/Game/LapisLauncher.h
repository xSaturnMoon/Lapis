#ifndef LAPIS_LAUNCHER_H
#define LAPIS_LAUNCHER_H

#import <Foundation/Foundation.h>

/// Initialize the game engine. Must be called once at app startup.
/// Sets up the dyld bypass so dlopen can load unsigned libraries.
void LapisEngine_init(void);

/// Set the JAVA_HOME environment variable.
void LapisEngine_setJavaHome(NSString *path);

/// Set the game home directory (where .minecraft lives).
void LapisEngine_setGameHome(NSString *path);

/// Launch the JVM with the given arguments.
/// Returns 0 on success, non-zero on failure.
/// @param args NSArray of NSString arguments
int LapisEngine_launchJVM(NSArray<NSString *> *args);

/// Check if the dyld bypass was initialized successfully.
BOOL LapisEngine_isBypassReady(void);

/// Get the last error message (if any).
NSString* LapisEngine_getLastError(void);

#endif
