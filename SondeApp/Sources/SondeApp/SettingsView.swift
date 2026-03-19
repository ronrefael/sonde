import SwiftUI
import SondeCore

struct SettingsView: View {
    let theme: PopoverTheme
    @Binding var showCosts: Bool
    @Binding var themeName: String
    @AppStorage("showMenuBarCost") var showMenuBarCost: Bool = true
    @AppStorage("showMenuBarPromo") var showMenuBarPromo: Bool = true
    @AppStorage("showMenuBarCountdown") var showMenuBarCountdown: Bool = true
    @AppStorage("pollInterval") var pollInterval: Double = 30
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 20, height: 20)
                        .background(theme.borderColor.opacity(0.5), in: Circle())
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Scrollable content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    // Menu Bar
                    settingsSection("Menu Bar") {
                        settingsToggle("Show cost", isOn: $showMenuBarCost)
                        settingsToggle("Show promo status", isOn: $showMenuBarPromo)
                        settingsToggle("Show reset countdown", isOn: $showMenuBarCountdown)
                    }

                    // Display
                    settingsSection("Display") {
                        settingsToggle("Show costs in popover", isOn: $showCosts)

                        HStack {
                            Text("Theme")
                                .font(.system(size: 11))
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                            Menu {
                                ForEach(PopoverTheme.allCases, id: \.rawValue) { t in
                                    Button {
                                        themeName = t.rawValue
                                    } label: {
                                        HStack {
                                            Circle()
                                                .fill(t.swatchColor)
                                                .frame(width: 8, height: 8)
                                            Text(t.rawValue)
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(theme.swatchColor)
                                        .frame(width: 6, height: 6)
                                    Text(themeName)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(theme.textPrimary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 8))
                                        .foregroundStyle(theme.textSecondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(theme.borderColor.opacity(0.4), in: RoundedRectangle(cornerRadius: 5))
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    // Data
                    settingsSection("Data") {
                        HStack {
                            Text("Refresh interval")
                                .font(.system(size: 11))
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                            HStack(spacing: 2) {
                                ForEach([(15.0, "15s"), (30.0, "30s"), (60.0, "60s"), (120.0, "2m")], id: \.0) { val, label in
                                    Button {
                                        pollInterval = val
                                    } label: {
                                        Text(label)
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundStyle(pollInterval == val ? theme.popoverBackground : theme.textSecondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(
                                                pollInterval == val ? theme.headerAccent : theme.borderColor.opacity(0.4),
                                                in: RoundedRectangle(cornerRadius: 4)
                                            )
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
        .frame(width: 260, height: 320)
        .background(theme.popoverBackground)
    }

    // MARK: - Components

    @ViewBuilder
    private func settingsSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(theme.headerAccent)
                .tracking(0.8)

            VStack(spacing: 6) {
                content()
            }
            .padding(10)
            .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.borderColor, lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func settingsToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(theme.headerAccent)
                .labelsHidden()
        }
    }
}
