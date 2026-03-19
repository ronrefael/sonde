import Combine
import Foundation
import os.log
import SwiftUI

private let logger = Logger(subsystem: "dev.sonde.app", category: "ViewModel")

/// Main view model that aggregates all data sources.
@MainActor
public final class SondeViewModel: ObservableObject {
    // Usage limits
    @Published public var fiveHourUtil: Double?
    @Published public var fiveHourReset: String?
    @Published public var sevenDayUtil: Double?
    @Published public var sevenDayReset: String?
    @Published public var extraUsageUtil: Double?

    // Promo
    @Published public var promoActive: Bool = false
    @Published public var promoEmoji: String = ""
    @Published public var promoLabel: String = ""
    @Published public var promoCountdown: String = ""
    @Published public var promoCountdownLabel: String = ""
    @Published public var promoDescription: String = ""
    @Published public var promoUrl: String = ""

    // Pacing
    @Published public var paceTier: PaceTier = .comfortable
    @Published public var pacePredict: String?

    // Session
    @Published public var session: SessionData = SessionData()
    @Published public var allSessions: [SessionData] = []
    @Published public var allProjects: [ProjectSession] = []

    // Codex
    @Published public var codexCost: Double?

    // Daily spend
    @Published public var dailyClaudeCost: Double = 0
    @Published public var dailyCodexCost: Double = 0

    // Live session timer
    @Published public var liveSessionDuration: String = "--"

    // Cost/time checkpoint ("mark") — user can reset to track from a point
    @Published public var markActive: Bool = false
    @Published public var costSinceMark: Double = 0
    @Published public var timeSinceMark: String = "--"
    private var markDate: Date?
    private var markCost: Double = 0

    // Extra usage details
    @Published public var extraUsageEnabled: Bool = false
    @Published public var extraUsageMonthlyLimit: Double?
    @Published public var extraUsageUsedCredits: Double?

    // Agents
    @Published public var activeSessions: [AgentSession] = []

    // Watcher window
    @Published public var showWatcher: Bool = false

    // Usage history (sparkline)
    @Published public var usageHistory: [Double] = []

    // Update
    @Published public var updateAvailable: String?

    // Budget
    @AppStorage("dailyBudget") public var dailyBudget: Double = 0
    @Published public var budgetExceeded: Bool = false

    // Usage history (daily chart)
    @Published public var dailyHistory: [DailySnapshot] = []

    // State
    @Published public var isLoading: Bool = true
    @Published public var lastUpdated: Date?

    private let usageService = UsageService()
    private let promoService = PromoService()
    private let agentWatcher = AgentWatcher()
    private let sessionReader = SessionReader()
    private let codexCostReader = CodexCostReader()
    private let dailySpendTracker = DailySpendTracker()
    private let updateChecker = UpdateChecker()
    private let promoDetector = PromoDetector()
    private let usageHistoryTracker = UsageHistoryTracker()
    private var pollTimer: Timer?
    private var sessionTimer: Timer?
    private var sessionStartTime: Date?
    private var hasCheckedForUpdate = false

    public init() {
        NotificationManager.shared.requestPermission()
    }

    deinit {
        pollTimer?.invalidate()
        sessionTimer?.invalidate()
    }

    /// Set a checkpoint — track cost/time from this moment.
    public func setMark() {
        markDate = Date()
        markCost = session.sessionCost ?? 0
        markActive = true
        costSinceMark = 0
        timeSinceMark = "0m 00s"
    }

    /// Clear the checkpoint.
    public func clearMark() {
        markActive = false
        markDate = nil
        markCost = 0
        costSinceMark = 0
        timeSinceMark = "--"
    }

    public func startPolling(interval: TimeInterval = 30) {
        stopPolling()
        Task { await refresh() }
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.refresh()
            }
        }
    }

    public func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        sessionTimer?.invalidate()
        sessionTimer = nil
    }

    private func startSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard let start = self.sessionStartTime else { return }
                let elapsed = Int(Date().timeIntervalSince(start))
                let h = elapsed / 3600
                let m = (elapsed % 3600) / 60
                let s = elapsed % 60
                let new: String
                if h > 0 {
                    new = String(format: "%dh %02dm %02ds", h, m, s)
                } else {
                    new = String(format: "%dm %02ds", m, s)
                }
                if self.liveSessionDuration != new { self.liveSessionDuration = new }

                // Update mark timer
                if self.markActive, let markStart = self.markDate {
                    let markElapsed = Int(Date().timeIntervalSince(markStart))
                    let mh = markElapsed / 3600
                    let mm = (markElapsed % 3600) / 60
                    let ms = markElapsed % 60
                    let markStr: String
                    if mh > 0 {
                        markStr = String(format: "%dh %02dm %02ds", mh, mm, ms)
                    } else {
                        markStr = String(format: "%dm %02ds", mm, ms)
                    }
                    if self.timeSinceMark != markStr { self.timeSinceMark = markStr }

                    let currentCost = self.session.sessionCost ?? 0
                    let delta = max(0, currentCost - self.markCost)
                    if self.costSinceMark != delta { self.costSinceMark = delta }
                }
            }
        }
    }

    /// Build a JSON string summarising current usage data for export.
    public func exportJSONString() -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        var dict: [String: Any] = [:]

        // Current session
        var sessionDict: [String: Any] = [:]
        sessionDict["model"] = session.modelName ?? "unknown"
        sessionDict["cost"] = session.sessionCost ?? 0
        sessionDict["duration"] = liveSessionDuration
        sessionDict["context_tokens_used"] = session.contextTokensUsed
        sessionDict["context_window_size"] = session.contextWindowSize ?? 0
        sessionDict["context_used_pct"] = session.contextUsedPct ?? 0
        dict["current_session"] = sessionDict

        // Usage limits
        var limits: [String: Any] = [:]
        limits["five_hour_pct"] = fiveHourUtil ?? 0
        limits["seven_day_pct"] = sevenDayUtil ?? 0
        limits["five_hour_reset"] = fiveHourReset ?? ""
        limits["seven_day_reset"] = sevenDayReset ?? ""
        dict["usage_limits"] = limits

        // Daily spend
        var daily: [String: Any] = [:]
        daily["claude"] = dailyClaudeCost
        daily["codex"] = dailyCodexCost
        daily["total"] = dailyClaudeCost + dailyCodexCost
        dict["daily_spend"] = daily

        // Promo
        var promo: [String: Any] = [:]
        promo["active"] = promoActive
        promo["label"] = promoLabel
        promo["emoji"] = promoEmoji
        dict["promo"] = promo

        // Sessions
        dict["active_sessions_count"] = activeSessions.count
        var sessionsArray: [[String: Any]] = []
        for s in allSessions {
            var sDict: [String: Any] = [:]
            sDict["session_id"] = s.sessionId ?? "unknown"
            sDict["model"] = s.modelName ?? "unknown"
            sDict["cost"] = s.sessionCost ?? 0
            sDict["context_used_pct"] = s.contextUsedPct ?? 0
            sDict["project"] = s.projectName ?? "unknown"
            sessionsArray.append(sDict)
        }
        dict["sessions"] = sessionsArray

        // Timestamp
        dict["exported_at"] = iso.string(from: Date())

        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return str
    }

    public func refresh() async {
        // Guard against fetches that hang indefinitely
        let result: (UsageData?, Date?, [AgentSession], SessionData, Double?)? = await withTaskGroup(of: (UsageData?, Date?, [AgentSession], SessionData, Double?)?.self) { group in
            group.addTask { @MainActor [usageService, agentWatcher, sessionReader, codexCostReader] in
                async let usageTask = usageService.fetchUsage()
                async let sessionsTask = agentWatcher.getActiveSessions()
                async let sessionTask = sessionReader.getSessionData()
                async let codexTask = codexCostReader.getSessionCost()
                let (u, ts) = await usageTask
                return (u, ts, await sessionsTask, await sessionTask, await codexTask)
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10s timeout
                return nil
            }
            // Return whichever finishes first; if timeout wins, we get nil
            for await value in group {
                if let value { group.cancelAll(); return value }
            }
            return nil
        }
        guard let (usage, _, sessions, newSession, newCodexCost) = result else {
            logger.warning("refresh() timed out after 10s")
            if isLoading { isLoading = false }
            return
        }

        // Last updated — use current time whenever we complete a refresh
        lastUpdated = Date()

        // Usage
        let newFiveHourUtil = usage?.fiveHour?.utilization
        let newFiveHourReset = usage?.fiveHour?.resetsAt
        let newSevenDayUtil = usage?.sevenDay?.utilization
        let newSevenDayReset = usage?.sevenDay?.resetsAt
        let newExtraUsageUtil = usage?.extraUsage?.utilization
        // Promo: use PromoSchedule (local) for real-time status,
        // PromoDetector (official support page) for promo existence + URL
        let transition = PromoSchedule.nextTransition()
        let detectedPromo = await promoDetector.detectPromo()

        let newPromoActive = detectedPromo != nil && transition.isCurrentlyOffpeak
        let newPromoEmoji = "" // No emoji — using SF Symbols now
        let newPromoLabel = detectedPromo?.title ?? (transition.isCurrentlyOffpeak ? "2X — Off-peak limits active" : "")

        let fhChanged = fiveHourUtil != newFiveHourUtil
        let sdChanged = sevenDayUtil != newSevenDayUtil

        if fhChanged { fiveHourUtil = newFiveHourUtil }
        if fiveHourReset != newFiveHourReset { fiveHourReset = newFiveHourReset }
        if sdChanged { sevenDayUtil = newSevenDayUtil }
        if sevenDayReset != newSevenDayReset { sevenDayReset = newSevenDayReset }
        if extraUsageUtil != newExtraUsageUtil { extraUsageUtil = newExtraUsageUtil }
        if promoActive != newPromoActive { promoActive = newPromoActive }
        if promoEmoji != newPromoEmoji { promoEmoji = newPromoEmoji }
        if promoLabel != newPromoLabel { promoLabel = newPromoLabel }

        // Promo countdown (from PromoSchedule — local calculation)
        if promoCountdownLabel != transition.label { promoCountdownLabel = transition.label }
        if promoCountdown != transition.timeRemaining { promoCountdown = transition.timeRemaining }

        // Promo URL + description from detector
        let newPromoUrl = detectedPromo?.url ?? ""
        if promoUrl != newPromoUrl { promoUrl = newPromoUrl }
        let newPromoDesc: String
        if let detected = detectedPromo {
            newPromoDesc = "\(detected.title). Click to view announcement."
        } else if transition.isCurrentlyOffpeak {
            newPromoDesc = "Off-peak hours — increased rate limits."
        } else {
            newPromoDesc = "Normal rate limits during peak hours."
        }
        if promoDescription != newPromoDesc { promoDescription = newPromoDesc }

        // Codex cost
        if codexCost != newCodexCost { codexCost = newCodexCost }

        // Extra usage details
        let newExtraEnabled = usage?.extraUsage?.isEnabled ?? false
        let newExtraMonthly = usage?.extraUsage?.monthlyLimit
        let newExtraUsed = usage?.extraUsage?.usedCredits
        if extraUsageEnabled != newExtraEnabled { extraUsageEnabled = newExtraEnabled }
        if extraUsageMonthlyLimit != newExtraMonthly { extraUsageMonthlyLimit = newExtraMonthly }
        if extraUsageUsedCredits != newExtraUsed { extraUsageUsedCredits = newExtraUsed }

        if let util = newFiveHourUtil {
            let newTier = PaceTier.calculate(utilization: util, promoActive: newPromoActive)
            if paceTier != newTier { paceTier = newTier }

            // Pace prediction
            let newPredict = PaceTier.predictTimeToLimit(utilization: util, resetsAt: newFiveHourReset)
            if pacePredict != newPredict { pacePredict = newPredict }

            // Usage history (sparkline)
            usageHistory.append(util)
            if usageHistory.count > 30 { usageHistory.removeFirst(usageHistory.count - 30) }
        }

        if session != newSession { session = newSession }
        if activeSessions != sessions { activeSessions = sessions }

        // Refresh all active sessions from per-session cache files
        let newAllSessions = await sessionReader.getAllActiveSessions()
        if allSessions != newAllSessions { allSessions = newAllSessions }

        // Refresh allProjects from session reader
        let newProjects = await sessionReader.getAllProjects()
        if allProjects != newProjects { allProjects = newProjects }

        // Daily spend tracking
        let daily = dailySpendTracker.update(claudeSessionCost: newSession.sessionCost, codexSessionCost: newCodexCost)
        if dailyClaudeCost != daily.claude { dailyClaudeCost = daily.claude }
        if dailyCodexCost != daily.codex { dailyCodexCost = daily.codex }

        // Budget check
        let totalSpend = daily.claude + daily.codex
        let exceeded = dailyBudget > 0 && totalSpend >= dailyBudget
        if budgetExceeded != exceeded { budgetExceeded = exceeded }
        if exceeded {
            NotificationManager.shared.checkBudget(total: totalSpend, budget: dailyBudget)
        }

        // Usage history tracking (daily chart)
        usageHistoryTracker.record(
            fiveHour: newFiveHourUtil,
            sevenDay: newSevenDayUtil,
            cost: totalSpend
        )
        let newHistory = usageHistoryTracker.getHistory()
        if dailyHistory != newHistory { dailyHistory = newHistory }

        // Live session timer — derive start time from session duration
        if newSession.modelName != nil && sessionStartTime == nil {
            if let durationMs = newSession.sessionDurationMs, durationMs > 0 {
                sessionStartTime = Date().addingTimeInterval(-Double(durationMs) / 1000.0)
            } else {
                sessionStartTime = Date()
            }
            startSessionTimer()
        }

        if fhChanged || sdChanged {
            NotificationManager.shared.checkAndNotify(
                fiveHourUtil: newFiveHourUtil,
                sevenDayUtil: newSevenDayUtil
            )
        }

        // Check for updates on first refresh only
        if !hasCheckedForUpdate {
            hasCheckedForUpdate = true
            Task {
                if let result = await updateChecker.check(), result.available {
                    self.updateAvailable = result.latestVersion
                }
            }
        }

        // Write widget data for App Group sharing + iCloud sync
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let widgetData = WidgetData(
            fiveHourUtil: fiveHourUtil,
            sevenDayUtil: sevenDayUtil,
            dailyCost: dailyClaudeCost + dailyCodexCost,
            paceTier: paceTier.rawValue,
            fiveHourReset: fiveHourReset.flatMap { isoFormatter.date(from: $0) },
            sevenDayReset: sevenDayReset.flatMap { isoFormatter.date(from: $0) },
            usageHistory: usageHistory,
            promoActive: promoActive
        )
        SharedDefaults.write(widgetData)
        // Sync to iCloud for iPhone companion
        CloudSyncManager.write(widgetData)

        if isLoading { isLoading = false }
    }
}
