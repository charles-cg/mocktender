import Foundation
import UIKit
import UserNotifications

/// Schedules a single repeating daily local notification that reminds the
/// user to refill any bottle whose `remaining` has fallen to ~15% of
/// `capacity` or below. The same request id is reused so updating the set
/// of low bottles just replaces the pending content — when nothing is low,
/// the pending request is removed entirely.
@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // Foreground crossings already surface as an in-app banner (see
    // `refresh(bottles:)`), so suppress the system presentation entirely
    // when the app is active to avoid double-notifying the user.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([])
    }

    private let requestId = "low_bottle_refill_daily"
    /// Bottles at or below this fraction of capacity trigger the reminder.
    private let threshold = 0.15
    /// Local time of day for the daily reminder.
    private let fireHour = 10
    private let fireMinute = 0

    private var authorized = false
    /// Pump ids that were already ≤ threshold on the previous `refresh` call.
    /// Used to edge-trigger the immediate "just hit 15%" notification so it
    /// fires once on the crossing instead of on every BLE packet while low.
    private var previouslyLow: Set<String> = []

    func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
                Task { @MainActor in
                    self?.authorized = granted
                }
            }
    }

    /// Recompute which bottles are low and update the pending daily
    /// notification. Safe to call on every BLE packet — it cancels and
    /// re-schedules a single request so duplicates can't accumulate.
    func refresh(bottles: [Bottle]) {
        let low = bottles.filter { $0.capacity > 0 && $0.remaining / $0.capacity <= threshold }
        let center = UNUserNotificationCenter.current()
        let lowIds = Set(low.map { $0.id })

        // Edge-trigger: fire an immediate one-shot for any bottle that just
        // crossed the threshold this refresh. Update `previouslyLow` after so
        // a bottle that's refilled past 15% and later drains again re-fires.
        let newlyLow = lowIds.subtracting(previouslyLow)
        let isForeground = UIApplication.shared.applicationState == .active
        for id in newlyLow {
            guard let pump = Catalog.pump(id) else { continue }
            if isForeground {
                // In-app banner — RootView renders this over the active screen.
                BluetoothManager.shared.surfaceLowBottleBanner(
                    LowBottleBannerData(pumpName: pump.name, pumpShort: pump.short)
                )
            } else {
                let content = UNMutableNotificationContent()
                content.title = "\(pump.name) is low"
                content.body = "Only about 15% left — refill the bottle when you get a chance."
                content.sound = .default
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let req = UNNotificationRequest(
                    identifier: "low_bottle_immediate_\(id)_\(UUID().uuidString)",
                    content: content,
                    trigger: trigger
                )
                center.add(req, withCompletionHandler: nil)
            }
        }
        previouslyLow = lowIds

        guard !low.isEmpty else {
            center.removePendingNotificationRequests(withIdentifiers: [requestId])
            return
        }

        let names = low.compactMap { Catalog.pump($0.id)?.name }
        let body: String
        switch names.count {
        case 1: body = "\(names[0]) is running low. Time to refill the bottle."
        case 2: body = "\(names[0]) and \(names[1]) are running low. Time to refill."
        default:
            let head = names.dropLast().joined(separator: ", ")
            body = "\(head), and \(names.last!) are running low. Time to refill."
        }

        let content = UNMutableNotificationContent()
        content.title = "Mocktender refill reminder"
        content.body = body
        content.sound = .default

        var when = DateComponents()
        when.hour = fireHour
        when.minute = fireMinute
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)

        let request = UNNotificationRequest(identifier: requestId, content: content, trigger: trigger)
        // Replacing a pending request with the same identifier updates the
        // content/trigger in place — no need to remove first.
        center.add(request, withCompletionHandler: nil)
    }
}
