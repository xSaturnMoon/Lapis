import Foundation
import SwiftUI
import Darwin

// MARK: - External C Functions
@_silgen_name("csops")
func csops(_ pid: Int32, _ ops: UInt32, _ useraddr: UnsafeMutableRawPointer?, _ usersize: Int) -> Int32

// MARK: - Game Launcher Stub
class GameLauncher {
    static let shared = GameLauncher()
    
    struct LaunchConfig {
        let versionId: String
        let loader: ModLoader
        let inputMode: InputMode
        let playerName: String
        let playerUUID: String
        let accessToken: String
    }
    
    func initEngine() {
        print("Stub: Engine initialized")
    }
    
    func launch(config: LaunchConfig, completion: @escaping (String?) -> Void) {
        print("Stub: Launching \(config.versionId)")
        
        // Mock a launching delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            completion(nil) // Success
        }
    }
}

// MARK: - Engine Functions Stubs
func LapisEngine_isJITEnabled() -> Bool {
    // 1. Try to dynamically find and use pthread_jit_write_prot_np (iOS 14.2+)
    typealias JITWriteProtFunc = @convention(c) (Int32) -> Void
    let RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: -2)
    if let sym = dlsym(RTLD_DEFAULT, "pthread_jit_write_prot_np") {
        let f = unsafeBitCast(sym, to: JITWriteProtFunc.self)
        // If we can call it without crashing, we have JIT
        f(1)
        f(0)
        return true
    }

    // 2. Fallback: Standard mmap with MAP_JIT
    let size = Int(getpagesize())
    let address = mmap(nil, size, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE | MAP_JIT, -1, 0)
    
    if address != MAP_FAILED {
        // Try to transition to EXEC to confirm JIT capability
        let res = mprotect(address, size, PROT_READ | PROT_EXEC)
        munmap(address, size)
        if res == 0 { return true }
    }
    
    // 3. Try to check for CS_DEBUGGED flag using csops (standard for many JIT enablers)
    var cs_flags: UInt32 = 0
    // CS_OPS_STATUS = 0
    if csops(getpid(), 0, &cs_flags, MemoryLayout<UInt32>.size) == 0 {
        // CS_DEBUGGED = 0x10000000
        if (cs_flags & 0x10000000) != 0 {
            return true
        }
    }

    // 4. Last fallback: check for debugger/ptrace flag via sysctl
    var info = kinfo_proc()
    var info_size = MemoryLayout<kinfo_proc>.size
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
    
    if sysctl(&mib, 4, &info, &info_size, nil, 0) == 0 {
        // P_TRACED = 0x00000800
        return (info.kp_proc.p_flag & 0x00000800) != 0
    }
    
    return false
}

func LapisEngine_isBypassReady() -> Bool {
    // For the stub, the engine is always "ready" to show the UI in its active state
    return true
}

// MARK: - Input Mode Stub (if missing)
// This is already defined in InputModeView.swift probably, but let's check
// HomeView uses InputMode, let's make sure it's available.
// It seems it's defined in InputModeView.swift.
