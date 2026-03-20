import SwiftUI
import SondeCore

/// Full settings tab that replaces the dashboard content area.
struct SettingsTab: View {
    let theme: PopoverTheme
    @Binding var showCosts: Bool
    @Binding var themeName: String
    @Binding var showSettings: Bool
    @AppStorage("appearanceMode") var appearanceMode: String = "auto"
    @AppStorage("showMenuBarCost") var showMenuBarCost: Bool = true
    @AppStorage("showMenuBarPromo") var showMenuBarPromo: Bool = true
    @AppStorage("showMenuBarCountdown") var showMenuBarCountdown: Bool = true
    @AppStorage("menuBarTimerMode") var menuBarTimerMode: String = "5h_left"
    @AppStorage("pollInterval") var pollInterval: Double = 30

    private let appearanceOptions: [(String, String)] = [
        ("auto", "Auto"),
        ("light", "Light"),
        ("dark", "Dark"),
    ]

    private let timerOptions: [(String, String)] = [
        ("5h_left", "5h time left"),
        ("5h_elapsed", "5h elapsed"),
        ("5h_reset_time", "5h resets at"),
        ("7d_left", "7d time left"),
        ("7d_reset_time", "7d resets at"),
        ("promo_left", "Promo time left"),
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
                        .foregroundColor(rowTextColor)
                    Spacer()
                    Text("Dashboard").font(.system(size: 11)).hidden()
                }

                // MENU BAR
                sectionCard("MENU BAR") {
                    settingsRow("Show cost") {
                        sondeToggle($showMenuBarCost)
                    }
                    thinDivider
                    settingsRow("Show promo status") {
                        sondeToggle($showMenuBarPromo)
                    }
                    thinDivider
                    settingsRow("Show timer") {
                        sondeToggle($showMenuBarCountdown)
                    }
                    thinDivider
                    HStack {
                        Text("Timer shows")
                            .font(.system(size: 12))
                            .foregroundColor(rowTextColor)
                        Spacer()
                        themedMenu(
                            selection: $menuBarTimerMode,
                            options: timerOptions,
                            label: { timerOptions.first { $0.0 == menuBarTimerMode }?.1 ?? "5h time left" }
                        )
                    }
                    .padding(.vertical, 3)
                    .opacity(showMenuBarCountdown ? 1.0 : 0.3)
                    .allowsHitTesting(showMenuBarCountdown)
                }

                // DISPLAY
                sectionCard("DISPLAY") {
                    settingsRow("Show costs") {
                        sondeToggle($showCosts)
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
                                    .foregroundColor(dropdownTextColor)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(dropdownTextColor.opacity(0.6))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(dropdownBgColor, in: RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.borderless)
                    }
                    thinDivider
                    // Light/Dark — always visible, greyed when not System theme
                    HStack {
                        Text("Light / Dark")
                            .font(.system(size: 12))
                            .foregroundColor(rowTextColor)
                        Spacer()
                        themedMenu(
                            selection: $appearanceMode,
                            options: appearanceOptions,
                            label: { appearanceOptions.first { $0.0 == appearanceMode }?.1 ?? "Auto" }
                        )
                    }
                    .padding(.vertical, 3)
                    .opacity(theme == .system ? 1.0 : 0.3)
                    .allowsHitTesting(theme == .system)
                }

                // DATA (bottom)
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

    /// Whether the current theme has a dark card background.
    private var isDarkTheme: Bool { theme.isDark }

    /// Text color for row labels.
    private var rowTextColor: Color {
        isDarkTheme ? Color(white: 0.95) : Color(white: 0.08)
    }

    /// Accent color for dropdown buttons.
    private var dropdownTextColor: Color {
        isDarkTheme ? theme.headerAccent : Color(red: 0.15, green: 0.2, blue: 0.65)
    }

    /// Background for dropdown pills.
    private var dropdownBgColor: Color {
        isDarkTheme ? theme.headerAccent.opacity(0.15) : Color(red: 0.15, green: 0.2, blue: 0.65).opacity(0.1)
    }

    /// Toggle accent color.
    private var toggleAccent: Color {
        isDarkTheme ? theme.headerAccent : Color(red: 0.15, green: 0.2, blue: 0.65)
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
                    .foregroundColor(dropdownTextColor)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(dropdownTextColor.opacity(0.6))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(dropdownBgColor, in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.borderless)
    }

    private var thinDivider: some View {
        Divider().overlay(theme.borderColor.opacity(0.5))
    }

    /// Custom pill toggle that matches the theme.
    @ViewBuilder
    private func sondeToggle(_ isOn: Binding<Bool>) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { isOn.wrappedValue.toggle() }
        } label: {
            ZStack(alignment: isOn.wrappedValue ? .trailing : .leading) {
                Capsule()
                    .fill(isOn.wrappedValue ? toggleAccent : (isDarkTheme ? Color(white: 0.3) : Color(white: 0.78)))
                    .frame(width: 36, height: 20)
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                    .frame(width: 16, height: 16)
                    .padding(.horizontal, 2)
            }
        }
        .buttonStyle(.borderless)
    }
}
