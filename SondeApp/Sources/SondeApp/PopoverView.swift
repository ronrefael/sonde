import ServiceManagement
import SondeCore
import SwiftUI

/// The popover dashboard shown when clicking the menu bar icon.
struct PopoverView: View {
    @ObservedObject var viewModel: SondeViewModel
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar
            headerSection
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Current session card
                    sessionCard

                    // Pacing + promo
                    pacingSection

                    // Usage limits
                    usageLimitsSection

                    // Extra usage card
                    if viewModel.extraUsageEnabled {
                        extraUsageCard
                    }

                    // Active sessions
                    if viewModel.activeSessions.count > 1 {
                        sessionsSection
                    }

                    // Model suggestion
                    modelSuggestion
                }
                .padding(16)
            }

            Divider()
            footerSection
        }
        .frame(width: 320, height: 480)
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
            HStack {
                Text("Current Session")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 16) {
                // Model
                VStack(alignment: .leading, spacing: 2) {
                    Text("Model")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(viewModel.session.modelName ?? "—")
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Spacer()

                // Cost
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
                            .foregroundStyle(.secondary)
                    }
                }

                // Duration
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Time")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(viewModel.session.formattedDuration)
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
            }
            Spacer()
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
                UsageRow(
                    label: "5-hour window",
                    utilization: fh,
                    resetTime: viewModel.fiveHourReset
                )
            }

            if let sd = viewModel.sevenDayUtil {
                UsageRow(
                    label: "7-day window",
                    utilization: sd,
                    resetTime: viewModel.sevenDayReset
                )
            }

            if let extra = viewModel.extraUsageUtil {
                UsageRow(
                    label: "Extra usage",
                    utilization: extra,
                    resetTime: nil
                )
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
                    Text("Monthly Limit")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if let limit = viewModel.extraUsageMonthlyLimit {
                        Text(String(format: "$%.0f", limit))
                            .font(.headline)
                            .fontWeight(.semibold)
                    } else {
                        Text("--")
                            .font(.headline)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Used")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if let used = viewModel.extraUsageUsedCredits {
                        Text(String(format: "$%.2f", used))
                            .font(.headline)
                            .fontWeight(.semibold)
                    } else {
                        Text("--")
                            .font(.headline)
                    }
                }

                Spacer()

                if let util = viewModel.extraUsageUtil {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Utilization")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text("\(Int(util))%")
                            .font(.headline)
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .foregroundStyle(util >= 80 ? .red : util >= 60 ? .orange : .green)
                    }
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
        }
        .padding(10)
        .background(.quaternary.opacity(0.3))
        .cornerRadius(6)
    }

    // MARK: - Model Suggestion

    @ViewBuilder
    private var modelSuggestion: some View {
        if let fh = viewModel.fiveHourUtil, fh >= 60,
           viewModel.session.modelName == "Opus"
        {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb")
                    .foregroundStyle(.yellow)
                    .font(.caption)
                Text(fh >= 80
                    ? "Switch to Haiku for routine tasks"
                    : "Consider Sonnet for lower-cost work")
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(10)
            .background(.yellow.opacity(0.08))
            .cornerRadius(6)
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
                // If registration fails, revert the toggle
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
                            width: max(0, geo.size.width * CGFloat(min(utilization, 100) / 100.0)),
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
