import SwiftUI
import SondeCore

/// Full settings tab that replaces the dashboard content area.
struct SettingsTab: View {
    let theme: PopoverTheme
    @Binding var themeName: String
    @Binding var showSettings: Bool
    @AppStorage("appearanceMode") var appearanceMode: String = "auto"
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
                        chipPicker(
                            selection: $menuBarTimerMode,
                            options: timerOptions,
                        )
                    }
                    .padding(.vertical, 3)
                    .opacity(showMenuBarCountdown ? 1.0 : 0.3)
                    .allowsHitTesting(showMenuBarCountdown)
                }

                // DISPLAY
                sectionCard("DISPLAY") {
                    settingsRow("Theme") {
                        ThemeChipPicker(
                            selection: $themeName,
                            accentColor: theme.headerAccent,
                            isDark: isDarkTheme,
                            currentSwatch: theme.swatchColor
                        )
                    }
                    thinDivider
                    // Light/Dark — always visible, greyed when not System theme
                    HStack {
                        Text("Light / Dark")
                            .font(.system(size: 12))
                            .foregroundColor(rowTextColor)
                        Spacer()
                        chipPicker(
                            selection: $appearanceMode,
                            options: appearanceOptions,
                        )
                    }
                    .padding(.vertical, 3)
                    .opacity(theme == .system || theme == .sonde ? 1.0 : 0.3)
                    .allowsHitTesting(theme == .system || theme == .sonde)
                }

                // DATA (bottom)
                sectionCard("DATA") {
                    settingsRow("Refresh interval") {
                        chipPicker(
                            selection: $pollInterval,
                            options: intervalOptions,
                        )
                    }
                    thinDivider
                    settingsRow("Run setup again") {
                        Button {
                            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                            withAnimation(.easeInOut(duration: 0.2)) { showSettings = false }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 10))
                                Text("Reset")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(theme.headerAccent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(theme.headerAccent.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Components

    private var useSoftCards: Bool {
        theme == .system || theme == .sonde
    }

    @ViewBuilder
    private func sectionCard(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(theme.headerAccent)
                .tracking(0.8)
                .padding(.bottom, 6)

            let card = VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 10))

            if useSoftCards {
                card.shadow(color: Color.black.opacity(0.15), radius: 8, y: 2)
            } else {
                card.overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(theme.borderColor, lineWidth: 1)
                )
            }
        }
    }

    /// Whether the current theme has a dark card background.
    /// Liquid Glass is translucent — needs dark text despite isDark=true.
    private var isDarkTheme: Bool {
        if theme == .liquidGlass { return false }
        return theme.isDark
    }

    /// Text color for row labels.
    private var rowTextColor: Color {
        if theme == .liquidGlass { return Color(white: 0.15) }
        return isDarkTheme ? Color(white: 0.95) : Color(white: 0.08)
    }

    /// Toggle accent color.
    private var toggleAccent: Color {
        isDarkTheme ? theme.headerAccent : SondeColors.settingsLightBlue
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

    /// Chip-style picker — selected value shows as an accent chip.
    /// Tapping opens a popover with all options as selectable chips.
    @ViewBuilder
    private func chipPicker<T: Equatable>(
        selection: Binding<T>,
        options: [(T, String)],
        icon: String? = nil
    ) -> some View {
        ChipPickerButton(
            selection: selection,
            options: options,
            icon: icon,
            accentColor: theme.headerAccent,
            textColor: rowTextColor,
            isDark: isDarkTheme,
            cardBg: theme.cardBackground,
            borderColor: theme.borderColor
        )
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

// MARK: - Chip Picker

/// A chip-style picker button that shows the selected value as an accent chip.
/// Tapping opens a popover with all options displayed as selectable chips with hover animation.
private struct ChipPickerButton<T: Equatable>: View {
    @Binding var selection: T
    let options: [(T, String)]
    let icon: String?
    let accentColor: Color
    let textColor: Color
    let isDark: Bool
    let cardBg: Color
    let borderColor: Color

    @State private var showPicker = false
    @State private var hoveredIndex: Int?

    private var selectedLabel: String {
        options.first { $0.0 == selection }?.1 ?? ""
    }

    var body: some View {
        Button { showPicker.toggle() } label: {
            HStack(spacing: 5) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 9))
                        .foregroundColor(accentColor)
                }
                Text(selectedLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isDark ? .white : accentColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                accentColor.opacity(isDark ? 0.2 : 0.12),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(accentColor.opacity(isDark ? 0.3 : 0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.borderless)
        .popover(isPresented: $showPicker, arrowEdge: .trailing) {
            chipGrid
        }
    }

    private var chipGrid: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(options.enumerated()), id: \.offset) { idx, option in
                let isSelected = selection == option.0
                let isHovered = hoveredIndex == idx

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selection = option.0
                    }
                    showPicker = false
                } label: {
                    HStack(spacing: 8) {
                        // Selection indicator
                        Circle()
                            .fill(isSelected ? accentColor : accentColor.opacity(0.15))
                            .frame(width: 8, height: 8)
                            .overlay(
                                isSelected
                                    ? Circle().stroke(Color.white.opacity(0.8), lineWidth: 1.5).frame(width: 5, height: 5)
                                    : nil
                            )

                        Text(option.1)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                            .foregroundColor(isSelected ? accentColor : textColor)

                        Spacer()

                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(accentColor)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        isSelected
                            ? accentColor.opacity(isDark ? 0.15 : 0.08)
                            : isHovered
                                ? accentColor.opacity(isDark ? 0.08 : 0.04)
                                : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                    .scaleEffect(isHovered && !isSelected ? 1.02 : 1.0)
                    .animation(.easeOut(duration: 0.12), value: isHovered)
                }
                .buttonStyle(.borderless)
                .onHover { hovering in
                    hoveredIndex = hovering ? idx : nil
                }
            }
        }
        .padding(8)
        .frame(minWidth: 180)
        .background(isDark ? SondeColors.chipGridDarkBg : .white)
    }
}

// MARK: - Theme Chip Picker

/// Special chip picker for themes — shows color swatch in chip and popover.
private struct ThemeChipPicker: View {
    @Binding var selection: String
    let accentColor: Color
    let isDark: Bool
    let currentSwatch: Color

    @State private var showPicker = false
    @State private var hoveredTheme: String?

    var body: some View {
        Button { showPicker.toggle() } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(currentSwatch)
                    .frame(width: 8, height: 8)
                Text(selection)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isDark ? .white : accentColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                accentColor.opacity(isDark ? 0.2 : 0.12),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(accentColor.opacity(isDark ? 0.3 : 0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.borderless)
        .popover(isPresented: $showPicker, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(PopoverTheme.allCases, id: \.rawValue) { t in
                    let isSelected = selection == t.rawValue
                    let isHovered = hoveredTheme == t.rawValue

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selection = t.rawValue
                        }
                        showPicker = false
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(t.swatchColor)
                                .frame(width: 10, height: 10)
                                .overlay(
                                    isSelected
                                        ? Circle().stroke(Color.white, lineWidth: 2).frame(width: 14, height: 14)
                                        : nil
                                )

                            Text(t.rawValue)
                                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? t.swatchColor : (isDark ? .white : Color(white: 0.15)))

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(t.swatchColor)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            isSelected
                                ? t.swatchColor.opacity(isDark ? 0.15 : 0.08)
                                : isHovered
                                    ? t.swatchColor.opacity(isDark ? 0.08 : 0.04)
                                    : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .scaleEffect(isHovered && !isSelected ? 1.02 : 1.0)
                        .animation(.easeOut(duration: 0.12), value: isHovered)
                    }
                    .buttonStyle(.borderless)
                    .onHover { hovering in
                        hoveredTheme = hovering ? t.rawValue : nil
                    }
                }
            }
            .padding(8)
            .frame(minWidth: 180)
            .background(isDark ? SondeColors.chipGridDarkBg : .white)
        }
    }
}
