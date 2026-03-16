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

    // Pacing
    @Published public var paceTier: PaceTier = .comfortable

    // Session
    @Published public var session: SessionData = SessionData()

    // Agents
    @Published public var activeSessions: [AgentSession] = []

    // State
    @Published public var isLoading: Bool = true

    private let usageService = UsageService()
    private let promoService = PromoService()
    private let agentWatcher = AgentWatcher()
    private let sessionReader = SessionReader()
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

        let usage = await usageTask
        let promo = await promoTask
        let sessions = await sessionsTask
        let newSession = await sessionTask

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
