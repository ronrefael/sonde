import Foundation
import UserNotifications

/// Manages usage threshold notifications.
/// Fires once per threshold crossing, resets when usage drops back down.
/// Sends both UNUserNotificationCenter alerts and in-app toast notifications.
@MainActor
public final class NotificationManager {
    public static let shared = NotificationManager()

    private var fiveHourNotified: Set<Threshold> = []
    private var sevenDayNotified: Set<Threshold> = []
    private var hasPermission = false
    private var budgetNotifiedToday: Bool = false
    private var budgetNotifiedDate: Date?

    /// Callback for in-app toast notifications (set by the app layer).
    /// Parameters: (message: String, icon: String?)
    public var toastHandler: ((String, String?) -> Void)?

    enum Threshold: Double, CaseIterable, Hashable {
        case warning = 60.0
        case critical = 80.0
        case danger = 90.0
    }

    private init() {}

    public func requestPermission() {
        // Guard: UNUserNotificationCenter crashes in unbundled SPM binaries
        guard Bundle.main.bundleIdentifier != nil else { return }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            Task { @MainActor in
                self?.hasPermission = granted
            }
        }
    }

    /// Check usage and fire notifications if thresholds crossed.
    public func checkAndNotify(fiveHourUtil: Double?, sevenDayUtil: Double?) {
        if let fh = fiveHourUtil {
            checkThresholds(utilization: fh, window: "5h", notified: &fiveHourNotified)
        }
        if let sd = sevenDayUtil {
            checkThresholds(utilization: sd, window: "7d", notified: &sevenDayNotified)
        }
    }

    /// Check if daily budget is exceeded and fire a notification (once per day).
    public func checkBudget(total: Double, budget: Double) {
        guard budget > 0, total >= budget else { return }

        // Reset flag on new calendar day
        let today = Calendar.current.startOfDay(for: Date())
        if let lastDate = budgetNotifiedDate, lastDate < today {
            budgetNotifiedToday = false
        }

        guard !budgetNotifiedToday else { return }
        budgetNotifiedToday = true
        budgetNotifiedDate = today

        // Toast notification (always works, no permission needed)
        let toastMsg = String(format: "Budget exceeded: $%.2f", total)
        toastHandler?(toastMsg, "\u{1F6A8}") // 🚨

        // System notification (if permission granted)
        guard hasPermission else { return }

        let content = UNMutableNotificationContent()
        content.title = "sonde: Daily budget exceeded"
        content.body = String(format: "You've spent $%.2f today (budget: $%.2f).", total, budget)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "sonde.budget.\(today.timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Notify that a promo period has started.
    public func notifyPromoStart(label: String) {
        toastHandler?("\(label) starts now!", "\u{1F7E2}") // 🟢
    }

    private func checkThresholds(utilization: Double, window: String, notified: inout Set<Threshold>) {
        for threshold in Threshold.allCases {
            if utilization >= threshold.rawValue && !notified.contains(threshold) {
                notified.insert(threshold)
                sendNotification(window: window, utilization: utilization, threshold: threshold)
            } else if utilization < threshold.rawValue && notified.contains(threshold) {
                notified.remove(threshold)
            }
        }
    }

    private func sendNotification(window: String, utilization: Double, threshold: Threshold) {
        // Toast notification (always works)
        let icon: String
        let toastMsg: String
        switch threshold {
        case .warning:
            icon = "\u{26A0}\u{FE0F}" // ⚠️
            toastMsg = "\(window) usage: \(Int(utilization))%"
        case .critical:
            icon = "\u{1F525}" // 🔥
            toastMsg = "\(window) usage: \(Int(utilization))%"
        case .danger:
            icon = "\u{26D4}" // ⛔
            toastMsg = "\(window) usage critical: \(Int(utilization))%"
        }
        toastHandler?(toastMsg, icon)

        // System notification (if permission granted)
        guard hasPermission else { return }

        let content = UNMutableNotificationContent()

        switch threshold {
        case .warning:
            content.title = "sonde: \(window) usage at \(Int(utilization))%"
            content.body = "Consider pacing your usage. Window resets soon."
        case .critical:
            content.title = "sonde: \(window) usage at \(Int(utilization))%"
            content.body = "Usage is getting high. You may hit rate limits."
        case .danger:
            content.title = "sonde: \(window) usage critical — \(Int(utilization))%"
            content.body = "Rate limiting is imminent. Consider switching to a lighter model."
        }

        content.sound = threshold == .danger ? .default : nil

        let request = UNNotificationRequest(
            identifier: "sonde.\(window).\(threshold.rawValue)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
