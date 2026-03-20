import AppKit
import ServiceManagement
import SondeCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Theme

private func hex(_ hex: UInt) -> Color {
    Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
}

// Shared color constants — single source of truth
enum SondeColors {
    static let brandGreen = Color(red: 0.114, green: 0.620, blue: 0.459)
    static let settingsLightBlue = Color(red: 0.15, green: 0.2, blue: 0.65)
    static let chipGridDarkBg = Color(white: 0.12)
}

enum PopoverTheme: String, CaseIterable {
    case liquidGlass = "Liquid Glass"
    case system = "System"
    case sonde = "Sonde"
    case terminal = "Terminal"
    case cyberpunk = "Cyberpunk"
    case synthwave = "Synthwave"
    case solarFlare = "Solarflare"

    private static let phosphor = Color(red: 0.2, green: 1.0, blue: 0.2)
    private static let phosphorDim = Color(red: 0.15, green: 0.6, blue: 0.15)
    private static let phosphorFaint = Color(red: 0.12, green: 0.45, blue: 0.12)
    private static let amber = Color(red: 1.0, green: 0.85, blue: 0.3)
    private static let amberDim = Color(red: 0.75, green: 0.6, blue: 0.2)
    private static let cyan = Color(red: 0.3, green: 0.9, blue: 0.9)

    // MARK: Colors

    /// Whether this theme is currently in dark mode.
    /// System theme reads from AppStorage; all others are inherently dark.
    var isDark: Bool {
        switch self {
        case .system:
            let mode = UserDefaults.standard.string(forKey: "appearanceMode") ?? "auto"
            switch mode {
            case "light": return false
            case "dark": return true
            default:
                // Auto: check macOS appearance
                return NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            }
        case .sonde:
            // Safe to read UserDefaults.standard directly (not @AppStorage) — no cycle
            let mode = UserDefaults.standard.string(forKey: "appearanceMode") ?? "auto"
            switch mode {
            case "light": return false
            case "dark": return true
            default:
                return NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            }
        case .liquidGlass: return true
        default: return true
        }
    }

    var cardBackground: Color {
        switch self {
        case .liquidGlass: Color.primary.opacity(0.04)
        case .terminal: Color(red: 0.04, green: 0.06, blue: 0.04)
        case .cyberpunk: hex(0x141726)
        case .synthwave: hex(0x2D1B4E)
        case .solarFlare: hex(0x1A0A12)
        case .system: isDark ? hex(0x2C2C2E) : .white
        case .sonde: hex(0x313244)
        }
    }

    var headerAccent: Color {
        switch self {
        case .liquidGlass: .blue
        case .terminal: Self.amber
        case .cyberpunk: hex(0x18E0FF)
        case .synthwave: hex(0xFF2975)
        case .solarFlare: hex(0xFF6B2B)
        case .system: isDark ? hex(0x0A84FF) : hex(0x007AFF)
        case .sonde: hex(0x74C7EC)
        }
    }

    var textPrimary: Color {
        switch self {
        case .liquidGlass: .primary
        case .terminal: Self.phosphor
        case .cyberpunk: hex(0xE0E0E0)
        case .synthwave: hex(0xF0E6FF)
        case .solarFlare: hex(0xFFE0C8)
        case .system: isDark ? Color(white: 0.95) : Color(white: 0.0)
        case .sonde: hex(0xCDD6F4)
        }
    }

    var textSecondary: Color {
        switch self {
        case .liquidGlass: .secondary
        case .terminal: Self.amberDim
        case .cyberpunk: hex(0x8FA4B8)
        case .synthwave: hex(0xC4A0E8)
        case .solarFlare: hex(0xC08050)
        case .system: isDark ? hex(0x98989D) : hex(0x3C3C43).opacity(0.6)
        case .sonde: hex(0xA6ADC8)
        }
    }

    var costHighColor: Color {
        switch self {
        case .terminal: Color(red: 1.0, green: 0.15, blue: 0.15)
        case .system: isDark ? hex(0xFF6961) : hex(0xE5484D)
        case .sonde: hex(0xF38BA8)
        default: .red
        }
    }

    var costMedColor: Color {
        switch self {
        case .terminal: Self.amber
        case .system: isDark ? hex(0xF5A623) : hex(0xD97706)
        case .sonde: hex(0xFAB387)
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
        case .system: isDark ? Color.white.opacity(0.12) : hex(0xC6C6C8).opacity(0.8)
        case .sonde: hex(0x45475A).opacity(0.5)
        }
    }

    var popoverBackground: Color {
        switch self {
        case .liquidGlass: .clear
        case .terminal: Color(red: 0.02, green: 0.02, blue: 0.04)
        case .cyberpunk: hex(0x0B0C10)
        case .synthwave: hex(0x1A1025)
        case .solarFlare: hex(0x0D0208)
        case .system: isDark ? hex(0x1C1C1E) : hex(0xF2F2F7)
        case .sonde: hex(0x1E1E2E)
        }
    }

    var dividerColor: Color {
        switch self {
        case .liquidGlass: Color.primary.opacity(0.1)
        case .terminal: Self.phosphor.opacity(0.12)
        case .system: isDark ? Color.white.opacity(0.08) : hex(0xC6C6C8).opacity(0.6)
        case .sonde: hex(0x45475A).opacity(0.3)
        default: borderColor
        }
    }

    var footerText: Color {
        switch self {
        case .liquidGlass: .secondary
        case .terminal: Self.phosphorFaint
        case .system: isDark ? hex(0x98989D) : hex(0x3C3C43).opacity(0.6)
        case .sonde: hex(0x6C7086)
        default: textSecondary.opacity(0.7)
        }
    }

    var textGlow: Color? {
        switch self {
        case .terminal: Self.phosphor.opacity(0.6)
        case .cyberpunk: hex(0x18E0FF).opacity(0.5)
        case .synthwave: hex(0xFF2975).opacity(0.5)
        case .solarFlare: hex(0xFF6B2B).opacity(0.5)
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
        case .sonde: hex(0xCBA6F7).opacity(0.06)
        default: nil
        }
    }

    var highlightAccent: Color {
        switch self {
        case .terminal: Self.cyan
        case .system: isDark ? hex(0x64D2FF) : hex(0x5B8DEF)
        case .sonde: hex(0x89DCEB)
        default: headerAccent
        }
    }

    var lowUtilColor: Color {
        switch self {
        case .terminal: Self.phosphor
        case .system: isDark ? hex(0x30D158) : hex(0x2DB87B)
        case .sonde: hex(0xA6E3A1)
        default: .green
        }
    }

    var medUtilColor: Color {
        switch self {
        case .terminal: Self.amber
        case .system: isDark ? hex(0x64D2FF) : hex(0x5B8DEF)
        case .sonde: hex(0xF9E2AF)
        default: .orange
        }
    }

    var highUtilColor: Color {
        switch self {
        case .terminal: Color(red: 1.0, green: 0.15, blue: 0.15)
        case .system: isDark ? hex(0xFF6961) : hex(0xE5484D)
        case .sonde: hex(0xF38BA8)
        default: .red
        }
    }

    var swatchColor: Color {
        switch self {
        case .sonde: hex(0xCBA6F7)
        default: headerAccent
        }
    }

    // Model pill colors
    var modelOpusColor: Color {
        switch self {
        case .terminal: Self.amber
        case .system: isDark ? hex(0xBF5AF2) : hex(0xAF52DE)
        case .sonde: hex(0xCBA6F7)
        default: Color(red: 0.55, green: 0.25, blue: 0.85)
        }
    }

    var modelSonnetColor: Color {
        switch self {
        case .terminal: Self.cyan
        case .system: isDark ? hex(0x0A84FF) : hex(0x007AFF)
        case .sonde: hex(0xEBBE64)
        default: Color(red: 0.2, green: 0.45, blue: 0.9)
        }
    }

    var modelHaikuColor: Color {
        switch self {
        case .terminal: Self.phosphorDim
        case .sonde: hex(0x181825)
        default: Color(red: 0.0, green: 0.65, blue: 0.55)
        }
    }

    var modelPillText: Color {
        switch self {
        case .terminal: Color(red: 0.08, green: 0.08, blue: 0.06)
        case .sonde: hex(0x1E1E2E)
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

// MARK: - Card Edge Modifier

private struct CardEdgeModifier: ViewModifier {
    let theme: PopoverTheme
    func body(content: Content) -> some View {
        switch theme {
        case .system, .sonde:
            content.shadow(color: Color.black.opacity(0.15), radius: 8, y: 3)
        case .liquidGlass:
            content.overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
        default:
            content
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.borderColor, lineWidth: 1))
                .shadow(color: theme.cardGlow ?? .clear, radius: 4)
        }
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

    private var shortName: String {
        let lower = name.lowercased()
        if lower.contains("opus") { return "Opus" }
        if lower.contains("sonnet") { return "Sonnet" }
        if lower.contains("haiku") { return "Haiku" }
        return String(name.prefix(10))
    }

    var body: some View {
        Text(shortName)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(theme.modelPillText)
            .glowText(theme)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(theme.modelColor(for: name), in: RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Pulse Dot

private struct PulseDot: View {
    var theme: PopoverTheme = .system
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(theme.lowUtilColor)
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
        if pct >= 80 { return theme.highUtilColor }
        if pct >= 60 { return theme.medUtilColor }
        return theme.lowUtilColor
    }

    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(theme.borderColor)
                        .frame(height: 4)
                    if theme.textGlow != nil {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor)
                            .frame(width: max(0, geo.size.width * min(pct, 100) / 100), height: 4)
                            .blur(radius: 3)
                            .opacity(0.5)
                    }
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
                    .glowText(theme)
                    .contentTransition(.numericText())
                Text("  \(formatK(tokensUsed))/\(formatK(windowSize))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(theme.textSecondary.opacity(0.6))
                    .glowText(theme, radius: 2)
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

    var body: some View {
        VStack(spacing: 6) {
            // Top row: model pill, git branch, timer, pulse dot
            HStack(spacing: 8) {
                if let model = session.modelName {
                    HStack(spacing: 4) {
                        ModelPill(name: model, theme: theme)
                        if let window = session.contextWindowSize, window > 0 {
                            Text(formatWindowSize(window))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(theme.textSecondary.opacity(0.6))
                                .glowText(theme, radius: 2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(theme.borderColor, in: RoundedRectangle(cornerRadius: 3))
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                if session.projectName != nil || session.gitBranch != nil {
                    VStack(alignment: .leading, spacing: 1) {
                        if let project = session.projectName {
                            HStack(spacing: 3) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 8))
                                Text(project)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(theme.textPrimary)
                            .glowText(theme)
                        }
                        if let branch = session.gitBranch {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.system(size: 8))
                                Text(branch)
                                    .font(.system(size: 10, design: .monospaced))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(theme.textSecondary)
                            .glowText(theme, radius: 2)
                        }
                    }
                }

                Spacer()

                Text(liveTimer)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                    .glowText(theme, radius: 2)
                    .contentTransition(.numericText())

                PulseDot(theme: theme)
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

    private func formatWindowSize(_ tokens: Int) -> String {
        if tokens >= 1_000_000 { return "\(tokens / 1_000_000)M ctx" }
        if tokens >= 1000 { return "\(tokens / 1000)k ctx" }
        return "\(tokens) ctx"
    }
}

// MARK: - Popover Root

struct PopoverView: View {
    @ObservedObject var viewModel: SondeViewModel
    @AppStorage("popoverTheme") private var themeName: String = PopoverTheme.system.rawValue
    @AppStorage("appearanceMode") private var appearanceMode: String = "auto"
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var showProjects = false
    @State private var showSettings = false
    @State private var dismissedBanners: Set<String> = []

    private var theme: PopoverTheme {
        PopoverTheme(rawValue: themeName) ?? .system
    }

    /// Whether the current theme should render in dark mode.
    /// For System/Sonde themes, uses the live SwiftUI colorScheme environment
    /// instead of reading NSApp appearance (which doesn't update reactively).
    private var isDark: Bool {
        guard theme == .system || theme == .sonde else { return true }
        switch appearanceMode {
        case "light": return false
        case "dark": return true
        default: return systemColorScheme == .dark
        }
    }

    private var hasActiveSession: Bool {
        viewModel.session.modelName != nil
    }

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil // auto — follows system
        }
    }

    /// Compute active status banner conditions (reappear on refresh if not dismissed).
    private var activeBannerConditions: [StatusBannerCondition] {
        var conditions: [StatusBannerCondition] = []

        // Check Claude Code installed
        let homeDir: URL = {
            if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
                return URL(fileURLWithPath: String(cString: dir))
            }
            return FileManager.default.homeDirectoryForCurrentUser
        }()
        if !FileManager.default.fileExists(atPath: homeDir.appendingPathComponent(".claude").path) {
            conditions.append(.claudeNotInstalled)
        }

        // Check OAuth token
        if CredentialProvider.getOAuthToken() == nil {
            conditions.append(.authMissing)
        }

        // Check data staleness (>10 min old)
        if let lastUpdated = viewModel.lastUpdated,
           Date().timeIntervalSince(lastUpdated) > 600 {
            conditions.append(.dataStale)
        }

        // Check loading state (rate limited / refreshing)
        if viewModel.lastRefreshFailed && viewModel.lastUpdated != nil {
            conditions.append(.rateLimited)
        }

        return conditions.filter { !dismissedBanners.contains($0.id) }
    }

    var body: some View {
        if !hasCompletedOnboarding {
            OnboardingView(theme: theme, onComplete: { hasCompletedOnboarding = true })
                .frame(width: 380, height: 595)
                .background(Color(white: 0.97))
                .preferredColorScheme(.light)
        } else {
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

                // Status banners (between header and session strip)
                let banners = activeBannerConditions
                if !banners.isEmpty {
                    StatusBannerView(
                        conditions: banners,
                        theme: theme,
                        onDismiss: { condition in
                            dismissedBanners.insert(condition.id)
                        }
                    )
                }

                // Live Session Strip (between header and scroll, fixed)
                if hasActiveSession {
                    LiveSessionStrip(
                        theme: theme,
                        session: viewModel.session,
                        liveTimer: viewModel.liveSessionDuration
                    )
                    .animation(.easeInOut(duration: 0.3), value: hasActiveSession)

                    Divider().overlay(theme.dividerColor)
                }

                if showSettings {
                    SettingsTab(
                        theme: theme,
                        themeName: $themeName,
                        showSettings: $showSettings
                    )
                } else if showProjects {
                    ProjectsView(
                        projects: viewModel.allProjects,
                        showProjects: $showProjects,
                        theme: theme
                    )
                } else if viewModel.isLoading {
                    LoadingPlaceholder(theme: theme)
                } else {
                    DashboardContent(
                        theme: theme,
                        viewModel: viewModel,
                        showProjects: $showProjects
                    )
                }

                Divider().overlay(theme.dividerColor)

                FooterBar(
                    theme: theme,
                    onRefresh: {
                        // Reset dismissed banners on manual refresh so persistent conditions reappear
                        dismissedBanners.removeAll()
                        Task {
                            await viewModel.refresh()
                            ToastManager.shared.show(message: "Data refreshed", icon: nil)
                        }
                    },
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
                    showSettings: $showSettings
                )
            }
            .frame(width: 380, height: 595)
            .background(theme.popoverBackground)
            .overlay {
                if theme.hasScanlines { ScanlineOverlay() }
            }
            .preferredColorScheme(colorScheme)
            .onAppear {
                // Reset dismissed banners each time popover appears
                dismissedBanners.removeAll()
                Task { await viewModel.refresh() }
            }
        }
    }

    private func copySummary() {
        let sessions = viewModel.allSessions
        let count = max(sessions.count, viewModel.activeSessions.count)
        var text = String(format: "%d session%@", count, count == 1 ? "" : "s")
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
                        .foregroundStyle(SondeColors.brandGreen)
                        .glowText(theme)
                    Text("e")
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundStyle(SondeColors.brandGreen)
                        .glowText(theme)
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
                        .glowText(theme)
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
                .glowText(theme)
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
                    .glowText(theme)
                if promoActive {
                    let activeLabel = promoShortLabel == "⚡" ? "Promo Active" : "\(promoShortLabel) Active"
                    Text(activeLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.highlightAccent)
                        .glowText(theme)
                    if !promoCountdown.isEmpty {
                        Text("· \(promoCountdown)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                            .glowText(theme, radius: 2)
                    }
                } else {
                    Text("Off-peak in \(promoCountdown)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.textPrimary)
                        .glowText(theme)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(promoActive ? theme.highlightAccent.opacity(0.15) : theme.cardBackground)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(promoActive ? theme.highlightAccent.opacity(0.4) : theme.borderColor, lineWidth: 1))
            .shadow(color: theme.cardGlow ?? .clear, radius: theme.textGlow != nil ? 3 : 0)
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
                    onTap: { showProjects = true }
                )

                // Session activity summary
                SessionActivityCard(
                    theme: theme,
                    sessions: viewModel.allSessions,
                    session: viewModel.session
                )

                UsageCard(
                    theme: theme,
                    dailyHistory: viewModel.dailyHistory,
                    usageHistory: viewModel.usageHistory,
                    fiveHourUtil: viewModel.fiveHourUtil,
                    sevenDayUtil: viewModel.sevenDayUtil
                )
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
    let onTap: () -> Void

    @State private var gaugeAppeared = false
    @State private var isHovered = false

    private var sessionCount: Int { max(sessions.count, activeCount) }
    private var totalTokens: Int {
        sessions.reduce(0) { $0 + ($1.totalInputTokens ?? 0) + ($1.totalOutputTokens ?? 0) }
    }
    private var totalLines: Int { sessions.reduce(0) { $0 + ($1.linesAdded ?? 0) - ($1.linesRemoved ?? 0) } }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Section header
                HStack {
                    Text("Usage")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(theme.textSecondary.opacity(0.7))
                        .glowText(theme, radius: 2)
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

                    // Center: sessions + sparkline + code velocity
                    VStack(spacing: 4) {
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
                        .glowText(theme, radius: 2)

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
                                    .glowText(theme)
                                Text(velocity)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(theme.highlightAccent)
                                    .glowText(theme)
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
                    if totalLines != 0 {
                        let lineLabel = totalLines >= 0 ? "+\(totalLines)" : "\(totalLines)"
                        statLabel(value: lineLabel, unit: "lines")
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
                            .glowText(theme)
                        Text(paceTier.rawValue)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                            .glowText(theme, radius: 2)
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
                        .foregroundStyle(theme.costMedColor)
                        .glowText(theme)
                }
            }
            .padding(12)
            .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
            .modifier(CardEdgeModifier(theme: theme))
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

    private var cacheHitRatio: String? {
        let totalRead = sessions.reduce(0) { $0 + $1.cacheReadTokens }
        let totalWrite = sessions.reduce(0) { $0 + $1.cacheWriteTokens }
        let total = totalRead + totalWrite
        guard total > 0 else { return nil }
        return "\(Int(Double(totalRead) / Double(total) * 100))%"
    }

    private func statLabel(value: String, unit: String) -> some View {
        HStack(spacing: 2) {
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.textPrimary)
                .glowText(theme)
            Text(unit)
                .font(.system(size: 10))
                .foregroundStyle(theme.textSecondary.opacity(0.5))
                .glowText(theme, radius: 2)
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
        if util >= 80 { return theme.highUtilColor }
        if util >= 60 { return theme.costMedColor }
        if util >= 40 { return theme.medUtilColor }
        return theme.lowUtilColor
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.textSecondary.opacity(0.6))
                .glowText(theme, radius: 2)
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
                .glowText(theme)
                .frame(width: 30, alignment: .leading)
                .contentTransition(.numericText())

            if let reset {
                Text(TimeFormatting.formatResetCountdown(from: reset))
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textSecondary.opacity(0.5))
                    .glowText(theme, radius: 2)
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

    private var used: Int { max(0, min(100, Int(util))) }

    private var gaugeColor: Color {
        if util >= 80 { return theme.highUtilColor }
        if util >= 60 { return theme.costMedColor }
        if util >= 40 { return theme.medUtilColor }
        return theme.lowUtilColor
    }

    private var hasGlow: Bool { theme.textGlow != nil }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Track
                Circle()
                    .stroke(theme.borderColor.opacity(hasGlow ? 0.5 : 1.0), lineWidth: lineWidth)

                // Backlit glow behind fill — tight halo, high opacity for brightness without blur
                if hasGlow {
                    Circle()
                        .trim(from: 0, to: min(util, 100) / 100)
                        .stroke(gaugeColor.opacity(0.6), style: StrokeStyle(lineWidth: lineWidth + 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .blur(radius: 3)
                        .animation(.easeOut(duration: 1.0), value: util)
                }

                // Fill
                Circle()
                    .trim(from: 0, to: min(util, 100) / 100)
                    .stroke(gaugeColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.0), value: util)

                // Center label — larger + heavier for brightness, single tight shadow for sharpness
                VStack(spacing: 1) {
                    Text("\(used)%")
                        .font(.system(size: 20, weight: .heavy, design: .monospaced))
                        .foregroundStyle(gaugeColor)
                        .contentTransition(.numericText())
                        .shadow(color: theme.textGlow ?? .clear, radius: hasGlow ? 6 : 0)
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.textSecondary.opacity(hasGlow ? 0.9 : 0.6))
                        .shadow(color: theme.textGlow ?? .clear, radius: hasGlow ? 3 : 0)
                }
            }
            .frame(width: gaugeSize, height: gaugeSize)

            // Reset countdown
            if let reset {
                Text(TimeFormatting.formatResetCountdown(from: reset))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.textSecondary.opacity(hasGlow ? 0.85 : 0.5))
                    .shadow(color: theme.textGlow ?? .clear, radius: hasGlow ? 4 : 0)
            }
        }
    }
}

// MARK: - Session Activity Card

private struct SessionActivityCard: View {
    let theme: PopoverTheme
    let sessions: [SessionData]
    let session: SessionData

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
                        .glowText(theme, radius: 2)
                    Spacer()
                }

                // Code changes bar (added vs removed, visual ratio)
                if totalLinesAdded > 0 || totalLinesRemoved > 0 {
                    VStack(spacing: 3) {
                        HStack(spacing: 4) {
                            Text("Code")
                                .font(.system(size: 9))
                                .foregroundStyle(theme.textSecondary.opacity(0.5))
                                .glowText(theme, radius: 2)
                            Spacer()
                            Text("+\(totalLinesAdded)")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(theme.lowUtilColor)
                                .glowText(theme)
                            Text("/")
                                .font(.system(size: 9))
                                .foregroundStyle(theme.textSecondary.opacity(0.3))
                            Text("-\(totalLinesRemoved)")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(theme.highUtilColor)
                                .glowText(theme)
                            Text("=")
                                .font(.system(size: 9))
                                .foregroundStyle(theme.textSecondary.opacity(0.3))
                            Text("\(netLines > 0 ? "+" : "")\(netLines) net")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(netLines >= 0 ? theme.lowUtilColor : theme.highUtilColor)
                                .glowText(theme)
                        }
                        // Visual ratio bar: green (added) vs red (removed)
                        let total = max(totalLinesAdded + totalLinesRemoved, 1)
                        GeometryReader { geo in
                            HStack(spacing: 1) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(theme.lowUtilColor.opacity(0.7))
                                    .frame(width: geo.size.width * CGFloat(totalLinesAdded) / CGFloat(total))
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(theme.highUtilColor.opacity(0.7))
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
                    VStack(spacing: 4) {
                        ForEach(sessions.prefix(5), id: \.sessionId) { s in
                            HStack(spacing: 0) {
                                // Project name — fixed left column
                                Text(s.projectName ?? "Unknown")
                                    .font(.system(size: 10))
                                    .foregroundStyle(theme.textPrimary)
                                    .glowText(theme)
                                    .lineLimit(1)
                                    .frame(width: 120, alignment: .leading)

                                Spacer(minLength: 4)

                                // Model pill — fixed width
                                if let model = s.modelName {
                                    Text(shortModel(model))
                                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(theme.modelPillText)
                                        .glowText(theme)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(theme.modelColor(for: model), in: RoundedRectangle(cornerRadius: 3))
                                        .frame(width: 50)
                                }

                                // Duration — right-aligned
                                Text(s.formattedDuration)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(theme.textSecondary.opacity(0.6))
                                    .glowText(theme, radius: 2)
                                    .frame(width: 60, alignment: .trailing)
                            }
                        }
                    }
                }
            }
            .padding(10)
            .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
            .modifier(CardEdgeModifier(theme: theme))
        }
    }

    private func miniStatView(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(theme.textSecondary.opacity(0.5))
                .glowText(theme, radius: 2)
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.textPrimary)
                .glowText(theme)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(theme.textSecondary.opacity(0.4))
                .glowText(theme, radius: 2)
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
                    .glowText(theme, radius: 2)
                Spacer()
                if let util = fiveHourUtil {
                    Text("5h: \(Int(util))%")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textSecondary.opacity(0.7))
                        .glowText(theme, radius: 2)
                }
                if let util = sevenDayUtil {
                    Text("7d: \(Int(util))%")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textSecondary.opacity(0.7))
                        .glowText(theme, radius: 2)
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
                            .glowText(theme, radius: day.isToday ? 3 : 2)
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
        if value >= 85 { return theme.highUtilColor }
        if value >= 60 { return theme.medUtilColor }
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
        if peak >= 85 { return theme.highUtilColor }
        if peak >= 60 { return theme.medUtilColor }
        return theme.lowUtilColor
    }
}

// MARK: - Footer Bar (clean, minimal)

private struct FooterBar: View {
    let theme: PopoverTheme
    let onRefresh: () -> Void
    let onExport: () -> Void
    let onCopySummary: () -> Void
    let onToggleWatcher: () -> Void
    @Binding var showSettings: Bool

    @State private var spinning = false

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
                    .glowText(theme)
                    .rotationEffect(.degrees(spinning ? 360 : 0))
                    .animation(.linear(duration: 0.5), value: spinning)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("r", modifiers: .command)
            .help("Refresh (Cmd+R)")

            Button(action: onToggleWatcher) {
                Image(systemName: "pip")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.headerAccent)
                    .glowText(theme)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("p", modifiers: .command)
            .help("Toggle watcher (Cmd+P)")

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showSettings.toggle() }
            } label: {
                Image(systemName: showSettings ? "gearshape.fill" : "gearshape")
                    .font(.system(size: 11))
                    .foregroundStyle(showSettings ? theme.popoverBackground : theme.headerAccent)
                    .glowText(theme)
                    .padding(4)
                    .background(
                        showSettings
                            ? AnyShapeStyle(theme.headerAccent)
                            : AnyShapeStyle(.clear),
                        in: RoundedRectangle(cornerRadius: 4)
                    )
            }
            .buttonStyle(.borderless)
            .help("Settings")

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textSecondary)
                    .glowText(theme, radius: 2)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("q", modifiers: .command)
            .help("Quit (Cmd+Q)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
