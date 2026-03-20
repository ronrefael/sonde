import AppKit
import SondeCore
import SwiftUI

/// A small always-on-top floating panel that displays active Claude sessions.
struct FloatingWatcherView: View {
    @ObservedObject var viewModel: SondeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title bar
            HStack {
                Image(systemName: "terminal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Agent Watcher")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    viewModel.showWatcher = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }

            Divider()

            // Current model summary
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Model")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(viewModel.session.modelName ?? "--")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                Spacer()
            }
            .padding(.vertical, 2)

            Divider()

            // Active sessions list
            if viewModel.activeSessions.isEmpty {
                Text("No active sessions")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            } else {
                Text("\(viewModel.activeSessions.count) active")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                ForEach(viewModel.activeSessions) { session in
                    HStack(spacing: 6) {
                        Text("PID \(session.id)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(truncateCommand(session.command))
                            .font(.caption2)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
        }
        .padding(10)
        .frame(width: 200)
    }

    private func truncateCommand(_ cmd: String) -> String {
        if cmd.count > 30 {
            return String(cmd.prefix(30)) + "..."
        }
        return cmd
    }
}

// MARK: - Floating Panel Controller

/// Manages the floating NSPanel that hosts the watcher view.
@MainActor
final class FloatingWatcherPanel {
    static let shared = FloatingWatcherPanel()

    private var panel: NSPanel?
    private var hostingView: NSHostingView<FloatingWatcherView>?

    private init() {}

    func show(viewModel: SondeViewModel) {
        if let existing = panel {
            existing.orderFront(nil)
            return
        }

        let content = FloatingWatcherView(viewModel: viewModel)
        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(x: 0, y: 0, width: 200, height: 200)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
            styleMask: [.titled, .closable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.title = "Agent Watcher"
        panel.contentView = hosting
        panel.isReleasedWhenClosed = false

        // Size to fit content
        hosting.invalidateIntrinsicContentSize()
        let fittingSize = hosting.fittingSize
        panel.setContentSize(fittingSize)

        // Position near top-right of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - fittingSize.width - 20
            let y = screenFrame.maxY - fittingSize.height - 20
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFront(nil)
        self.panel = panel
        self.hostingView = hosting
    }

    func close() {
        panel?.close()
        panel = nil
        hostingView = nil
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }
}
