import AppKit
import ServiceManagement
import SondeCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Theme

private func hex(_ hex: UInt) -> Color {
    Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
}

enum PopoverTheme: String, CaseIterable {
    case liquidGlass = "Liquid Glass"
    case system = "System"
    case terminal = "Terminal"
    case cyberpunk = "Cyberpunk"
    case synthwave = "Synthwave"
    case solarFlare = "Solar Flare"

    private static let phosphor = Color(red: 0.2, green: 1.0, blue: 0.2)
    private static let phosphorDim = Color(red: 0.15, green: 0.6, blue: 0.15)
    private static let phosphorFaint = Color(red: 0.12, green: 0.45, blue: 0.12)
    private static let amber = Color(red: 1.0, green: 0.85, blue: 0.3)
    private static let amberDim = Color(red: 0.75, green: 0.6, blue: 0.2)
    private static let cyan = Color(red: 0.3, green: 0.9, blue: 0.9)

    // MARK: Colors

    var cardBackground: Color {
        switch self {
        case .liquidGlass: Color.primary.opacity(0.04)
        case .terminal: Color(red: 0.04, green: 0.06, blue: 0.04)
        case .cyberpunk: hex(0x141726)
        case .synthwave: hex(0x2D1B4E)
        case .solarFlare: hex(0x1A0A12)
        case .system: Color.white.opacity(0.6)
        }
    }

    var headerAccent: Color {
        switch self {
        case .liquidGlass: .blue
        case .terminal: Self.amber
        case .cyberpunk: hex(0x18E0FF)
        case .synthwave: hex(0xFF2975)
        case .solarFlare: hex(0xFF6B2B)
        case .system: hex(0x0071E3)
        }
    }

    var textPrimary: Color {
        switch self {
        case .liquidGlass: .primary
        case .terminal: Self.phosphor
        case .cyberpunk: hex(0xE0E0E0)
        case .synthwave: hex(0xF0E6FF)
        case .solarFlare: hex(0xFFE0C8)
        case .system: hex(0x1D1D1F)
        }
    }

    var textSecondary: Color {
        switch self {
        case .liquidGlass: .secondary
        case .terminal: Self.amberDim
        case .cyberpunk: hex(0x6B7B8D)
        case .synthwave: hex(0x9B7EC8)
        case .solarFlare: hex(0x8B5A3A)
        case .system: hex(0x86868B)
        }
    }

    var costHighColor: Color {
        switch self {
        case .terminal: Color(red: 1.0, green: 0.15, blue: 0.15)
        default: .red
        }
    }

    var costMedColor: Color {
        switch self {
        case .terminal: Self.amber
        default: .orange
        }
    }

    var borderColor: Color {
        switch self {
        case .liquidGlass: Color.primary.opacity(0.06)
        case .terminal: Self.phosphorDim.opacity(0.3)
        case .cyberpunk: hex(0x18E0FF).opacity(0.2)
        case .synthwave: hex(0xFF2975).opacity(0.2)
        case .solarFlare: hex(0xFF6B2B).opacity(0.2)
        case .system: Color.primary.opacity(0.08)
        }
    }

    var popoverBackground: Color {
        switch self {
        case .liquidGlass: .clear
        case .terminal: Color(red: 0.02, green: 0.02, blue: 0.04)
        case .cyberpunk: hex(0x0B0C10)
        case .synthwave: hex(0x1A1025)
        case .solarFlare: hex(0x0D0208)
        case .system: hex(0xF5F5F7)
        }
    }

    var dividerColor: Color {
        switch self {
        case .liquidGlass: Color.primary.opacity(0.1)
        case .terminal: Self.phosphor.opacity(0.12)
        case .system: Color.primary.opacity(0.08)
        default: borderColor
        }
    }

    var footerText: Color {
        switch self {
        case .liquidGlass, .system: .secondary
        case .terminal: Self.phosphorFaint
        default: textSecondary.opacity(0.7)
        }
    }

    var textGlow: Color? {
        switch self {
        case .terminal: Self.phosphor.opacity(0.6)
        case .cyberpunk: hex(0x18E0FF).opacity(0.5)
        case .solarFlare: hex(0xFF6B2B).opacity(0.4)
        default: nil
        }
    }

    var preferMonospaced: Bool {
        switch self {
        case .terminal, .cyberpunk: true
        default: false
        }
    }

    var hasScanlines: Bool {
        switch self {
        case .terminal, .cyberpunk: true
        default: false
        }
    }

    var cardGlow: Color? {
        switch self {
        case .terminal: Self.phosphor.opacity(0.15)
        case .cyberpunk: hex(0x18E0FF).opacity(0.1)
        case .synthwave: hex(0xFF2975).opacity(0.08)
        case .solarFlare: hex(0xFF6B2B).opacity(0.1)
        default: nil
        }
    }

    /// Highlight color for interactive/standout stats (lines/hr, context %, promo)
    var highlightAccent: Color {
        switch self {
        case .terminal: Self.cyan
        default: headerAccent
        }
    }

    /// Low-utilization color for gauges and bars (replaces hardcoded .green)
    var lowUtilColor: Color {
        switch self {
        case .terminal: Self.phosphor
        default: .green
        }
    }

    var swatchColor: Color { headerAccent }

    // Model pill colors
    var modelOpusColor: Color {
        switch self {
        case .terminal: Self.amber
        default: Color(red: 0.55, green: 0.25, blue: 0.85)
        }
    }

    var modelSonnetColor: Color {
        switch self {
        case .terminal: Self.cyan
        default: Color(red: 0.2, green: 0.45, blue: 0.9)
        }
    }

    var modelHaikuColor: Color {
        switch self {
        case .terminal: Self.phosphorDim
        default: Color(red: 0.0, green: 0.65, blue: 0.55)
        }
    }

    var modelPillText: Color {
        switch self {
        case .terminal: Color(red: 0.08, green: 0.08, blue: 0.06)
        default: .white
        }
    }

    func modelColor(for name: String) -> Color {
        let lower = name.lowercased()
        if lower.contains("opus") { return modelOpusColor }
        if lower.contains("haiku") { return modelHaikuColor }
        return modelSonnetColor
    }
}

// MARK: - Scanline Overlay

private struct ScanlineOverlay: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 3
            var y: CGFloat = 0
            while y < size.height {
                let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                context.fill(Path(rect), with: .color(.black.opacity(0.12)))
                y += spacing
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Model Pill

private struct ModelPill: View {
    let name: String
    let theme: PopoverTheme
    var cost: Double? = nil
    var compact: Bool = false

    private var shortName: String {
        let lower = name.lowercased()
        if lower.contains("opus") { return "Opus" }
        if lower.contains("sonnet") { return "Sonnet" }
        if lower.contains("haiku") { return "Haiku" }
        return String(name.prefix(10))
    }

    var body: some View {
        HStack(spacing: 3) {
            Text(shortName)
                .font(.system(size: compact ? 9 : 11, weight: .semibold, design: .monospaced))
            if let cost {
                Text(String(format: "$%.2f", cost))
                    .font(.system(size: compact ? 9 : 10, weight: .medium, design: .monospaced))
            }
        }
        .foregroundStyle(theme.modelPillText)
        .padding(.horizontal, compact ? 5 : 7)
        .padding(.vertical, compact ? 2 : 3)
        .background(theme.modelColor(for: name), in: RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Pulse Dot

private struct PulseDot: View {
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(.green)
            .frame(width: 5, height: 5)
            .opacity(pulsing ? 1.0 : 0.3)
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulsing)
            .onAppear { pulsing = true }
    }
}

// MARK: - Context Progress Bar

private struct ContextBar: View {
    let theme: PopoverTheme
    let pct: Double
    let tokensUsed: Int
    let windowSize: Int

    private var barColor: Color {
        if pct >= 80 { return .red }
        if pct >= 60 { return .orange }
        return theme.lowUtilColor
    }

    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(theme.borderColor)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor)
                        .frame(width: max(0, geo.size.width * min(pct, 100) / 100), height: 4)
                        .animation(.easeInOut(duration: 0.8), value: pct)
                }
            }
            .frame(height: 4)

            HStack(spacing: 0) {
                Spacer()
                Text("\(Int(pct))%")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(barColor)
                    .contentTransition(.numericText())
                Text("  \(formatK(tokensUsed))/\(formatK(windowSize))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(theme.textSecondary.opacity(0.6))
            }
        }
    }

    private func formatK(_ tokens: Int) -> String {
        if tokens >= 1_000_000 { return String(format: "%.0fM", Double(tokens) / 1_000_000) }
        if tokens >= 1000 { return String(format: "%.0fk", Double(tokens) / 1000) }
        return "\(tokens)"
    }
}

// MARK: - Live Session Strip

private struct LiveSessionStrip: View {
    let theme: PopoverTheme
    let session: SessionData
    let liveTimer: String
    let payPerToken: Bool
    let extraUsageUsed: Double?
    let extraUsageLimit: Double?
    let markActive: Bool
    let costSinceMark: Double
    let timeSinceMark: String
    let showCosts: Bool
    let onSetMark: () -> Void
    let onClearMark: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            // Top row: model pill, git branch, cost, timer, pulse dot
            HStack(spacing: 8) {
                if let model = session.modelName {
                    HStack(spacing: 4) {
                        ModelPill(name: model, theme: theme)
                        if payPerToken {
                            Text(tokenRate(for: model))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(theme.costMedColor.opacity(0.8))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(theme.costMedColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 3))
                        } else if let window = session.contextWindowSize, window > 0 {
                            Text(formatWindowSize(window))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(theme.textSecondary.opacity(0.6))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(theme.borderColor, in: RoundedRectangle(cornerRadius: 3))
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                if let branch = session.gitBranch {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 9))
                        Text(branch)
                            .font(.system(size: 11, design: .monospaced))
                            .lineLimit(1)
                            .frame(maxWidth: 90, alignment: .leading)
                    }
                    .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                if showCosts && (payPerToken || showExtraUsageCost) {
                    HStack(spacing: 3) {
                        if showExtraUsageCost && !payPerToken {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.orange)
                                .help("Extended session — extra usage billing active")
                        }
                        Text(session.formattedCost)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(costColor)
                            .contentTransition(.numericText())
                    }
                }

                Text(liveTimer)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                    .contentTransition(.numericText())

                PulseDot()
            }

            // Burn rate + mark row
            HStack(spacing: 0) {
                // Mark button / indicator
                if showCosts {
                    if markActive {
                        Button(action: onClearMark) {
                            HStack(spacing: 3) {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.blue)
                                Text(String(format: "+$%.2f", costSinceMark))
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.blue)
                                Text(timeSinceMark)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(theme.textSecondary.opacity(0.6))
                            }
                        }
                        .buttonStyle(.borderless)
                        .help("Click to clear checkpoint")
                    } else {
                        Button(action: onSetMark) {
                            HStack(spacing: 3) {
                                Image(systemName: "flag")
                                    .font(.system(size: 8))
                                Text("Mark")
                                    .font(.system(size: 9))
                            }
                            .foregroundStyle(theme.textSecondary.opacity(0.4))
                        }
                        .buttonStyle(.borderless)
                        .help("Set checkpoint to track cost from now")
                    }
                }

                Spacer()

                if showCosts, let rate = session.costPerHour {
                    Image(systemName: "flame")
                        .font(.system(size: 8))
                        .foregroundStyle(.orange)
                    Text(" \(rate)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textSecondary.opacity(0.7))
                }
            }

            // Context bar
            if let pct = session.contextUsedPct, let window = session.contextWindowSize, window > 0 {
                ContextBar(
                    theme: theme,
                    pct: pct,
                    tokensUsed: session.contextTokensUsed,
                    windowSize: window
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(theme.cardBackground.opacity(0.5))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    /// Show cost when extra usage has kicked in (user extended beyond included limits)
    private var showExtraUsageCost: Bool {
        guard let used = extraUsageUsed else { return false }
        return used > 0
    }

    private var costColor: Color {
        guard let cost = session.sessionCost else { return theme.textPrimary }
        if cost >= 10.0 { return theme.costHighColor }
        if cost >= 5.0 { return theme.costMedColor }
        return theme.textPrimary
    }

    private func formatWindowSize(_ tokens: Int) -> String {
        if tokens >= 1_000_000 { return "\(tokens / 1_000_000)M ctx" }
        if tokens >= 1000 { return "\(tokens / 1000)k ctx" }
        return "\(tokens) ctx"
    }

    /// Per-MTok pricing for the current model (input/output)
    private func tokenRate(for model: String) -> String {
        let lower = model.lowercased()
        if lower.contains("opus") { return "$15/$75 MTok" }
        if lower.contains("haiku") { return "$0.25/$1.25 MTok" }
        return "$3/$15 MTok" // Sonnet default
    }
}

// MARK: - Popover Root

struct PopoverView: View {
    @ObservedObject var viewModel: SondeViewModel
    @AppStorage("popoverTheme") private var themeName: String = PopoverTheme.system.rawValue
    @AppStorage("showCosts") private var showCosts: Bool = false
    @State private var showProjects = false

    private var theme: PopoverTheme {
        PopoverTheme(rawValue: themeName) ?? .system
    }

    private var hasActiveSession: Bool {
        viewModel.session.modelName != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(
                theme: theme,
                lastUpdated: viewModel.lastUpdated,
                updateAvailable: viewModel.updateAvailable,
                promoActive: viewModel.promoActive,
                promoCountdown: viewModel.promoCountdown,
                promoShortLabel: viewModel.promoShortLabel,
                promoDescription: viewModel.promoDescription,
                promoUrl: viewModel.promoUrl,
                agentName: viewModel.session.agentName
            )

            Divider().overlay(theme.dividerColor)

            // Live Session Strip (between header and scroll, fixed)
            if hasActiveSession {
                LiveSessionStrip(
                    theme: theme,
                    session: viewModel.session,
                    liveTimer: viewModel.liveSessionDuration,
                    payPerToken: viewModel.extraUsageEnabled,
                    extraUsageUsed: viewModel.extraUsageUsedCredits,
                    extraUsageLimit: viewModel.extraUsageMonthlyLimit,
                    markActive: viewModel.markActive,
                    costSinceMark: viewModel.costSinceMark,
                    timeSinceMark: viewModel.timeSinceMark,
                    showCosts: showCosts,
                    onSetMark: { viewModel.setMark() },
                    onClearMark: { viewModel.clearMark() }
                )
                .animation(.easeInOut(duration: 0.3), value: hasActiveSession)

                Divider().overlay(theme.dividerColor)
            }

            if showProjects {
                ProjectsView(
                    projects: viewModel.allProjects,
                    showProjects: $showProjects,
                    showCosts: showCosts,
                    theme: theme
                )
            } else if viewModel.isLoading {
                LoadingPlaceholder(theme: theme)
            } else {
                DashboardContent(
                    theme: theme,
                    viewModel: viewModel,
                    showProjects: $showProjects,
                    showCosts: showCosts
                )
            }

            Divider().overlay(theme.dividerColor)

            FooterBar(
                theme: theme,
                onRefresh: { Task { await viewModel.refresh() } },
                onExport: { exportUsageData() },
                onCopySummary: { copySummary() },
                onToggleWatcher: {
                    viewModel.showWatcher.toggle()
                    if viewModel.showWatcher {
                        FloatingWatcherPanel.shared.show(viewModel: viewModel)
                    } else {
                        FloatingWatcherPanel.shared.close()
                    }
                },
                themeName: $themeName,
                showCosts: $showCosts
            )
        }
        .frame(width: 380, height: 700)
        .background(theme.popoverBackground)
        .overlay {
            if theme.hasScanlines { ScanlineOverlay() }
        }
        .onAppear { Task { await viewModel.refresh() } }
    }

    private func copySummary() {
        let sessions = viewModel.allSessions
        let totalCost = sessions.reduce(0.0) { $0 + ($1.sessionCost ?? 0) }
        let count = max(sessions.count, viewModel.activeSessions.count)
        var text = String(format: "$%.2f across %d session%@", totalCost, count, count == 1 ? "" : "s")
        if let fh = viewModel.fiveHourUtil {
            text += String(format: " (%d%% of 5h limit used)", Int(fh))
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func exportUsageData() {
        let json = viewModel.exportJSONString()
        let panel = NSSavePanel()
        let dateStr = ISO8601DateFormatter.string(
            from: Date(), timeZone: .current,
            formatOptions: [.withFullDate, .withDashSeparatorInDate])
        panel.nameFieldStringValue = "sonde-export-\(dateStr).json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try json.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

// MARK: - Header Bar

private struct HeaderBar: View {
    let theme: PopoverTheme
    let lastUpdated: Date?
    let updateAvailable: String?
    let promoActive: Bool
    let promoCountdown: String
    let promoShortLabel: String
    let promoDescription: String
    let promoUrl: String
    let agentName: String?

    private var showPromoBadge: Bool {
        promoActive || !promoCountdown.isEmpty
    }

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                SondeLogoMascot()
                    .frame(width: 20, height: 20)
                HStack(spacing: 0) {
                    Text("sond")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.114, green: 0.620, blue: 0.459))
                    Text("e")
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundStyle(Color(red: 0.114, green: 0.620, blue: 0.459))
                }
            }
            .help(lastUpdatedText)

            if let version = updateAvailable {
                Button {
                    if let url = URL(string: "https://github.com/ronrefael/sonde/releases/latest") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text("v\(version)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue, in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.borderless)
            }

            Spacer()

            // Agent badge pill
            if let agent = agentName, !agent.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "cpu")
                        .font(.system(size: 9))
                    Text(agent)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(theme.headerAccent)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(theme.headerAccent.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(theme.headerAccent.opacity(0.3), lineWidth: 1))
                .cornerRadius(5)
            }

            if showPromoBadge {
                PromoBadge(
                    theme: theme,
                    promoActive: promoActive,
                    promoCountdown: promoCountdown,
                    promoShortLabel: promoShortLabel,
                    promoDescription: promoDescription,
                    promoUrl: promoUrl
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var lastUpdatedText: String {
        guard let updated = lastUpdated else { return "Not yet updated" }
        let secs = Int(Date().timeIntervalSince(updated))
        if secs < 5 { return "Updated just now" }
        if secs < 60 { return "Updated \(secs)s ago" }
        return "Updated \(secs / 60)m ago"
    }
}

// MARK: - Promo Badge

private struct PromoBadge: View {
    let theme: PopoverTheme
    let promoActive: Bool
    let promoCountdown: String
    let promoShortLabel: String
    let promoDescription: String
    let promoUrl: String

    var body: some View {
        Button {
            let urlString = promoUrl.isEmpty ? "https://support.claude.com/en/articles/14063676-claude-march-2026-usage-promotion" : promoUrl
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: promoActive ? "bolt.fill" : "clock")
                    .font(.system(size: 10))
                    .foregroundStyle(promoActive ? theme.highlightAccent : theme.textPrimary)
                if promoActive {
                    let activeLabel = promoShortLabel == "⚡" ? "Promo Active" : "\(promoShortLabel) Active"
                    Text(activeLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.highlightAccent)
                    if !promoCountdown.isEmpty {
                        Text("· \(promoCountdown)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                    }
                } else {
                    let endsLabel = promoShortLabel == "⚡" || promoShortLabel.isEmpty ? "Promo" : promoShortLabel.lowercased()
                    Text("\(endsLabel) ends in \(promoCountdown)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.textPrimary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(promoActive ? theme.highlightAccent.opacity(0.15) : theme.cardBackground)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(promoActive ? theme.highlightAccent.opacity(0.4) : theme.borderColor, lineWidth: 1))
            .cornerRadius(6)
        }
        .buttonStyle(.borderless)
        .help(promoDescription)
    }
}

// MARK: - Loading Placeholder

private struct LoadingPlaceholder: View {
    let theme: PopoverTheme

    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("Fetching usage data…")
                .font(.system(size: 12))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }
}

// MARK: - Dashboard Content

private struct DashboardContent: View {
    let theme: PopoverTheme
    @ObservedObject var viewModel: SondeViewModel
    @Binding var showProjects: Bool
    let showCosts: Bool

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                MainCard(
                    theme: theme,
                    sessions: viewModel.allSessions,
                    activeCount: viewModel.activeSessions.count,
                    fiveHourUtil: viewModel.fiveHourUtil,
                    fiveHourReset: viewModel.fiveHourReset,
                    sevenDayUtil: viewModel.sevenDayUtil,
                    sevenDayReset: viewModel.sevenDayReset,
                    extraUsageEnabled: viewModel.extraUsageEnabled,
                    extraUsageUtil: viewModel.extraUsageUtil,
                    paceTier: viewModel.paceTier,
                    usageHistory: viewModel.usageHistory,
                    pacePredict: viewModel.pacePredict,
                    modelName: viewModel.session.modelName,
                    codeVelocity: viewModel.session.codeVelocity,
                    costPerModel: viewModel.session.costPerModel,
                    showCosts: showCosts,
                    onTap: { showProjects = true }
                )

                // Session activity summary
                SessionActivityCard(
                    theme: theme,
                    sessions: viewModel.allSessions,
                    session: viewModel.session,
                    showCosts: showCosts
                )

                UsageCard(
                    theme: theme,
                    dailyHistory: viewModel.dailyHistory,
                    usageHistory: viewModel.usageHistory,
                    fiveHourUtil: viewModel.fiveHourUtil,
                    sevenDayUtil: viewModel.sevenDayUtil
                )

                if showCosts {
                    DailySpendCard(
                        theme: theme,
                        claudeCost: viewModel.dailyClaudeCost,
                        codexCost: viewModel.dailyCodexCost,
                        budget: viewModel.dailyBudget,
                        budgetExceeded: viewModel.budgetExceeded,
                        dailyHistory: viewModel.dailyHistory,
                        otherProjects: viewModel.session.otherProjects,
                        showCosts: showCosts,
                        onSetBudget: { viewModel.dailyBudget = $0 }
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Main Card

private struct MainCard: View {
    let theme: PopoverTheme
    let sessions: [SessionData]
    let activeCount: Int
    let fiveHourUtil: Double?
    let fiveHourReset: String?
    let sevenDayUtil: Double?
    let sevenDayReset: String?
    let extraUsageEnabled: Bool
    let extraUsageUtil: Double?
    let paceTier: PaceTier
    let usageHistory: [Double]
    let pacePredict: String?
    let modelName: String?
    let codeVelocity: String?
    let costPerModel: [ModelCostEntry]
    let showCosts: Bool
    let onTap: () -> Void

    @State private var gaugeAppeared = false
    @State private var isHovered = false

    private var sessionCount: Int { max(sessions.count, activeCount) }
    private var totalCost: Double { sessions.reduce(0.0) { $0 + ($1.sessionCost ?? 0) } }
    private var totalTokens: Int {
        sessions.reduce(0) { $0 + ($1.totalInputTokens ?? 0) + ($1.totalOutputTokens ?? 0) }
    }
    private var totalLines: Int { sessions.reduce(0) { $0 + ($1.linesAdded ?? 0) } }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Section header
                HStack {
                    Text("Usage")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(theme.textSecondary.opacity(0.7))
                    Spacer()
                }

                // Hero: Circle gauges
                HStack(spacing: 0) {
                    if let fh = fiveHourUtil {
                        CircleGauge(
                            theme: theme,
                            label: "5h",
                            util: gaugeAppeared ? fh : 0,
                            reset: fiveHourReset
                        )
                    }

                    // Center: cost + sessions + sparkline + code velocity
                    VStack(spacing: 4) {
                        if showCosts {
                            Text(totalCost > 0 ? String(format: "$%.2f", totalCost) : "--")
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .foregroundStyle(costColor)
                                .shadow(color: theme.textGlow ?? .clear, radius: 3)
                                .contentTransition(.numericText())
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "terminal")
                                .font(.system(size: 10))
                            Text("\(sessionCount)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(theme.textSecondary.opacity(0.3))
                        }
                        .foregroundStyle(theme.textSecondary)

                        if usageHistory.count > 2 {
                            SparklineView(data: usageHistory)
                                .frame(width: 64, height: 16)
                        }

                        // Code velocity
                        if let velocity = codeVelocity {
                            HStack(spacing: 3) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(theme.highlightAccent)
                                Text(velocity)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(theme.highlightAccent)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    if let sd = sevenDayUtil {
                        CircleGauge(
                            theme: theme,
                            label: "7d",
                            util: gaugeAppeared ? sd : 0,
                            reset: sevenDayReset
                        )
                    }
                }

                // Stats row
                HStack(spacing: 10) {
                    statLabel(value: formatTokens(totalTokens), unit: "tokens")
                    if totalLines > 0 {
                        statLabel(value: "+\(totalLines)", unit: "lines")
                    }
                    if showCosts, let cpl = costPerLineValue {
                        statLabel(value: cpl, unit: "/line")
                    }
                    if let cache = cacheHitRatio {
                        statLabel(value: cache, unit: "cache")
                    }
                    Spacer()
                    // Pace tier badge
                    HStack(spacing: 3) {
                        Image(systemName: paceTier.icon)
                            .font(.system(size: 10))
                            .foregroundStyle(paceTier.swiftColor)
                        Text(paceTier.rawValue)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                    }
                }

                // Per-model cost breakdown
                if showCosts && costPerModel.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(costPerModel.sorted(by: { $0.cost > $1.cost }), id: \.model) { entry in
                            ModelPill(name: entry.model, theme: theme, cost: entry.cost, compact: true)
                        }
                        Spacer()
                    }
                }

                // Extra usage bar (if enabled)
                if extraUsageEnabled, let util = extraUsageUtil {
                    UsageBar(theme: theme, label: "Extra", util: util, reset: nil)
                }

                // Hint
                if let predict = pacePredict,
                   paceTier == .elevated || paceTier == .hot || paceTier == .critical || paceTier == .runaway {
                    Label(predict, systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                }
            }
            .padding(12)
            .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.borderColor, lineWidth: 1))
            .shadow(color: theme.cardGlow ?? .clear, radius: 4)
            .scaleEffect(isHovered ? 1.005 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                gaugeAppeared = true
            }
        }
    }

    // Efficiency metrics (aggregated from all sessions)
    private var costPerLineValue: String? {
        guard totalLines > 0, totalCost > 0 else { return nil }
        return String(format: "$%.2f", totalCost / Double(totalLines))
    }

    private var cacheHitRatio: String? {
        let totalRead = sessions.reduce(0) { $0 + $1.cacheReadTokens }
        let totalWrite = sessions.reduce(0) { $0 + $1.cacheWriteTokens }
        let total = totalRead + totalWrite
        guard total > 0 else { return nil }
        return "\(Int(Double(totalRead) / Double(total) * 100))%"
    }

    private var costColor: Color {
        if totalCost >= 10.0 { return theme.costHighColor }
        if totalCost >= 5.0 { return theme.costMedColor }
        return theme.textPrimary
    }

    private func statLabel(value: String, unit: String) -> some View {
        HStack(spacing: 2) {
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.textPrimary)
            Text(unit)
                .font(.system(size: 10))
                .foregroundStyle(theme.textSecondary.opacity(0.5))
        }
    }

    private func formatTokens(_ tokens: Int) -> String {
        if tokens >= 1_000_000 { return String(format: "%.1fM", Double(tokens) / 1_000_000) }
        if tokens >= 1000 { return String(format: "%.0fk", Double(tokens) / 1000) }
        return "\(tokens)"
    }
}

// MARK: - Usage Bar (visual progress bar replacing raw percentages)

private struct UsageBar: View {
    let theme: PopoverTheme
    let label: String
    let util: Double
    let reset: String?

    private var barColor: Color {
        if util >= 80 { return .red }
        if util >= 60 { return .orange }
        if util >= 40 { return .yellow }
        return theme.lowUtilColor
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.textSecondary.opacity(0.6))
                .frame(width: 30, alignment: .trailing)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(theme.borderColor)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor)
                        .frame(width: max(0, geo.size.width * min(util, 100) / 100), height: 4)
                }
            }
            .frame(height: 4)

            Text("\(Int(util))%")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(barColor)
                .frame(width: 30, alignment: .leading)
                .contentTransition(.numericText())

            if let reset {
                Text(TimeFormatting.formatResetCountdown(from: reset))
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textSecondary.opacity(0.5))
            }
        }
    }
}

// MARK: - Circle Gauge

private struct CircleGauge: View {
    let theme: PopoverTheme
    let label: String
    let util: Double
    let reset: String?

    private let gaugeSize: CGFloat = 90
    private let lineWidth: CGFloat = 6

    private var remaining: Int { max(0, Int(100 - util)) }

    private var gaugeColor: Color {
        if util >= 80 { return .red }
        if util >= 60 { return .orange }
        if util >= 40 { return .yellow }
        return theme.lowUtilColor
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Track
                Circle()
                    .stroke(theme.borderColor, lineWidth: lineWidth)

                // Fill
                Circle()
                    .trim(from: 0, to: min(util, 100) / 100)
                    .stroke(gaugeColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.0), value: util)

                // Center label
                VStack(spacing: 1) {
                    Text("\(remaining)%")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(gaugeColor)
                        .contentTransition(.numericText())
                        .shadow(color: theme.textGlow ?? .clear, radius: 3)
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.textSecondary.opacity(0.6))
                }
            }
            .frame(width: gaugeSize, height: gaugeSize)

            // Reset countdown
            if let reset {
                Text(TimeFormatting.formatResetCountdown(from: reset))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(theme.textSecondary.opacity(0.5))
            }
        }
    }
}

// MARK: - Session Activity Card

private struct SessionActivityCard: View {
    let theme: PopoverTheme
    let sessions: [SessionData]
    let session: SessionData
    let showCosts: Bool

    private var totalCacheRead: Int { sessions.reduce(0) { $0 + $1.cacheReadTokens } }
    private var totalCacheWrite: Int { sessions.reduce(0) { $0 + $1.cacheWriteTokens } }
    private var cacheTotal: Int { totalCacheRead + totalCacheWrite }
    private var cacheRatio: Double {
        guard cacheTotal > 0 else { return 0 }
        return Double(totalCacheRead) / Double(cacheTotal) * 100
    }
    private var totalInput: Int { sessions.reduce(0) { $0 + ($1.totalInputTokens ?? 0) } }
    private var totalOutput: Int { sessions.reduce(0) { $0 + ($1.totalOutputTokens ?? 0) } }
    private var ioRatio: Double {
        guard totalOutput > 0 else { return 0 }
        return Double(totalInput) / Double(totalOutput)
    }
    private var totalLinesAdded: Int { sessions.reduce(0) { $0 + ($1.linesAdded ?? 0) } }
    private var totalLinesRemoved: Int { sessions.reduce(0) { $0 + ($1.linesRemoved ?? 0) } }
    private var netLines: Int { totalLinesAdded - totalLinesRemoved }
    private var totalMessages: Int { sessions.reduce(0) { $0 + $1.messageCount } }
    private var totalWebSearches: Int { sessions.reduce(0) { $0 + $1.webSearchCount } }
    private var totalWebFetches: Int { sessions.reduce(0) { $0 + $1.webFetchCount } }

    var body: some View {
        let hasActivity = cacheTotal > 0 || totalMessages > 0 || totalLinesAdded > 0

        if hasActivity {
            VStack(spacing: 8) {
                // Section header
                HStack {
                    Text("Activity")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(theme.textSecondary.opacity(0.7))
                    Spacer()
                }

                // Code changes bar (added vs removed, visual ratio)
                if totalLinesAdded > 0 || totalLinesRemoved > 0 {
                    VStack(spacing: 3) {
                        HStack(spacing: 4) {
                            Text("Code")
                                .font(.system(size: 9))
                                .foregroundStyle(theme.textSecondary.opacity(0.5))
                            Spacer()
                            Text("+\(totalLinesAdded)")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.green)
                            Text("/")
                                .font(.system(size: 9))
                                .foregroundStyle(theme.textSecondary.opacity(0.3))
                            Text("-\(totalLinesRemoved)")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.red)
                            Text("=")
                                .font(.system(size: 9))
                                .foregroundStyle(theme.textSecondary.opacity(0.3))
                            Text("\(netLines > 0 ? "+" : "")\(netLines) net")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(netLines >= 0 ? .green : .red)
                        }
                        // Visual ratio bar: green (added) vs red (removed)
                        let total = max(totalLinesAdded + totalLinesRemoved, 1)
                        GeometryReader { geo in
                            HStack(spacing: 1) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.green.opacity(0.7))
                                    .frame(width: geo.size.width * CGFloat(totalLinesAdded) / CGFloat(total))
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.red.opacity(0.7))
                                    .frame(width: geo.size.width * CGFloat(totalLinesRemoved) / CGFloat(total))
                            }
                        }
                        .frame(height: 4)
                    }
                }

                // Activity counters row
                HStack(spacing: 0) {
                    if totalMessages > 0 {
                        miniStatView(icon: "bubble.left.fill", value: "\(totalMessages)", label: "msgs")
                    }
                    if let apiWait = session.apiWaitRatio {
                        miniStatView(icon: "hourglass", value: apiWait, label: "wait")
                    }
                    if sessions.count > 1 {
                        miniStatView(icon: "rectangle.stack", value: "\(sessions.count)", label: "active")
                    }
                }

                // Multi-session breakdown (when >1 session)
                if sessions.count > 1 {
                    VStack(spacing: 3) {
                        ForEach(sessions.prefix(3), id: \.sessionId) { s in
                            HStack(spacing: 6) {
                                Text(s.projectName ?? "Unknown")
                                    .font(.system(size: 10))
                                    .foregroundStyle(theme.textPrimary)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if let model = s.modelName {
                                    Text(shortModel(model))
                                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(theme.modelPillText)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(theme.modelColor(for: model), in: RoundedRectangle(cornerRadius: 3))
                                }
                                if showCosts {
                                    Text(s.formattedCost)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(theme.textSecondary)
                                }
                                Text(s.formattedDuration)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(theme.textSecondary.opacity(0.6))
                            }
                        }
                    }
                }
            }
            .padding(10)
            .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.borderColor, lineWidth: 1))
            .shadow(color: theme.cardGlow ?? .clear, radius: 4)
        }
    }

    private func miniStatView(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(theme.textSecondary.opacity(0.5))
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.textPrimary)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(theme.textSecondary.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    private func shortModel(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("opus") { return "Opus" }
        if lower.contains("haiku") { return "Haiku" }
        if lower.contains("sonnet") { return "Sonnet" }
        return name
    }
}

// MARK: - Usage Card

private struct UsageCard: View {
    let theme: PopoverTheme
    let dailyHistory: [DailySnapshot]
    let usageHistory: [Double]
    let fiveHourUtil: Double?
    let sevenDayUtil: Double?

    /// Build 7-day bar data: peak 5h utilization per day.
    /// Pads with zeros for missing days so we always show 7 bars.
    private var weekData: [(label: String, value: Double, isToday: Bool)] {
        let cal = Calendar.current
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "EEE"

        let today = cal.startOfDay(for: Date())
        var result: [(label: String, value: Double, isToday: Bool)] = []

        for offset in (-6...0) {
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            let key = dateFmt.string(from: day)
            let label = dayFmt.string(from: day)
            let isToday = offset == 0

            if let snap = dailyHistory.first(where: { $0.date == key }) {
                result.append((label, snap.fiveHourPeak, isToday))
            } else if isToday, let util = fiveHourUtil {
                result.append((label, util, true))
            } else {
                result.append((label, 0, isToday))
            }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Usage")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.textSecondary.opacity(0.7))
                Spacer()
                if let util = fiveHourUtil {
                    Text("5h: \(Int(util))%")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textSecondary.opacity(0.7))
                }
                if let util = sevenDayUtil {
                    Text("7d: \(Int(util))%")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textSecondary.opacity(0.7))
                }
            }

            let data = weekData
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(data.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 2) {
                        GeometryReader { geo in
                            let ratio = min(day.value / 100.0, 1.0)
                            VStack {
                                Spacer()
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(barColor(day.value, isToday: day.isToday))
                                    .frame(height: max(2, geo.size.height * CGFloat(ratio)))
                            }
                        }
                        Text(day.label)
                            .font(.system(size: 7))
                            .foregroundStyle(day.isToday ? theme.textPrimary : theme.textSecondary.opacity(0.4))
                    }
                }
            }
            .frame(height: 48)
        }
        .padding(10)
        .background(theme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func barColor(_ value: Double, isToday: Bool) -> Color {
        if value >= 85 { return .red }
        if value >= 60 { return .orange }
        if isToday { return theme.lowUtilColor }
        return theme.lowUtilColor.opacity(0.6)
    }
}

private struct UsageSparkline: View {
    let data: [Double]
    let theme: PopoverTheme

    var body: some View {
        GeometryReader { geo in
            let maxVal = max(data.max() ?? 100, 100)
            let w = geo.size.width
            let h = geo.size.height
            let step = data.count > 1 ? w / CGFloat(data.count - 1) : w

            // Fill area
            Path { path in
                path.move(to: CGPoint(x: 0, y: h))
                for (i, val) in data.enumerated() {
                    let x = CGFloat(i) * step
                    let y = h - (CGFloat(val / maxVal) * h)
                    if i == 0 {
                        path.addLine(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                path.addLine(to: CGPoint(x: CGFloat(data.count - 1) * step, y: h))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [sparkColor.opacity(0.3), sparkColor.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Line
            Path { path in
                for (i, val) in data.enumerated() {
                    let x = CGFloat(i) * step
                    let y = h - (CGFloat(val / maxVal) * h)
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(sparkColor, lineWidth: 1.5)
        }
    }

    private var sparkColor: Color {
        let peak = data.max() ?? 0
        if peak >= 85 { return .red }
        if peak >= 60 { return .orange }
        return theme.lowUtilColor
    }
}

// MARK: - Daily Spend Card

private struct DailySpendCard: View {
    let theme: PopoverTheme
    let claudeCost: Double
    let codexCost: Double
    let budget: Double
    let budgetExceeded: Bool
    let dailyHistory: [DailySnapshot]
    let otherProjects: [ProjectCost]
    let showCosts: Bool
    let onSetBudget: (Double) -> Void

    @State private var showBudgetSheet = false
    @State private var budgetInput = ""

    private var total: Double { claudeCost + codexCost }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Spend")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.textSecondary.opacity(0.7))
                Spacer()
            }

            HStack(spacing: 0) {
                Text("Today")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textSecondary.opacity(0.6))

                Spacer()

                if showCosts {
                    if budgetExceeded {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                            .padding(.trailing, 4)
                    }

                    Text(String(format: "$%.2f", total))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(total >= 10 ? theme.costHighColor : total >= 5 ? theme.costMedColor : theme.textPrimary)
                        .contentTransition(.numericText())

                    Button {
                        budgetInput = budget > 0 ? String(format: "%.0f", budget) : ""
                        showBudgetSheet = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.borderless)
                    .padding(.leading, 6)
                    .popover(isPresented: $showBudgetSheet, arrowEdge: .trailing) {
                        BudgetPopover(
                            budgetInput: $budgetInput,
                            showSheet: $showBudgetSheet,
                            currentBudget: budget,
                            onSetBudget: onSetBudget
                        )
                    }
                }
            }

            // Cost breakdown (only if codex is used)
            if showCosts && codexCost > 0 {
                HStack(spacing: 12) {
                    HStack(spacing: 2) {
                        Text(String(format: "$%.2f", claudeCost))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(theme.textSecondary)
                        Text("Claude")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.textSecondary.opacity(0.5))
                    }
                    HStack(spacing: 2) {
                        Text(String(format: "$%.2f", codexCost))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(theme.textSecondary)
                        Text("Codex")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.textSecondary.opacity(0.5))
                    }
                    Spacer()
                }
            }

            // Per-project costs (up to 3)
            if showCosts && !otherProjects.isEmpty {
                VStack(spacing: 3) {
                    ForEach(otherProjects.prefix(3), id: \.name) { project in
                        HStack(spacing: 4) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(theme.textSecondary.opacity(0.5))
                            Text(project.name)
                                .font(.system(size: 10))
                                .foregroundStyle(theme.textSecondary)
                                .lineLimit(1)
                            Spacer()
                            Text(String(format: "$%.2f", project.cost))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(theme.textPrimary)
                        }
                    }
                }
                .padding(.top, 2)
            }

            // Budget bar
            if showCosts && budget > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme.borderColor)
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(budgetExceeded ? Color.red : theme.lowUtilColor)
                            .frame(width: max(0, geo.size.width * min(total / budget, 1.0)), height: 3)
                    }
                }
                .frame(height: 3)
            }

            // 14-day usage trend
            if dailyHistory.count >= 3 {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("14-day spend")
                            .font(.system(size: 9))
                            .foregroundStyle(theme.textSecondary.opacity(0.5))
                        Spacer()
                        if showCosts {
                            Text(String(format: "$%.0f avg", dailyHistory.suffix(14).map(\.dailyCost).reduce(0, +) / Double(min(dailyHistory.count, 14))))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(theme.textSecondary.opacity(0.5))
                        }
                    }
                    DailyCostChart(data: Array(dailyHistory.suffix(14).map(\.dailyCost)), theme: theme)
                        .frame(height: 36)
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.borderColor, lineWidth: 1))
        .shadow(color: theme.cardGlow ?? .clear, radius: 4)
    }
}

// MARK: - Daily Cost Chart (area sparkline)

private struct DailyCostChart: View {
    let data: [Double]
    let theme: PopoverTheme

    var body: some View {
        Canvas { context, size in
            guard data.count > 1 else { return }
            let maxVal = max(data.max() ?? 1, 1)
            let stepX = size.width / CGFloat(data.count - 1)
            let inset: CGFloat = 2

            // Build line path
            var linePath = Path()
            for (i, val) in data.enumerated() {
                let x = CGFloat(i) * stepX
                let y = inset + (size.height - inset * 2) * (1 - CGFloat(val / maxVal))
                if i == 0 { linePath.move(to: CGPoint(x: x, y: y)) }
                else { linePath.addLine(to: CGPoint(x: x, y: y)) }
            }

            // Fill path (close to bottom)
            var fillPath = linePath
            fillPath.addLine(to: CGPoint(x: CGFloat(data.count - 1) * stepX, y: size.height))
            fillPath.addLine(to: CGPoint(x: 0, y: size.height))
            fillPath.closeSubpath()

            let gradient = Gradient(colors: [
                theme.headerAccent.opacity(0.25),
                theme.headerAccent.opacity(0.05),
            ])
            context.fill(fillPath, with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: size.height)
            ))

            context.stroke(linePath, with: .color(theme.headerAccent.opacity(0.6)), lineWidth: 1.5)

            // Dots on each day
            for (i, val) in data.enumerated() {
                let x = CGFloat(i) * stepX
                let y = inset + (size.height - inset * 2) * (1 - CGFloat(val / maxVal))
                let dot = CGRect(x: x - 2, y: y - 2, width: 4, height: 4)
                context.fill(Path(ellipseIn: dot), with: .color(theme.headerAccent.opacity(0.8)))
            }
        }
    }
}

// MARK: - Budget Popover

private struct BudgetPopover: View {
    @Binding var budgetInput: String
    @Binding var showSheet: Bool
    let currentBudget: Double
    let onSetBudget: (Double) -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("Daily Budget")
                .font(.body)
                .fontWeight(.semibold)
            TextField("Amount ($)", text: $budgetInput)
                .textFieldStyle(.roundedBorder)
                .frame(width: 140)
            HStack(spacing: 8) {
                if currentBudget > 0 {
                    Button("Clear") {
                        onSetBudget(0)
                        showSheet = false
                    }
                    .font(.caption)
                }
                Button("Save") {
                    if let val = Double(budgetInput), val > 0 {
                        onSetBudget(val)
                    }
                    showSheet = false
                }
                .font(.caption)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(14)
    }
}

// MARK: - Footer Bar (clean, minimal)

private struct FooterBar: View {
    let theme: PopoverTheme
    let onRefresh: () -> Void
    let onExport: () -> Void
    let onCopySummary: () -> Void
    let onToggleWatcher: () -> Void
    @Binding var themeName: String
    @Binding var showCosts: Bool

    @State private var spinning = false
    @State private var showSettings = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.linear(duration: 0.5)) { spinning = true }
                onRefresh()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { spinning = false }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.headerAccent)
                    .rotationEffect(.degrees(spinning ? 360 : 0))
                    .animation(.linear(duration: 0.5), value: spinning)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("r", modifiers: .command)
            .help("Refresh (Cmd+R)")

            Button(action: onCopySummary) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.headerAccent)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("c", modifiers: .command)
            .help("Copy summary (Cmd+C)")

            Button(action: onExport) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.headerAccent)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("e", modifiers: .command)
            .help("Export JSON (Cmd+E)")

            Button(action: onToggleWatcher) {
                Image(systemName: "pip")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.headerAccent)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("p", modifiers: .command)
            .help("Toggle watcher (Cmd+P)")

            // Show costs toggle
            Button {
                showCosts.toggle()
            } label: {
                Image(systemName: showCosts ? "dollarsign.circle.fill" : "dollarsign.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(showCosts ? theme.headerAccent : theme.footerText)
            }
            .buttonStyle(.borderless)
            .help(showCosts ? "Hide costs" : "Show costs")

            // Theme picker
            Menu {
                ForEach(PopoverTheme.allCases, id: \.rawValue) { t in
                    Button {
                        themeName = t.rawValue
                    } label: {
                        HStack {
                            if t.rawValue == themeName {
                                Circle()
                                    .fill(t.swatchColor)
                                    .frame(width: 8, height: 8)
                            }
                            Text(t.rawValue)
                        }
                    }
                }
            } label: {
                Image(systemName: "paintpalette")
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 11))
            }
            .menuIndicator(.hidden)
            .buttonStyle(.borderless)
            .tint(theme.headerAccent)
            .help("Theme")

            // Settings
            Button { showSettings.toggle() } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.headerAccent)
            }
            .buttonStyle(.borderless)
            .help("Settings")
            .popover(isPresented: $showSettings, arrowEdge: .top) {
                SettingsView(
                    theme: theme,
                    showCosts: $showCosts,
                    themeName: $themeName
                )
            }

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.headerAccent)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
