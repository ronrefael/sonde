import SondeCore
import SwiftUI

/// Shows a list of all active projects with drill-down detail.
struct ProjectsView: View {
    let projects: [ProjectSession]
    @Binding var showProjects: Bool
    let theme: PopoverTheme
    @State private var selectedProject: ProjectSession?
    @State private var showAllTasks: Bool = false

    var body: some View {
        if let project = selectedProject {
            projectDetail(project)
        } else {
            projectList
        }
    }

    // MARK: - Project List

    private var projectList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    showProjects = false
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.caption)
                        Text("Dashboard")
                            .font(.caption)
                    }
                    .foregroundStyle(theme.headerAccent)
                }
                .buttonStyle(.borderless)
                Spacer()
                Text("\(projects.count) project\(projects.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider().overlay(theme.dividerColor)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(projects) { project in
                        projectCard(project)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedProject = project
                            }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
    }

    // MARK: - Project Card

    private func projectCard(_ project: ProjectSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.headerAccent)

                Text(project.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textSecondary.opacity(0.5))
            }

            HStack(spacing: 6) {
                if let model = project.modelName {
                    modelBadge(model)
                }
                if let branch = project.gitBranch {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 8))
                        Text(branch)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 90, alignment: .leading)
                    }
                    .foregroundStyle(theme.textSecondary)
                    .font(.system(size: 10))
                }
                Spacer()
                if let activity = project.lastActivity {
                    Text(relativeTime(activity))
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textSecondary.opacity(0.6))
                }
            }

            if let pct = project.contextUsedPct, let window = project.contextWindowSize, window > 0 {
                miniContextBar(pct: pct, used: project.contextTokensUsed, window: window)
            }

            HStack(spacing: 0) {
                miniStat(icon: "text.word.spacing", value: formatTokens(project.contextTokensUsed), label: "tokens")
                if let lines = project.linesAdded, lines > 0 {
                    miniStat(icon: "plus.square", value: "+\(lines)", label: "lines", color: theme.lowUtilColor)
                }
                if let cache = project.cacheHitRatio {
                    miniStat(icon: "arrow.triangle.2.circlepath", value: cache, label: "cache")
                }
                if project.messageCount > 0 {
                    miniStat(icon: "bubble.left", value: "\(project.messageCount)", label: "msgs")
                }
                if !project.tasks.isEmpty {
                    miniStat(icon: "list.bullet", value: "\(project.tasks.count)", label: "tasks")
                }
            }
        }
        .padding(10)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.borderColor, lineWidth: 1))
    }

    private func modelBadge(_ name: String) -> some View {
        Text(name)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(theme.modelColor(for: name), in: RoundedRectangle(cornerRadius: 3))
    }

    private func miniContextBar(pct: Double, used: Int, window: Int) -> some View {
        let color: Color = pct >= 80 ? theme.highUtilColor : pct >= 60 ? theme.medUtilColor : theme.lowUtilColor
        return HStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(theme.borderColor)
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: max(0, geo.size.width * min(pct, 100) / 100), height: 3)
                }
            }
            .frame(height: 3)

            Text("\(Int(pct))%")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text("\(used / 1000)k/\(window / 1000)k")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(theme.textSecondary.opacity(0.5))
        }
    }

    private func miniStat(icon: String, value: String, label: String, color: Color? = nil) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(theme.textSecondary.opacity(0.5))
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(color ?? theme.textPrimary)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(theme.textSecondary.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Project Detail

    private func projectDetail(_ project: ProjectSession) -> some View {
        let hasLines = (project.linesAdded ?? 0) > 0 || (project.linesRemoved ?? 0) > 0

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    selectedProject = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.caption)
                        Text("Projects")
                            .font(.caption)
                    }
                    .foregroundStyle(theme.headerAccent)
                }
                .buttonStyle(.borderless)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider().overlay(theme.dividerColor)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.headerAccent)
                    Text(project.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    if let model = project.modelName {
                        modelBadge(model)
                    }
                }

                if let branch = project.gitBranch {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 9))
                        Text(branch)
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(theme.textSecondary)
                }

                // Hero row
                HStack(spacing: 0) {
                    VStack(spacing: 1) {
                        Text("Messages")
                            .font(.system(size: 9))
                            .foregroundStyle(theme.textSecondary.opacity(0.6))
                        Text("\(project.messageCount)")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(theme.textPrimary)
                    }
                    .frame(maxWidth: .infinity)

                    if let activity = project.lastActivity {
                        VStack(spacing: 1) {
                            Text("Activity")
                                .font(.system(size: 9))
                                .foregroundStyle(theme.textSecondary.opacity(0.6))
                            Text(relativeTime(activity))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(theme.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                    }

                }
                .padding(10)
                .background(theme.cardBackground)
                .cornerRadius(8)

                // Context bar
                if let _ = project.contextUsedPct, let window = project.contextWindowSize, window > 0 {
                    contextBar(for: project)
                }

                // Tokens + stats
                VStack(spacing: 6) {
                    HStack(spacing: 0) {
                        statCell(label: "Input", value: formatTokens(project.totalInputTokens))
                        statCell(label: "Output", value: formatTokens(project.totalOutputTokens))
                        statCell(label: "Cache Read", value: formatTokens(project.cacheReadTokens))
                        statCell(label: "Cache Write", value: formatTokens(project.cacheWriteTokens))
                    }

                    Divider().overlay(theme.dividerColor).opacity(0.3)

                    HStack(spacing: 0) {
                        if let cache = project.cacheHitRatio {
                            statCell(label: "Cache Hit", value: cache)
                        }
                        if hasLines {
                            statCell(label: "Added", value: "+\(project.linesAdded ?? 0)", color: theme.lowUtilColor)
                            statCell(label: "Removed", value: "-\(project.linesRemoved ?? 0)", color: theme.highUtilColor)
                        }
                        if project.webSearchCount > 0 {
                            statCell(label: "Searches", value: "\(project.webSearchCount)")
                        }
                        if project.webFetchCount > 0 {
                            statCell(label: "Fetches", value: "\(project.webFetchCount)")
                        }
                        if !hasLines && project.webSearchCount == 0 && project.webFetchCount == 0 {
                            statCell(label: "Total", value: formatTokens(project.contextTokensUsed))
                        }
                    }
                }
                .padding(10)
                .background(theme.cardBackground)
                .cornerRadius(8)

                if !project.tasks.isEmpty {
                    tasksSection(project.tasks)
                }
            }
            .padding(14)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Tasks Section

    private func tasksSection(_ tasks: [TaskInfo]) -> some View {
        let displayTasks = showAllTasks ? tasks : Array(tasks.prefix(20))
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Conversations")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Text("\(tasks.count)")
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary.opacity(0.5))
            }

            VStack(spacing: 1) {
                ForEach(displayTasks) { task in
                    taskRow(task)
                }
            }
            .background(theme.cardBackground)
            .cornerRadius(8)

            if tasks.count > 20 && !showAllTasks {
                Button {
                    showAllTasks = true
                } label: {
                    Text("Show all \(tasks.count) conversations")
                        .font(.caption2)
                        .foregroundStyle(theme.headerAccent)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func taskRow(_ task: TaskInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(task.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)
                    .truncationMode(.tail)

                Spacer()
            }

            HStack(spacing: 6) {
                if let model = task.modelName {
                    modelBadge(model)
                }

                Text(task.formattedTokens)
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(theme.textSecondary)

                if task.messageCount > 0 {
                    HStack(spacing: 1) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 8))
                        Text("\(task.messageCount)")
                            .font(.caption2)
                    }
                    .foregroundStyle(theme.textSecondary.opacity(0.6))
                }

                Spacer()

                if let activity = task.lastActivity {
                    Text(relativeTime(activity))
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    private func contextBar(for project: ProjectSession) -> some View {
        let used = project.contextTokensUsed
        let size = project.contextWindowSize ?? 200_000
        let pct = size > 0 ? Double(used) / Double(size) * 100 : 0
        let barPct = min(pct, 100)
        let color: Color = pct >= 70 ? theme.highUtilColor : pct >= 40 ? theme.medUtilColor : theme.lowUtilColor

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Context")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                if pct > 100 {
                    Text("FULL")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(theme.highUtilColor)
                } else {
                    Text("\(Int(pct))%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(color)
                }
                Text("\(used / 1000)k/\(size / 1000)k")
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary.opacity(0.5))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.borderColor)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: max(0, geo.size.width * CGFloat(barPct / 100)), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private func statCell(label: String, value: String, color: Color? = nil) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(theme.textSecondary.opacity(0.6))
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(color ?? theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func formatTokens(_ count: Int?) -> String {
        guard let count else { return "--" }
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1000 { return String(format: "%.1fk", Double(count) / 1000) }
        return "\(count)"
    }

    private func formatTokens(_ count: Int) -> String {
        formatTokens(Optional(count))
    }

    private func relativeTime(_ date: Date) -> String {
        let secs = Int(Date().timeIntervalSince(date))
        if secs < 5 { return "just now" }
        if secs < 60 { return "\(secs)s ago" }
        if secs < 3600 { return "\(secs / 60)m ago" }
        return "\(secs / 3600)h ago"
    }
}
