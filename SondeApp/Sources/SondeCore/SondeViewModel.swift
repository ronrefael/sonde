import Combine
import Foundation

/// Main view model that aggregates all data sources.
@MainActor
public final class SondeViewModel: ObservableObject {
    @Published public var fiveHourUtil: Double?
    @Published public var fiveHourReset: String?
    @Published public var sevenDayUtil: Double?
    @Published public var sevenDayReset: String?
    @Published public var extraUsageUtil: Double?
    @Published public var promoActive: Bool = false
    @Published public var promoEmoji: String = ""
    @Published public var promoLabel: String = ""
    @Published public var paceTier: PaceTier = .comfortable
    @Published public var isLoading: Bool = true

    private let usageService = UsageService()
    private let promoService = PromoService()
    private var pollTimer: Timer?

    public init() {}

    deinit {
        pollTimer?.invalidate()
    }

    public func startPolling(interval: TimeInterval = 60) {
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

        let usage = await usageTask
        let promo = await promoTask

        // Only update @Published properties when values actually change
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

        if isLoading { isLoading = false }
    }
}
