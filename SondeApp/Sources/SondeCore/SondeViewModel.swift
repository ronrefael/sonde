import Combine
import Foundation

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

    // Pacing
    @Published public var paceTier: PaceTier = .comfortable

    // Session
    @Published public var session: SessionData = SessionData()

    // Codex
    @Published public var codexCost: Double?

    // Extra usage details
    @Published public var extraUsageEnabled: Bool = false
    @Published public var extraUsageMonthlyLimit: Double?
    @Published public var extraUsageUsedCredits: Double?

    // Agents
    @Published public var activeSessions: [AgentSession] = []

    // State
    @Published public var isLoading: Bool = true

    private let usageService = UsageService()
    private let promoService = PromoService()
    private let agentWatcher = AgentWatcher()
    private let sessionReader = SessionReader()
    private let codexCostReader = CodexCostReader()
    private var pollTimer: Timer?

    public init() {
        NotificationManager.shared.requestPermission()
    }

    deinit {
        pollTimer?.invalidate()
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
    }

    public func refresh() async {
        async let usageTask = usageService.fetchUsage()
        async let promoTask = promoService.fetchPromo()
        async let sessionsTask = agentWatcher.getActiveSessions()
        async let sessionTask = sessionReader.getSessionData()
        async let codexTask = codexCostReader.getSessionCost()

        let usage = await usageTask
        let promo = await promoTask
        let sessions = await sessionsTask
        let newSession = await sessionTask
        let newCodexCost = await codexTask

        // Usage
        let newFiveHourUtil = usage?.fiveHour?.utilization
        let newFiveHourReset = usage?.fiveHour?.resetsAt
        let newSevenDayUtil = usage?.sevenDay?.utilization
        let newSevenDayReset = usage?.sevenDay?.resetsAt
        let newExtraUsageUtil = usage?.extraUsage?.utilization
        let newPromoActive = promo?.isOffpeak ?? false
        let newPromoEmoji = promo?.emoji ?? ""
        let newPromoLabel = promo?.label ?? ""

        if fiveHourUtil != newFiveHourUtil { fiveHourUtil = newFiveHourUtil }
        if fiveHourReset != newFiveHourReset { fiveHourReset = newFiveHourReset }
        if sevenDayUtil != newSevenDayUtil { sevenDayUtil = newSevenDayUtil }
        if sevenDayReset != newSevenDayReset { sevenDayReset = newSevenDayReset }
        if extraUsageUtil != newExtraUsageUtil { extraUsageUtil = newExtraUsageUtil }
        if promoActive != newPromoActive { promoActive = newPromoActive }
        if promoEmoji != newPromoEmoji { promoEmoji = newPromoEmoji }
        if promoLabel != newPromoLabel { promoLabel = newPromoLabel }

        // Promo countdown
        let transition = PromoSchedule.nextTransition()
        if promoCountdownLabel != transition.label { promoCountdownLabel = transition.label }
        if promoCountdown != transition.timeRemaining { promoCountdown = transition.timeRemaining }

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
        }

        if session != newSession { session = newSession }
        if activeSessions != sessions { activeSessions = sessions }

        if fiveHourUtil != newFiveHourUtil || sevenDayUtil != newSevenDayUtil {
            NotificationManager.shared.checkAndNotify(
                fiveHourUtil: newFiveHourUtil,
                sevenDayUtil: newSevenDayUtil
            )
        }

        if isLoading { isLoading = false }
    }
}
