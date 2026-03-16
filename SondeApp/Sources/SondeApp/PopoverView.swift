import ServiceManagement
import SondeCore
import SwiftUI
import UniformTypeIdentifiers

/// The popover dashboard shown when clicking the menu bar icon.
struct PopoverView: View {
    @ObservedObject var viewModel: SondeViewModel
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @State private var showBudgetSheet: Bool = false
    @State private var budgetInput: String = ""
    @State private var showProjects: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showProjects {
                headerSection
                Divider()
                ProjectsView(
                    projects: viewModel.allProjects,
                    showProjects: $showProjects
                )
                Divider()
                footerSection
            } else {
                headerSection
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    sessionRow
                    contextRow
                    statsRow
                    pacingUsageRow
                    dailySpendRow

                    if viewModel.activeSessions.count > 1 {
                        sessionsRow
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Spacer(minLength: 0)
                Divider()
                footerSection
            }
        }
        .frame(width: 320, height: 400)
        .onAppear { viewModel.startPolling() }
        .onDisappear { viewModel.stopPolling() }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundStyle(.blue)
                    Text("sonde")
                        .font(.headline)
                }
                if let updated = viewModel.lastUpdated {
                    Text("Updated \(relativeTime(updated))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            if let version = viewModel.updateAvailable {
                Button {
                    if let url = URL(string: "https://github.com/ronrefael/sonde/releases/latest") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text("v\(version) available")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .cornerRadius(4)
                }
                .buttonStyle(.borderless)
            }
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

    // MARK: - Session Row (Model + Cost + Time on one line)

    private var sessionRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Branch + agent tag
            HStack(spacing: 4) {
                if let branch = viewModel.session.gitBranch {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text(branch)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("·")
                        .foregroundStyle(.tertiary)
                }
                Text("Session")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                if let agent = viewModel.session.agentName {
                    Text(agent)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.purple.opacity(0.15))
                        .cornerRadius(3)
                }
            }

            // Model  Cost  Time — all on one line
            HStack(spacing: 0) {
                Text(viewModel.session.modelName ?? "--")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(viewModel.session.formattedCost)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(costColor)
                Spacer()
                Text(viewModel.liveSessionDuration)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
            }

            // Codex cost if present
            if let codex = viewModel.codexCost {
                HStack(spacing: 6) {
                    Spacer()
                    Text(String(format: "Codex $%.2f", codex))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    if let claude = viewModel.session.sessionCost {
                        Text(String(format: "Combined $%.2f", claude + codex))
                            .font(.system(size: 9, weight: .medium))
                    }
                }
            }
        }
        .padding(8)
        .background(.quaternary.opacity(0.3))
        .cornerRadius(6)
    }

    private var costColor: Color {
        guard let cost = viewModel.session.sessionCost else { return .primary }
        if cost >= 5.0 { return .red }
        if cost >= 2.0 { return .orange }
        return .primary
    }

    // MARK: - Context Row (inline single row with bar)

    @ViewBuilder
    private var contextRow: some View {
        if viewModel.session.totalInputTokens != nil {
            let used = viewModel.session.contextTokensUsed
            let size = viewModel.session.contextWindowSize ?? 200_000
            let pct = size > 0 ? Double(used) / Double(size) * 100 : 0
            let barPct = min(pct, 100)
            let color: Color = pct >= 70 ? .red : pct >= 40 ? .orange : .green

            HStack(spacing: 6) {
                Text("Context")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if pct > 100 {
                    Text("FULL")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.red)
                } else {
                    Text("\(Int(pct))%")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(color)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .frame(width: max(0, geo.size.width * CGFloat(barPct / 100)), height: 4)
                    }
                }
                .frame(height: 4)

                Text("\(used / 1000)k/\(size / 1000)k")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Stats Row (3 key stats inline)

    @ViewBuilder
    private var statsRow: some View {
        if viewModel.session.linesAdded != nil || viewModel.session.messageCount > 0 {
            HStack(spacing: 0) {
                // Lines added
                let lines = viewModel.session.linesAdded.map { "+\($0)" } ?? "--"
                HStack(spacing: 2) {
                    Text(lines)
                        .foregroundStyle(.green)
                    Text("lines")
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Cache hit ratio
                HStack(spacing: 2) {
                    Text(viewModel.session.cacheHitRatio ?? "--")
                        .foregroundStyle(.primary)
                    Text("cache")
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Cost per line
                Text(viewModel.session.costPerLine ?? "--")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
        }
    }

    // MARK: - Pacing + Usage combined row

    private var pacingUsageRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Main pacing line: emoji + tier + 5h window + 7d window
            HStack(spacing: 6) {
                Text(viewModel.paceTier.emoji)
                    .font(.system(size: 14))

                Text(viewModel.paceTier.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)

                Spacer()

                if viewModel.usageHistory.count > 2 {
                    SparklineView(data: viewModel.usageHistory)
                        .frame(width: 40, height: 14)
                }
            }

            // Usage windows inline
            HStack(spacing: 8) {
                // 5-hour window
                if let fh = viewModel.fiveHourUtil {
                    HStack(spacing: 3) {
                        Text("5h")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                        Text("\(Int(fh))%")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(utilColor(fh))
                        if let reset = viewModel.fiveHourReset {
                            Text("(\(TimeFormatting.formatResetCountdown(from: reset)))")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                // 7-day window
                if let sd = viewModel.sevenDayUtil {
                    HStack(spacing: 3) {
                        Text("7d")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                        Text("\(Int(sd))%")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(utilColor(sd))
                        if let reset = viewModel.sevenDayReset {
                            Text("(\(TimeFormatting.formatResetCountdown(from: reset)))")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()

                // Extra usage inline if enabled
                if viewModel.extraUsageEnabled, let util = viewModel.extraUsageUtil {
                    HStack(spacing: 2) {
                        Text("Extra")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                        Text("\(Int(util))%")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(utilColor(util))
                    }
                }
            }

            // Prediction / model suggestion (compact)
            if let predict = viewModel.pacePredict {
                Text(predict)
                    .font(.system(size: 9))
                    .italic()
                    .foregroundStyle(.orange)
            }
            if !viewModel.promoActive, let mins = promoMinsAway, mins <= 30 {
                Text("2x starts in \(mins)m -- queue heavy work")
                    .font(.system(size: 9))
                    .italic()
                    .foregroundStyle(.green)
            }
            if let suggestion = modelSuggestionText {
                Text(suggestion)
                    .font(.system(size: 9))
                    .italic()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(pacingBackground)
        .cornerRadius(6)
    }

    private func utilColor(_ util: Double) -> Color {
        if util >= 80 { return .red }
        if util >= 60 { return .orange }
        if util >= 40 { return .yellow }
        return .green
    }

    private var pacingBackground: Color {
        switch viewModel.paceTier {
        case .comfortable: return .green.opacity(0.08)
        case .onTrack: return .blue.opacity(0.08)
        case .elevated: return .yellow.opacity(0.08)
        case .hot: return .orange.opacity(0.08)
        case .critical: return .red.opacity(0.08)
        case .runaway: return .red.opacity(0.15)
        }
    }

    // MARK: - Daily Spend Row

    @ViewBuilder
    private var dailySpendRow: some View {
        if viewModel.dailyClaudeCost > 0 || viewModel.dailyCodexCost > 0 {
            HStack(spacing: 4) {
                Text("Today:")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                let total = viewModel.dailyClaudeCost + viewModel.dailyCodexCost

                Text(String(format: "$%.2f", viewModel.dailyClaudeCost))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                Text("Claude")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)

                if viewModel.dailyCodexCost > 0 {
                    Text("|")
                        .font(.system(size: 9))
                        .foregroundStyle(.quaternary)
                    Text(String(format: "$%.2f", viewModel.dailyCodexCost))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                    Text("Codex")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if viewModel.budgetExceeded {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.red)
                }

                Text(String(format: "$%.2f", total))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(total >= 10 ? .red : total >= 5 ? .orange : .primary)

                Button {
                    budgetInput = viewModel.dailyBudget > 0 ? String(format: "%.0f", viewModel.dailyBudget) : ""
                    showBudgetSheet = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .popover(isPresented: $showBudgetSheet, arrowEdge: .trailing) {
                    VStack(spacing: 8) {
                        Text("Daily Budget")
                            .font(.caption)
                            .fontWeight(.semibold)
                        TextField("Amount ($)", text: $budgetInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                        HStack(spacing: 8) {
                            if viewModel.dailyBudget > 0 {
                                Button("Clear") {
                                    viewModel.dailyBudget = 0
                                    showBudgetSheet = false
                                }
                                .font(.caption)
                            }
                            Button("Save") {
                                if let val = Double(budgetInput), val > 0 {
                                    viewModel.dailyBudget = val
                                }
                                showBudgetSheet = false
                            }
                            .font(.caption)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                    .padding(12)
                }
            }

            // Per-project cost breakdown from active worktrees
            if !viewModel.session.otherProjects.isEmpty {
                HStack(spacing: 4) {
                    ForEach(viewModel.session.otherProjects.prefix(3), id: \.name) { project in
                        HStack(spacing: 2) {
                            Image(systemName: "folder")
                                .font(.system(size: 8))
                                .foregroundStyle(.tertiary)
                            Text(project.name)
                                .font(.system(size: 9))
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Text(String(format: "$%.2f", project.cost))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if !viewModel.allProjects.isEmpty {
                        Button {
                            showProjects = true
                        } label: {
                            HStack(spacing: 1) {
                                Text("All")
                                    .font(.system(size: 9))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 7))
                            }
                            .foregroundStyle(.blue)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
    }

    // MARK: - Sessions Row

    private var sessionsRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "terminal")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Text("\(viewModel.activeSessions.count) sessions")
                .font(.caption2)
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
                    .font(.system(size: 9, weight: .medium))
            }
            .buttonStyle(.borderless)
            Button {
                showProjects = true
            } label: {
                HStack(spacing: 1) {
                    Text("View all")
                        .font(.system(size: 9))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 7))
                }
                .foregroundStyle(.blue)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Computed Helpers

    private func relativeTime(_ date: Date) -> String {
        let secs = Int(Date().timeIntervalSince(date))
        if secs < 5 { return "just now" }
        if secs < 60 { return "\(secs)s ago" }
        if secs < 3600 { return "\(secs / 60)m ago" }
        return "\(secs / 3600)h ago"
    }

    private var promoMinsAway: Int? {
        guard !viewModel.promoCountdown.isEmpty else { return nil }
        let parts = viewModel.promoCountdown.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
        guard let last = parts.last, let mins = Int(last) else { return nil }
        if viewModel.promoCountdown.contains("h") { return nil }
        return mins
    }

    private var modelSuggestionText: String? {
        guard let model = viewModel.session.modelName else { return nil }
        switch (viewModel.paceTier, model) {
        case (.comfortable, "Opus"): return nil
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
        VStack(spacing: 0) {
            if viewModel.dailyBudget > 0 {
                HStack {
                    Spacer()
                    Text(String(format: "Budget: $%.0f", viewModel.dailyBudget))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(.top, 4)
            }
            HStack {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.borderless)

                Button {
                    exportUsageData()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
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

    private func exportUsageData() {
        let json = viewModel.exportJSONString()

        let panel = NSSavePanel()
        let dateStr = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate, .withDashSeparatorInDate])
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
