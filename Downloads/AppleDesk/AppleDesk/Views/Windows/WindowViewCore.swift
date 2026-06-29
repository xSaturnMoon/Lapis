import SwiftUI

// MARK: - Resize Handle
struct ResizeHandle: View {
    let cursor: String
    let onDrag: (CGFloat, CGFloat) -> Void
    let onEnd: () -> Void
    @State private var startW: CGFloat = 0
    @State private var startH: CGFloat = 0
    @State private var startPos: CGPoint = .zero

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { v in onDrag(v.translation.width, v.translation.height) }
                    .onEnded { _ in onEnd() }
            )
    }
}

// MARK: - Window View
struct WindowView: View {
    let window: DesktopWindow
    let screenSize: CGSize
    @EnvironmentObject var desktopVM: DesktopViewModel

    @State private var position: CGPoint
    @State private var size: CGSize
    @State private var isMaximized: Bool
    @State private var dragOrigin: CGPoint = .zero
    @State private var isDragging = false
    @State private var appear = false
    @State private var preMaxSize: CGSize = .zero
    @State private var preMaxPosition: CGPoint = .zero

    // Resize state
    @State private var resizeStartSize: CGSize = .zero
    @State private var resizeStartPos: CGPoint = .zero
    @State private var isResizing = false

    init(window: DesktopWindow, screenSize: CGSize) {
        self.window = window
        self.screenSize = screenSize
        _position = State(initialValue: window.position)
        _size = State(initialValue: window.size)
        _isMaximized = State(initialValue: window.isMaximized)
    }

    var body: some View {
        let isActive = desktopVM.activeWindowID == window.id
        let minW: CGFloat = 320
        let minH: CGFloat = 220

        VStack(spacing: 0) {
            WindowTitleBar(
                title: window.title, icon: window.icon, iconAsset: window.iconAsset,
                isActive: isActive, isMaximized: isMaximized,
                onClose: { desktopVM.closeWindow(window.id) },
                onMinimize: { withAnimation(.spring(duration: 0.35, bounce: 0.1)) { desktopVM.minimizeWindow(window.id) } },
                onMaximize: { toggleMaximize() }
            )
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        guard !isMaximized else { return }
                        if !isDragging {
                            isDragging = true
                            dragOrigin = CGPoint(x: position.x - value.startLocation.x,
                                                y: position.y - value.startLocation.y)
                            desktopVM.bringToFront(window.id)
                        }
                        position = CGPoint(x: value.location.x + dragOrigin.x,
                                          y: value.location.y + dragOrigin.y)

                        // Snap zone detection
                        let loc = value.location
                        let t: CGFloat = 72
                        let inL = loc.x < t; let inR = loc.x > screenSize.width - t
                        let inT = loc.y < t; let inB = loc.y > screenSize.height - t

                        let newSnap: SnapZone?
                        if inT && inL      { newSnap = .topLeft }
                        else if inT && inR { newSnap = .topRight }
                        else if inB && inL { newSnap = .bottomLeft }
                        else if inB && inR { newSnap = .bottomRight }
                        else if inT        { newSnap = .fullscreen }
                        else if inL        { newSnap = .leftHalf }
                        else if inR        { newSnap = .rightHalf }
                        else               { newSnap = nil }

                        if desktopVM.snapPreview != newSnap {
                            withAnimation(.spring(duration: 0.18, bounce: 0.05)) {
                                desktopVM.snapPreview = newSnap
                            }
                        }
                    }
                    .onEnded { _ in
                        guard !isMaximized else { return }
                        isDragging = false
                        if let snap = desktopVM.snapPreview {
                            applySnap(snap)
                            withAnimation(.spring(duration: 0.2)) { desktopVM.snapPreview = nil }
                        } else {
                            position = CGPoint(
                                x: min(max(position.x, size.width/2), screenSize.width - size.width/2),
                                y: min(max(position.y, 44), screenSize.height - size.height/2 - 10)
                            )
                            desktopVM.updateWindow(window.id, position: position, size: size)
                        }
                    }
            )
            .onTapGesture(count: 2) { toggleMaximize() }

            WindowContent(app: desktopVM.taskbarApps.first { $0.id == window.appID }
                          ?? desktopVM.allApps.first { $0.id == window.appID })
                .frame(width: size.width, height: size.height - 44)
        }
        .frame(width: size.width, height: size.height)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: isMaximized ? 0 : 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: isMaximized ? 0 : 18, style: .continuous)
                .stroke(.white.opacity(isMaximized ? 0 : 0.15), lineWidth: 0.5)
        )
        // ── Resize handles (non visibili, solo hitbox) ──────────────────
        .overlay(alignment: .bottom) {
            ResizeHandle(cursor: "resizeDown", onDrag: { _, dy in
                guard !isMaximized else { return }
                if !isResizing { isResizing = true; resizeStartSize = size; resizeStartPos = position }
                size.height = max(minH, resizeStartSize.height + dy)
            }, onEnd: {
                isResizing = false
                desktopVM.removeSnappedWindow(window.id)
                desktopVM.updateWindow(window.id, position: position, size: size)
            })
            .frame(height: 8)
        }
        .overlay(alignment: .trailing) {
            ResizeHandle(cursor: "resizeRight", onDrag: { dx, _ in
                guard !isMaximized else { return }
                if !isResizing { isResizing = true; resizeStartSize = size; resizeStartPos = position }
                size.width = max(minW, resizeStartSize.width + dx)
            }, onEnd: {
                isResizing = false
                desktopVM.removeSnappedWindow(window.id)
                desktopVM.updateWindow(window.id, position: position, size: size)
            })
            .frame(width: 8)
        }
        .overlay(alignment: .bottomTrailing) {
            ResizeHandle(cursor: "resizeUpLeftDownRight", onDrag: { dx, dy in
                guard !isMaximized else { return }
                if !isResizing { isResizing = true; resizeStartSize = size; resizeStartPos = position }
                size.width  = max(minW, resizeStartSize.width  + dx)
                size.height = max(minH, resizeStartSize.height + dy)
            }, onEnd: {
                isResizing = false
                desktopVM.removeSnappedWindow(window.id)
                desktopVM.updateWindow(window.id, position: position, size: size)
            })
            .frame(width: 16, height: 16)
        }
        .overlay(alignment: .leading) {
            ResizeHandle(cursor: "resizeLeft", onDrag: { dx, _ in
                guard !isMaximized else { return }
                if !isResizing { isResizing = true; resizeStartSize = size; resizeStartPos = position }
                let newW = max(minW, resizeStartSize.width - dx)
                let delta = newW - size.width
                size.width = newW
                position.x -= delta / 2
            }, onEnd: {
                isResizing = false
                desktopVM.removeSnappedWindow(window.id)
                desktopVM.updateWindow(window.id, position: position, size: size)
            })
            .frame(width: 8)
        }
        .overlay(alignment: .top) {
            Color.clear.frame(height: 8) // top resize — gestita dal titlebar drag
        }
        .overlay(alignment: .bottomLeading) {
            ResizeHandle(cursor: "resizeUpRightDownLeft", onDrag: { dx, dy in
                guard !isMaximized else { return }
                if !isResizing { isResizing = true; resizeStartSize = size; resizeStartPos = position }
                let newW = max(minW, resizeStartSize.width - dx)
                let deltaW = newW - size.width
                size.width  = newW
                size.height = max(minH, resizeStartSize.height + dy)
                position.x -= deltaW / 2
            }, onEnd: {
                isResizing = false
                desktopVM.removeSnappedWindow(window.id)
                desktopVM.updateWindow(window.id, position: position, size: size)
            })
            .frame(width: 16, height: 16)
        }
        // ────────────────────────────────────────────────────────────────
        .shadow(color: .black.opacity(isActive ? 0.5 : 0.2), radius: isActive ? 30 : 14, y: isActive ? 12 : 5)
        .scaleEffect(isDragging ? 1.005 : 1)
        .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.85), value: isDragging)
        .animation(.spring(duration: 0.45, bounce: 0.1), value: isMaximized)
        .animation(.spring(duration: 0.45, bounce: 0.1), value: size)
        .position(x: position.x, y: position.y)
        .onTapGesture { desktopVM.bringToFront(window.id) }
        .opacity(appear ? 1 : 0)
        .scaleEffect(appear ? 1 : 0.88)
        .onAppear { withAnimation(.spring(duration: 0.4, bounce: 0.15)) { appear = true } }
        .onChange(of: window.isMaximized) { _, newValue in
            guard isMaximized != newValue else { return }
            withAnimation(.spring(duration: 0.45, bounce: 0.08)) {
                if newValue {
                    preMaxSize = size; preMaxPosition = position
                    size = screenSize
                    position = CGPoint(x: screenSize.width/2, y: screenSize.height/2)
                    isMaximized = true
                } else {
                    size = preMaxSize.width > 0 ? preMaxSize : CGSize(width: 680, height: 460)
                    position = (preMaxPosition.x > 0 || preMaxPosition.y > 44)
                        ? preMaxPosition
                        : CGPoint(x: screenSize.width/2, y: screenSize.height/2)
                    isMaximized = false
                }
            }
        }
    }

    // MARK: - Snap apply
    private func applySnap(_ zone: SnapZone) {
        withAnimation(.spring(duration: 0.4, bounce: 0.08)) {
            let hw = screenSize.width / 2; let hh = screenSize.height / 2
            switch zone {
            case .fullscreen:
                preMaxSize = size; preMaxPosition = position
                size = screenSize
                position = CGPoint(x: hw, y: hh)
                isMaximized = true
                desktopVM.setMaximized(window.id, value: true)
            case .leftHalf:
                size = CGSize(width: hw, height: screenSize.height)
                position = CGPoint(x: hw/2, y: hh)
                desktopVM.updateWindow(window.id, position: position, size: size)
                desktopVM.addSnappedWindow(window.id, zone: zone)
            case .rightHalf:
                size = CGSize(width: hw, height: screenSize.height)
                position = CGPoint(x: hw + hw/2, y: hh)
                desktopVM.updateWindow(window.id, position: position, size: size)
                desktopVM.addSnappedWindow(window.id, zone: zone)
            case .topLeft:
                size = CGSize(width: hw, height: hh)
                position = CGPoint(x: hw/2, y: hh/2)
                desktopVM.updateWindow(window.id, position: position, size: size)
                desktopVM.addSnappedWindow(window.id, zone: zone)
            case .topRight:
                size = CGSize(width: hw, height: hh)
                position = CGPoint(x: hw + hw/2, y: hh/2)
                desktopVM.updateWindow(window.id, position: position, size: size)
                desktopVM.addSnappedWindow(window.id, zone: zone)
            case .bottomLeft:
                size = CGSize(width: hw, height: hh)
                position = CGPoint(x: hw/2, y: hh + hh/2)
                desktopVM.updateWindow(window.id, position: position, size: size)
                desktopVM.addSnappedWindow(window.id, zone: zone)
            case .bottomRight:
                size = CGSize(width: hw, height: hh)
                position = CGPoint(x: hw + hw/2, y: hh + hh/2)
                desktopVM.updateWindow(window.id, position: position, size: size)
                desktopVM.addSnappedWindow(window.id, zone: zone)
            }
        }
    }

    // MARK: - Toggle maximize
    private func toggleMaximize() {
        withAnimation(.spring(duration: 0.45, bounce: 0.08)) {
            if isMaximized {
                let safeSize = preMaxSize.width > 0 ? preMaxSize : CGSize(width: 680, height: 460)
                let safePos  = (preMaxPosition.x > 0 || preMaxPosition.y > 44)
                    ? preMaxPosition
                    : CGPoint(x: screenSize.width/2, y: screenSize.height/2)
                size = safeSize; position = safePos
                isMaximized = false
                desktopVM.setMaximized(window.id, value: false)
            } else {
                preMaxSize = size; preMaxPosition = position
                size = screenSize
                position = CGPoint(x: screenSize.width/2, y: screenSize.height/2)
                isMaximized = true
                desktopVM.setMaximized(window.id, value: true)
                desktopVM.updateWindow(window.id, position: position, size: size)
            }
        }
    }
}