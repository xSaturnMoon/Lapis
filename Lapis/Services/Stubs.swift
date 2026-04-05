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
    // Try to map a page with MAP_JIT to see if we have the JIT entitlement
    let size = Int(getpagesize())
    let address = mmap(nil, size, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_ANON | MAP_PRIVATE | MAP_JIT, -1, 0)
    
    if address != MAP_FAILED {
        munmap(address, size)
        return true
    }
    
    // Fallback: check if we are being debugged (which also enables JIT usually)
    var info = kinfo_proc()
    var info_size = MemoryLayout<kinfo_proc>.size
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
    
    if sysctl(&mib, 4, &info, &info_size, nil, 0) == 0 {
        // P_TRACED is 0x00000800
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
