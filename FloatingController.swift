import AppKit
import SwiftUI

class FloatingController: NSObject {

    private var panel:        NSPanel?
    private var mainWindow:   NSWindow?
    private var tooltipPanel: NSPanel?
    private let taskManager:  TaskManager

    // Partagé entre FloatingPanelContent et FloatingCircleView
    private let pinState = FloatingPinState()

    private let positionKey     = "com.todofloat.position"
    private let mainPositionKey = "com.todofloat.mainWindowPosition"

    init(taskManager: TaskManager) {
        self.taskManager = taskManager
    }

    // MARK: - Floating Panel

    func show() {
        let size   = CGSize(width: 128, height: 128)
        let origin = savedPosition() ?? defaultPosition(size: size)

        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask:   [.borderless, .nonactivatingPanel],
            backing:     .buffered,
            defer:       false
        )
        panel.level              = .floating
        panel.isOpaque           = false
        panel.backgroundColor    = .clear
        panel.hasShadow          = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.delegate           = self

        // Vue SwiftUI — aucun gesture de drag ici, tout est géré par FloatingPanelContent
        let circleView = FloatingCircleView(
            taskManager:  taskManager,
            pinState:     pinState,
            onHoverStart: { [weak self] in self?.tooltipShow() },
            onHoverEnd:   { [weak self] in self?.tooltipHide() }
        )

        // Hosting view custom avec drag AppKit natif (NSEvent.mouseLocation)
        let content = FloatingPanelContent(rootView: AnyView(circleView))
        content.targetPanel = panel
        content.pinState    = pinState
        content.onTap       = { [weak self] in self?.tooltipHide(); self?.toggleMain() }
        content.onDragEnded = { [weak self] in
            guard let origin = self?.panel?.frame.origin else { return }
            self?.savePosition(origin)
        }
        content.onDragPosition = { [weak self] newOrigin in
            self?.updateTooltipPosition(panelOrigin: newOrigin)
        }

        panel.contentView = content
        panel.orderFrontRegardless()
        self.panel = panel
    }

    // MARK: - Tooltip

    // Centre visuel du cercle dans le panel 128×128 (cercle 56px centré → offset 36px depuis bord)
    private func circleMidX(panelOrigin: NSPoint) -> CGFloat { panelOrigin.x + 64 }
    private func circleMidY(panelOrigin: NSPoint) -> CGFloat { panelOrigin.y + 64 }
    private func circleMinY(panelOrigin: NSPoint) -> CGFloat { panelOrigin.y + 36 }
    private func circleMaxY(panelOrigin: NSPoint) -> CGFloat { panelOrigin.y + 92 }

    func tooltipShow() {
        let pending = taskManager.todayPending
        guard !pending.isEmpty, let panelOrigin = panel?.frame.origin else { return }

        let top3     = Array(pending.prefix(3))
        let rows     = CGFloat(top3.count)
        let tooltipH = 18 + rows * 24 - (rows > 0 ? 6 : 0)
        let tooltipW: CGFloat = 230

        let frame = tooltipFrame(panelOrigin: panelOrigin, tooltipW: tooltipW, tooltipH: tooltipH)

        if tooltipPanel == nil {
            let p = NSPanel(
                contentRect: frame,
                styleMask:   [.borderless, .nonactivatingPanel],
                backing:     .buffered,
                defer:       false
            )
            p.level              = .floating
            p.isOpaque           = false
            p.backgroundColor    = .clear
            p.hasShadow          = false
            p.ignoresMouseEvents = true
            p.collectionBehavior = [.canJoinAllSpaces, .stationary]
            tooltipPanel = p
        }

        tooltipPanel?.contentView = NSHostingView(rootView: TaskPreviewView(tasks: top3))
        tooltipPanel?.setFrame(frame, display: true)
        tooltipPanel?.orderFrontRegardless()
    }

    func tooltipHide() {
        tooltipPanel?.orderOut(nil)
    }

    /// Repositionne le tooltip en temps réel pendant le drag du pin
    private func updateTooltipPosition(panelOrigin: NSPoint) {
        guard let tp = tooltipPanel, tp.isVisible else { return }
        let size = tp.frame.size
        let frame = tooltipFrame(panelOrigin: panelOrigin, tooltipW: size.width, tooltipH: size.height)
        tp.setFrameOrigin(frame.origin)
    }

    private func tooltipFrame(panelOrigin: NSPoint, tooltipW: CGFloat, tooltipH: CGFloat) -> NSRect {
        var yPos = circleMinY(panelOrigin: panelOrigin) - tooltipH - 10
        if let screen = NSScreen.main, yPos < screen.visibleFrame.minY {
            yPos = circleMaxY(panelOrigin: panelOrigin) + 10
        }
        let xPos = (circleMidX(panelOrigin: panelOrigin) - tooltipW / 2).rounded()
        return NSRect(x: xPos, y: yPos, width: tooltipW, height: tooltipH)
    }

    // MARK: - Main Window

    private func toggleMain() {
        if let win = mainWindow, win.isVisible {
            win.orderOut(nil)
        } else {
            showMain()
        }
    }

    private func showMain() {
        if let win = mainWindow {
            win.makeKeyAndOrderFront(nil)
        } else {
            let win = makeMainWindow()
            mainWindow = win
            win.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeMainWindow() -> NSWindow {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask:   [.titled, .closable, .fullSizeContentView],
            backing:     .buffered,
            defer:       false
        )
        win.titleVisibility            = .hidden
        win.titlebarAppearsTransparent = true
        win.level = .floating
        if let origin = savedMainWindowPosition() {
            win.setFrameOrigin(origin)
        } else {
            win.center()
        }
        win.contentView = NSHostingView(rootView: ContentView(taskManager: taskManager))
        win.delegate    = self
        return win
    }

    // MARK: - Position persistence

    private func savedPosition() -> CGPoint? {
        guard let d = UserDefaults.standard.dictionary(forKey: positionKey),
              let x = d["x"] as? Double, let y = d["y"] as? Double else { return nil }
        let pt = CGPoint(x: x, y: y)
        return NSScreen.screens.contains(where: { $0.frame.contains(pt) }) ? pt : nil
    }

    private func defaultPosition(size: CGSize) -> CGPoint {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        return CGPoint(
            x: screen.visibleFrame.maxX - size.width  - 20,
            y: screen.visibleFrame.maxY - size.height - 20
        )
    }

    func savePosition(_ origin: CGPoint) {
        UserDefaults.standard.set(["x": origin.x, "y": origin.y], forKey: positionKey)
    }

    private func savedMainWindowPosition() -> CGPoint? {
        guard let d = UserDefaults.standard.dictionary(forKey: mainPositionKey),
              let x = d["x"] as? Double, let y = d["y"] as? Double else { return nil }
        let pt = CGPoint(x: x, y: y)
        return NSScreen.screens.contains(where: { $0.frame.contains(pt) }) ? pt : nil
    }
}

// MARK: - NSWindowDelegate

extension FloatingController: NSWindowDelegate {

    /// Intercepte le bouton rouge : masquage au lieu de close réelle (évite crash SwiftUI)
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === mainWindow {
            sender.orderOut(nil)
            return false
        }
        return true
    }

    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === panel, let origin = panel?.frame.origin {
            savePosition(origin)
        } else if window === mainWindow, let origin = mainWindow?.frame.origin {
            UserDefaults.standard.set(["x": origin.x, "y": origin.y], forKey: mainPositionKey)
        }
    }
}
