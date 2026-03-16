import SondeCore
import SwiftUI

/// Shows a list of all active projects with drill-down detail.
struct ProjectsView: View {
    let projects: [ProjectSession]
    @Binding var showProjects: Bool
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
                }
                .buttonStyle(.borderless)
                Spacer()
                Text("\(projects.count) projects")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(projects) { project in
                        projectRow(project)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedProject = project
                            }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func projectRow(_ project: ProjectSession) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .font(.caption)
                .foregroundStyle(.blue)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 6) {
                    if let branch = project.gitBranch {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 8))
                            Text(branch)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .foregroundStyle(.secondary)
                    }
                    if let model = project.modelName {
                        Text(model)
                            .foregroundStyle(.tertiary)
                    }
                }
                .font(.caption2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(project.formattedCost)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                if let activity = project.lastActivity {
                    Text(relativeTime(activity))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.clear)
    }

    // MARK: - Project Detail

    private func projectDetail(_ project: ProjectSession) -> some View {
        VStack(alignment: .leading, spacing: 0) {
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
                }
                .buttonStyle(.borderless)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Project header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.headline)
                        if let branch = project.gitBranch {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.caption2)
                                Text(branch)
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }

                    // Model & Cost
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Model")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text(project.modelName ?? "--")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Session Cost")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text(project.formattedCost)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(costColor(for: project.sessionCost))
                        }
                    }
                    .padding(12)
                    .background(.quaternary.opacity(0.5))
                    .cornerRadius(8)

                    // Context usage bar
                    if project.totalInputTokens != nil || project.totalOutputTokens != nil {
                        contextBar(for: project)
                    }

                    // Token counts
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tokens")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Input")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Text(formatTokens(project.totalInputTokens))
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .monospacedDigit()
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Output")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Text(formatTokens(project.totalOutputTokens))
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .monospacedDigit()
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Total")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Text(formatTokens(project.contextTokensUsed))
                                    .font(.callout)
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                            }
                        }
                    }
                    .padding(12)
                    .background(.quaternary.opacity(0.3))
                    .cornerRadius(8)

                    // Session Stats
                    if project.linesAdded != nil || project.messageCount > 0 {
                        sessionStatsCard(for: project)
                    }

                    // Last activity
                    if let activity = project.lastActivity {
                        HStack {
                            Text("Last Activity")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(relativeTime(activity))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Tasks section
                    if !project.tasks.isEmpty {
                        tasksSection(project.tasks)
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Tasks Section

    private func tasksSection(_ tasks: [TaskInfo]) -> some View {
        let displayTasks = showAllTasks ? tasks : Array(tasks.prefix(20))
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tasks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(tasks.count)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 1) {
                ForEach(displayTasks) { task in
                    taskRow(task)
                }
            }
            .background(.quaternary.opacity(0.3))
            .cornerRadius(8)

            if tasks.count > 20 && !showAllTasks {
                Button {
                    showAllTasks = true
                } label: {
                    Text("Show all \(tasks.count) tasks")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func taskRow(_ task: TaskInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(task.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                if let activity = task.lastActivity {
                    Text(relativeTime(activity))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 6) {
                if let model = task.modelName {
                    Text(model)
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.quaternary)
                        .cornerRadius(3)
                }

                Text(task.formattedTokens)
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Text(task.formattedCost)
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private func contextBar(for project: ProjectSession) -> some View {
        let used = project.contextTokensUsed
        let size = project.contextWindowSize ?? 200_000
        let pct = size > 0 ? Double(used) / Double(size) * 100 : 0
        let barPct = min(pct, 100)
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

    // MARK: - Session Stats

    private func sessionStatsCard(for project: ProjectSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stats")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                // Row 1: Lines Added | Lines Removed | Velocity
                HStack(spacing: 0) {
                    statCell(
                        label: "Added",
                        value: project.linesAdded.map { "+\($0)" } ?? "--",
                        color: .green
                    )
                    statCell(
                        label: "Removed",
                        value: project.linesRemoved.map { "-\($0)" } ?? "--",
                        color: .red
                    )
                    statCell(
                        label: "Velocity",
                        value: project.codeVelocity ?? "--",
                        color: .primary
                    )
                }

                // Row 2: Cache Hits | Cost/Line | Messages
                HStack(spacing: 0) {
                    statCell(
                        label: "Cache Hits",
                        value: project.cacheHitRatio ?? "--",
                        color: .primary
                    )
                    statCell(
                        label: "Cost/Line",
                        value: project.costPerLine ?? "--",
                        color: .primary
                    )
                    statCell(
                        label: "Messages",
                        value: "\(project.messageCount)",
                        color: .primary
                    )
                }

                // Row 3: Web Searches | Web Fetches | Lines Changed
                HStack(spacing: 0) {
                    statCell(
                        label: "Searches",
                        value: "\(project.webSearchCount)",
                        color: .primary
                    )
                    statCell(
                        label: "Fetches",
                        value: "\(project.webFetchCount)",
                        color: .primary
                    )
                    statCell(
                        label: "Changed",
                        value: "\(project.totalLinesChanged)",
                        color: .primary
                    )
                }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.3))
        .cornerRadius(8)
    }

    private func statCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func costColor(for cost: Double?) -> Color {
        guard let cost else { return .primary }
        if cost >= 5.0 { return .red }
        if cost >= 2.0 { return .orange }
        return .primary
    }

    private func formatTokens(_ count: Int?) -> String {
        guard let count else { return "--" }
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        }
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000)
        }
        return "\(count)"
    }

    private func relativeTime(_ date: Date) -> String {
        let secs = Int(Date().timeIntervalSince(date))
        if secs < 5 { return "just now" }
        if secs < 60 { return "\(secs)s ago" }
        if secs < 3600 { return "\(secs / 60)m ago" }
        return "\(secs / 3600)h ago"
    }
}
