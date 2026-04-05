import Foundation
import SwiftUI
import Darwin

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
    // 1. Try Apple's official JIT write protection toggle (iOS 14.2+)
    // This is the most reliable way to check if the entitlement is actually working
    if #available(iOS 14.2, *) {
        // If we can toggle JIT write protection without crashing, JIT is available
        pthread_jit_write_prot_np(1)
        pthread_jit_write_prot_np(0)
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
    
    // 3. Last fallback: check for debugger/ptrace flag
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
