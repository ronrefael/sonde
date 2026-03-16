import ServiceManagement
import SondeCore
import SwiftUI

/// The popover dashboard shown when clicking the menu bar icon.
struct PopoverView: View {
    @ObservedObject var viewModel: SondeViewModel
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    sessionCard

                    // Context window bar
                    if viewModel.session.totalInputTokens != nil {
                        contextWindowBar
                    }

                    // Per-model cost breakdown
                    if viewModel.session.costPerModel.count > 1 {
                        costBreakdown
                    }

                    // Today's spend
                    if viewModel.dailyClaudeCost > 0 || viewModel.dailyCodexCost > 0 {
                        dailySpendSection
                    }

                    pacingSection

                    usageLimitsSection

                    if viewModel.extraUsageEnabled {
                        extraUsageCard
                    }

                    if viewModel.activeSessions.count > 1 {
                        sessionsSection
                    }

                }
                .padding(16)
            }

            Divider()
            footerSection
        }
        .frame(width: 320, height: 520)
        .onAppear { viewModel.startPolling() }
        .onDisappear { viewModel.stopPolling() }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Image(systemName: "waveform.path.ecg")
                .foregroundStyle(.blue)
            Text("sonde")
                .font(.headline)
            Spacer()
            if !viewModel.promoEmoji.isEmpty {
                VStack(alignment: .trailing, spacing: 2) {
                    PromoBadge(
                        emoji: viewModel.promoEmoji,
                        label: viewModel.promoLabel,
                        isActive: viewModel.promoActive
                    )
                    if !viewModel.promoCountdown.isEmpty {
                        Text("\(viewModel.promoCountdownLabel) \(viewModel.promoCountdown)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Session Card

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                if let branch = viewModel.session.gitBranch {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(branch)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                }
                Text("Current Session")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Model")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(viewModel.session.modelName ?? "—")
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Cost")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(viewModel.session.formattedCost)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(costColor)
                    if let codex = viewModel.codexCost {
                        Text(String(format: "Codex $%.2f", codex))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let claude = viewModel.session.sessionCost, let codex = viewModel.codexCost {
                        Text(String(format: "Combined $%.2f", claude + codex))
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                }

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Time")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(viewModel.liveSessionDuration)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.5))
        .cornerRadius(8)
    }

    private var costColor: Color {
        guard let cost = viewModel.session.sessionCost else { return .primary }
        if cost >= 5.0 { return .red }
        if cost >= 2.0 { return .orange }
        return .primary
    }

    // MARK: - Context Window Bar

    private var contextWindowBar: some View {
        let used = viewModel.session.contextTokensUsed
        let size = viewModel.session.contextWindowSize ?? 200_000
        let pct = size > 0 ? Double(used) / Double(size) * 100 : 0
        let barPct = min(pct, 100) // Cap visual bar at 100%
        let color: Color = pct >= 70 ? .red : pct >= 40 ? .orange : .green

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Context")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if pct > 100 {
                    Text("FULL")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                } else {
                    Text("\(Int(pct))%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(color)
                }
                Text("\(used / 1000)k/\(size / 1000)k")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: max(0, geo.size.width * CGFloat(barPct / 100)), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Cost Breakdown

    private var costBreakdown: some View {
        DisclosureGroup("Cost breakdown") {
            ForEach(viewModel.session.costPerModel, id: \.model) { entry in
                HStack {
                    Text(entry.model)
                        .font(.caption)
                    Spacer()
                    Text(String(format: "$%.2f", entry.cost))
                        .font(.caption)
                        .monospacedDigit()
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Daily Spend

    private var dailySpendSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today's Spend")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Label(String(format: "$%.2f", viewModel.dailyClaudeCost), systemImage: "brain")
                    .font(.caption)

                if viewModel.dailyCodexCost > 0 {
                    Label(String(format: "$%.2f", viewModel.dailyCodexCost), systemImage: "terminal")
                        .font(.caption)
                }

                Spacer()

                let total = viewModel.dailyClaudeCost + viewModel.dailyCodexCost
                Text(String(format: "Total $%.2f", total))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(total >= 10 ? .red : total >= 5 ? .orange : .primary)
            }

            // Per-project cost breakdown from active worktrees
            if !viewModel.session.otherProjects.isEmpty {
                Divider()
                    .padding(.vertical, 2)
                Text("Active Projects")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                ForEach(viewModel.session.otherProjects, id: \.name) { project in
                    HStack {
                        Image(systemName: "folder")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(project.name)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text(String(format: "$%.2f", project.cost))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.3))
        .cornerRadius(6)
    }

    // MARK: - Pacing

    private var pacingSection: some View {
        HStack(spacing: 8) {
            Text(viewModel.paceTier.emoji)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.paceTier.rawValue)
                    .font(.headline)
                Text(pacingDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let predict = viewModel.pacePredict {
                    Text(predict)
                        .font(.caption)
                        .italic()
                        .foregroundStyle(.orange)
                }
                // Promo scheduling tip
                if !viewModel.promoActive, let mins = promoMinsAway, mins <= 30 {
                    Text("2x starts in \(mins)m — queue heavy work")
                        .font(.caption)
                        .italic()
                        .foregroundStyle(.green)
                }
                // Model suggestion inline
                if let suggestion = modelSuggestionText {
                    Text(suggestion)
                        .font(.caption)
                        .italic()
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if viewModel.usageHistory.count > 2 {
                SparklineView(data: viewModel.usageHistory)
                    .frame(width: 60, height: 24)
            }
        }
        .padding(12)
        .background(pacingBackground)
        .cornerRadius(8)
    }

    private var pacingDescription: String {
        switch viewModel.paceTier {
        case .comfortable: return "Usage is well within limits"
        case .onTrack: return "Steady pace, no concerns"
        case .elevated: return "Usage picking up — monitor closely"
        case .hot: return "Approaching limits — consider lighter models"
        case .critical: return "Near rate limit — switch models or pause"
        case .runaway: return "Rate limiting imminent!"
        }
    }

    private var pacingBackground: Color {
        switch viewModel.paceTier {
        case .comfortable: return .green.opacity(0.1)
        case .onTrack: return .blue.opacity(0.1)
        case .elevated: return .yellow.opacity(0.1)
        case .hot: return .orange.opacity(0.1)
        case .critical: return .red.opacity(0.1)
        case .runaway: return .red.opacity(0.2)
        }
    }

    // MARK: - Usage Limits

    private var usageLimitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Usage Limits")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let fh = viewModel.fiveHourUtil {
                UsageRow(label: "5-hour window", utilization: fh, resetTime: viewModel.fiveHourReset)
            }

            if let sd = viewModel.sevenDayUtil {
                UsageRow(label: "7-day window", utilization: sd, resetTime: viewModel.sevenDayReset)
            }

            if viewModel.fiveHourUtil == nil && viewModel.sevenDayUtil == nil {
                Text("No usage data available")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Extra Usage

    private var extraUsageCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Extra Usage")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Limit")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if let limit = viewModel.extraUsageMonthlyLimit {
                        Text(String(format: "$%.0f", limit))
                            .font(.headline)
                    } else {
                        Text("--").font(.headline)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Used")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if let used = viewModel.extraUsageUsedCredits {
                        Text(String(format: "$%.2f", used))
                            .font(.headline)
                    } else {
                        Text("--").font(.headline)
                    }
                }

                Spacer()

                if let util = viewModel.extraUsageUtil {
                    Text("\(Int(util))%")
                        .font(.headline)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(util >= 80 ? .red : util >= 60 ? .orange : .green)
                }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.5))
        .cornerRadius(8)
    }

    // MARK: - Sessions

    private var sessionsSection: some View {
        HStack(spacing: 6) {
            Image(systemName: "terminal")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(viewModel.activeSessions.count) Claude sessions active")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                viewModel.showWatcher.toggle()
                if viewModel.showWatcher {
                    FloatingWatcherPanel.shared.show(viewModel: viewModel)
                } else {
                    FloatingWatcherPanel.shared.close()
                }
            } label: {
                Text("Watcher")
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderless)
        }
        .padding(10)
        .background(.quaternary.opacity(0.3))
        .cornerRadius(6)
    }

    // MARK: - Computed Helpers

    /// Minutes until 2x promo starts (nil if already active or > 30m away)
    private var promoMinsAway: Int? {
        guard !viewModel.promoCountdown.isEmpty else { return nil }
        // Parse "Xh XXm" or "XXm" from countdown
        let parts = viewModel.promoCountdown.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
        guard let last = parts.last, let mins = Int(last) else { return nil }
        if viewModel.promoCountdown.contains("h") { return nil } // hours away
        return mins
    }

    /// Model suggestion based on current tier and model
    private var modelSuggestionText: String? {
        guard let model = viewModel.session.modelName else { return nil }
        switch (viewModel.paceTier, model) {
        case (.comfortable, "Opus"): return nil // no suggestion needed
        case (.onTrack, "Opus"): return nil
        case (.elevated, "Opus"): return "Consider Sonnet for routine work"
        case (.hot, "Opus"), (.critical, "Opus"), (.runaway, "Opus"):
            return "Switch to Haiku to conserve usage"
        case (.hot, "Sonnet"), (.critical, "Sonnet"), (.runaway, "Sonnet"):
            return "Switch to Haiku to conserve usage"
        default: return nil
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.borderless)

            Spacer()

            Toggle(isOn: $launchAtLogin) {
                Text("Login")
                    .font(.caption2)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .onChange(of: launchAtLogin) { newValue in
                setLaunchAtLogin(newValue)
            }

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if enabled {
                    try service.register()
                } else {
                    try service.unregister()
                }
            } catch {
                launchAtLogin = !enabled
            }
        }
    }
}

// MARK: - Subviews

struct PromoBadge: View {
    let emoji: String
    let label: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 3) {
            Text(emoji)
                .font(.caption2)
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(isActive ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
        .cornerRadius(4)
    }
}

struct UsageRow: View {
    let label: String
    let utilization: Double
    let resetTime: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                Spacer()
                Text("\(Int(utilization))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundStyle(barColor)
                if let reset = resetTime {
                    Text("resets \(TimeFormatting.formatResetCountdown(from: reset))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(
                            width: max(0, geo.size.width * CGFloat(min(utilization, 100) / 100)),
                            height: 6
                        )
                }
            }
            .frame(height: 6)
        }
    }

    private var barColor: Color {
        if utilization >= 80 { return .red }
        if utilization >= 60 { return .orange }
        if utilization >= 40 { return .yellow }
        return .green
    }
}
