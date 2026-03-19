import SwiftUI
import SondeCore

/// Full settings tab that replaces the dashboard content area.
struct SettingsTab: View {
    let theme: PopoverTheme
    @Binding var showCosts: Bool
    @Binding var themeName: String
    @Binding var showSettings: Bool
    @AppStorage("showMenuBarCost") var showMenuBarCost: Bool = true
    @AppStorage("showMenuBarPromo") var showMenuBarPromo: Bool = true
    @AppStorage("showMenuBarCountdown") var showMenuBarCountdown: Bool = true
    @AppStorage("menuBarTimerMode") var menuBarTimerMode: String = "5h_left"
    @AppStorage("pollInterval") var pollInterval: Double = 30

    private let timerOptions: [(String, String)] = [
        ("5h_left", "5h — Time left"),
        ("5h_elapsed", "5h — Time elapsed"),
        ("5h_reset_time", "5h — Resets at"),
        ("7d_left", "7d — Time left"),
        ("7d_reset_time", "7d — Resets at"),
        ("promo_left", "Promo — Time left"),
        ("session", "Session duration"),
    ]

    private let intervalOptions: [(Double, String)] = [
        (15, "15 sec"),
        (30, "30 sec"),
        (60, "1 min"),
        (120, "2 min"),
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                // Header
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showSettings = false }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Dashboard")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(theme.headerAccent)
                    }
                    .buttonStyle(.borderless)
                    Spacer()
                    Text("Settings")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Text("Dashboard").font(.system(size: 11)).hidden()
                }

                // MENU BAR
                sectionCard("MENU BAR") {
                    settingsRow("Show cost") {
                        Toggle("", isOn: $showMenuBarCost)
                            .toggleStyle(.switch).controlSize(.mini)
                            .tint(theme.headerAccent).labelsHidden()
                    }
                    thinDivider
                    settingsRow("Show promo status") {
                        Toggle("", isOn: $showMenuBarPromo)
                            .toggleStyle(.switch).controlSize(.mini)
                            .tint(theme.headerAccent).labelsHidden()
                    }
                    thinDivider
                    settingsRow("Show timer") {
                        Toggle("", isOn: $showMenuBarCountdown)
                            .toggleStyle(.switch).controlSize(.mini)
                            .tint(theme.headerAccent).labelsHidden()
                    }
                    if showMenuBarCountdown {
                        thinDivider
                        settingsRow("Timer shows") {
                            themedMenu(
                                selection: $menuBarTimerMode,
                                options: timerOptions,
                                label: { timerOptions.first { $0.0 == menuBarTimerMode }?.1 ?? "5h — Time left" }
                            )
                        }
                    }
                }

                // DISPLAY
                sectionCard("DISPLAY") {
                    settingsRow("Show costs") {
                        Toggle("", isOn: $showCosts)
                            .toggleStyle(.switch).controlSize(.mini)
                            .tint(theme.headerAccent).labelsHidden()
                    }
                    thinDivider
                    settingsRow("Theme") {
                        Menu {
                            ForEach(PopoverTheme.allCases, id: \.rawValue) { t in
                                Button {
                                    themeName = t.rawValue
                                } label: {
                                    Label {
                                        Text(t.rawValue)
                                    } icon: {
                                        Image(systemName: t.rawValue == themeName ? "checkmark.circle.fill" : "circle.fill")
                                            .foregroundStyle(t.swatchColor)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(theme.swatchColor)
                                    .frame(width: 8, height: 8)
                                Text(themeName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(theme.headerAccent)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(theme.headerAccent.opacity(0.6))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.headerAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.borderless)
                    }
                }

                // DATA
                sectionCard("DATA") {
                    settingsRow("Refresh interval") {
                        themedMenu(
                            selection: $pollInterval,
                            options: intervalOptions,
                            label: { intervalOptions.first { $0.0 == pollInterval }?.1 ?? "30 sec" }
                        )
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Components

    @ViewBuilder
    private func sectionCard(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(theme.headerAccent)
                .tracking(0.8)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.borderColor, lineWidth: 1)
            )
        }
    }

    /// Text color that's always readable on the card background.
    private var rowTextColor: Color {
        switch theme {
        case .system, .liquidGlass: return .primary
        default: return .white
        }
    }

    @ViewBuilder
    private func settingsRow(_ label: String, @ViewBuilder trailing: () -> some View) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(rowTextColor)
            Spacer()
            trailing()
        }
        .padding(.vertical, 3)
    }

    /// A themed dropdown menu that uses theme colors for the button label.
    @ViewBuilder
    private func themedMenu<T: Equatable>(
        selection: Binding<T>,
        options: [(T, String)],
        label: () -> String
    ) -> some View {
        Menu {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                Button {
                    selection.wrappedValue = option.0
                } label: {
                    HStack {
                        Text(option.1)
                        if selection.wrappedValue == option.0 {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(label())
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.headerAccent)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(theme.headerAccent.opacity(0.6))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.headerAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.borderless)
    }

    private var thinDivider: some View {
        Divider().overlay(theme.borderColor.opacity(0.5))
    }
}
