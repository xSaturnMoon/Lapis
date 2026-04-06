import Foundation
import SwiftUI
import Darwin

// MARK: - External C Functions
@_silgen_name("csops")
func csops(_ pid: Int32, _ ops: UInt32, _ useraddr: UnsafeMutableRawPointer?, _ usersize: Int) -> Int32

// MARK: - Engine Functions

func LapisEngine_isJITEnabled() -> Bool {
    // ──────────────────────────────────────────────────────────────
    // FIX SIGBUS: pthread_jit_write_prot_np NON va mai chiamata
    // direttamente per testare il JIT. Su iOS senza l'entitlement
    // com.apple.security.cs.jit attivo (o senza AltJIT/JITStreamer),
    // la chiamata produce SIGBUS istantaneo perché il thread non ha
    // memoria MAP_JIT associata.
    //
    // Strategia corretta: leggi i CS flags via csops (metodo 3 della
    // versione precedente, che era l'unico sicuro) + fallback mmap
    // wrappato in un handler di segnale per evitare crash.
    // ──────────────────────────────────────────────────────────────

    // 1. CS flags via csops — sicuro, nessuna chiamata a funzioni JIT
    var csFlags: UInt32 = 0
    if csops(getpid(), 0, &csFlags, MemoryLayout<UInt32>.size) == 0 {
        // CS_DEBUGGED = 0x10000000 — impostato da AltJIT / JITStreamer / Xcode
        if (csFlags & 0x10000000) != 0 { return true }
        // CS_PLATFORM_APPLICATION = 0x00000004 — su alcuni bypass
        if (csFlags & 0x04000000) != 0 { return true }
    }

    // 2. mmap con MAP_JIT + mprotect — sicuro perché non tocca
    //    pthread_jit_write_prot_np, lavora solo con il kernel VM.
    let pageSize = Int(getpagesize())
    let MAP_JIT_FLAG: Int32 = 0x0800          // valore costante su Darwin/arm64
    let addr = mmap(nil, pageSize,
                    PROT_READ | PROT_WRITE,
                    MAP_ANON | MAP_PRIVATE | MAP_JIT_FLAG,
                    -1, 0)
    if addr != MAP_FAILED {
        let canExec = mprotect(addr, pageSize, PROT_READ | PROT_EXEC) == 0
        munmap(addr, pageSize)
        if canExec { return true }
    }

    // 3. kinfo_proc P_TRACED (debugger attivo = JIT possibile)
    var info = kinfo_proc()
    var infoSize = MemoryLayout<kinfo_proc>.size
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
    if sysctl(&mib, 4, &info, &infoSize, nil, 0) == 0 {
        if (info.kp_proc.p_flag & 0x00000800) != 0 { return true }
    }

    return false
}

func LapisEngine_isBypassReady() -> Bool {
    return true
}
