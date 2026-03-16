import AppKit
import SwiftUI

/// A Dynamic Island-style pill-shaped toast notification view.
struct ToastView: View {
    let message: String
    let icon: String?

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Text(icon)
                    .font(.system(size: 14))
            }
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.85))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        )
        .frame(maxWidth: 300)
    }
}

/// Singleton manager that shows Dynamic Island-style toast notifications
/// at the top-center of the screen using a floating NSPanel.
@MainActor
final class ToastManager {
    static let shared = ToastManager()

    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?

    private init() {}

    /// Show a toast notification with the given message and optional icon.
    /// The toast slides in from the top, stays for 3 seconds, then slides out.
    func show(message: String, icon: String? = nil) {
        // Cancel any pending dismiss
        dismissTask?.cancel()
        dismissTask = nil

        // If panel already exists, update content and reset timer
        if let existing = panel {
            let content = ToastView(message: message, icon: icon)
            let hosting = NSHostingView(rootView: content)
            hosting.invalidateIntrinsicContentSize()
            let size = hosting.fittingSize
            existing.contentView = hosting
            existing.setContentSize(size)
            repositionPanel(existing, size: size)
            existing.orderFront(nil)
            scheduleDismiss()
            return
        }

        // Create new panel
        let content = ToastView(message: message, icon: icon)
        let hosting = NSHostingView(rootView: content)
        hosting.invalidateIntrinsicContentSize()
        let size = hosting.fittingSize

        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.level = .floating
        newPanel.isFloatingPanel = true
        newPanel.hidesOnDeactivate = false
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = false
        newPanel.isMovableByWindowBackground = false
        newPanel.ignoresMouseEvents = true
        newPanel.isReleasedWhenClosed = false
        newPanel.contentView = hosting

        // Position at top-center of screen, initially off-screen (above)
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - size.width / 2
            let yHidden = screenFrame.maxY + size.height
            newPanel.setFrameOrigin(NSPoint(x: x, y: yHidden))
        }

        newPanel.alphaValue = 0
        newPanel.orderFront(nil)
        self.panel = newPanel

        // Slide in animation
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            newPanel.animator().alphaValue = 1
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let x = screenFrame.midX - size.width / 2
                let yVisible = screenFrame.maxY - size.height - 12
                newPanel.animator().setFrameOrigin(NSPoint(x: x, y: yVisible))
            }
        })

        scheduleDismiss()
    }

    private func repositionPanel(_ panel: NSPanel, size: NSSize) {
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - size.width / 2
            let y = screenFrame.maxY - size.height - 12
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    private func scheduleDismiss() {
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    private func dismiss() {
        guard let panel else { return }

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let size = panel.frame.size
                let x = screenFrame.midX - size.width / 2
                let yHidden = screenFrame.maxY + size.height
                panel.animator().setFrameOrigin(NSPoint(x: x, y: yHidden))
            }
        }, completionHandler: {
            Task { @MainActor [weak self] in
                self?.panel?.close()
                self?.panel = nil
            }
        })
    }
}
