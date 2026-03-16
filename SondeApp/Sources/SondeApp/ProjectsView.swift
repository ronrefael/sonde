import SondeCore
import SwiftUI

/// Shows a list of all active projects with drill-down detail.
struct ProjectsView: View {
    let projects: [ProjectSession]
    @Binding var showProjects: Bool
    @State private var selectedProject: ProjectSession?

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
                }
                .padding(16)
            }
        }
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
