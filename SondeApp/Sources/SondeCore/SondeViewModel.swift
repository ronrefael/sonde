import Foundation
import Combine

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

    public func startPolling(interval: TimeInterval = 60) {
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

        // Usage
        fiveHourUtil = usage?.fiveHour?.utilization
        fiveHourReset = usage?.fiveHour?.resetsAt
        sevenDayUtil = usage?.sevenDay?.utilization
        sevenDayReset = usage?.sevenDay?.resetsAt
        extraUsageUtil = usage?.extraUsage?.utilization

        // Promo
        promoActive = promo?.isOffpeak ?? false
        promoEmoji = promo?.emoji ?? ""
        promoLabel = promo?.label ?? ""

        // Pacing
        if let util = fiveHourUtil {
            paceTier = PaceTier.calculate(utilization: util, promoActive: promoActive)
        }

        isLoading = false
    }
}
