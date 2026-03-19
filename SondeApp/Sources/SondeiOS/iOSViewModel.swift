import SwiftUI
import Combine
import SondeCore

@MainActor
final class iOSViewModel: ObservableObject {
    @Published var fiveHourUtil: Double?
    @Published var sevenDayUtil: Double?
    @Published var dailyCost: Double = 0
    @Published var paceTier: String = "Comfortable"
    @Published var fiveHourReset: Date?
    @Published var sevenDayReset: Date?
    @Published var usageHistory: [Double] = []
    @Published var promoActive: Bool = false
    @Published var lastUpdated: Date?
    @Published var isConnected: Bool = false

    private var observer: NSObjectProtocol?

    init() {
        loadFromCloud()
        // Listen for iCloud KVS changes pushed from Mac
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.loadFromCloud()
            }
        }
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func loadFromCloud() {
        guard let decoded = CloudSyncManager.read() else {
            isConnected = false
            return
        }

        isConnected = true
        fiveHourUtil = decoded.fiveHourUtil
        sevenDayUtil = decoded.sevenDayUtil
        dailyCost = decoded.dailyCost
        paceTier = decoded.paceTier
        fiveHourReset = decoded.fiveHourReset
        sevenDayReset = decoded.sevenDayReset
        usageHistory = decoded.usageHistory
        promoActive = decoded.promoActive
        lastUpdated = decoded.lastUpdated
    }
}
