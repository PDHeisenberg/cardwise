// NotificationService.swift
// CardWise
//
// Handles push notifications for wrong-card alerts, new card detection, and weekly digests

import Foundation
import UserNotifications

/// Service that manages all notification delivery for CardWise
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    // MARK: - Setup

    /// Request notification permission from the user
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                print("✅ Notification permission granted")
            }
            return granted
        } catch {
            print("❌ Notification permission error: \(error)")
            return false
        }
    }

    // MARK: - Wrong Card Alert

    /// Send a notification when the user pays with a sub-optimal card
    func sendWrongCardAlert(
        merchantName: String,
        amount: Double,
        usedCardName: String,
        optimalCardName: String,
        rewardsDelta: Double,
        optimalRateDescription: String
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "💳 Better Card Available"
        content.body = "You paid \(formatCurrency(amount)) at \(merchantName) with \(usedCardName). " +
            "\(optimalCardName) would've earned \(optimalRateDescription) " +
            "(saved ~\(formatCurrency(rewardsDelta)))"
        content.sound = .default
        content.categoryIdentifier = "WRONG_CARD"
        content.userInfo = [
            "merchant": merchantName,
            "amount": amount,
            "usedCard": usedCardName,
            "optimalCard": optimalCardName,
            "delta": rewardsDelta
        ]

        let request = UNNotificationRequest(
            identifier: "wrong-card-\(UUID().uuidString)",
            content: content,
            trigger: nil // Deliver immediately
        )

        do {
            try await center.add(request)
        } catch {
            print("❌ Failed to send wrong card alert: \(error)")
        }
    }

    // MARK: - New Card Detected

    /// Send a notification when a new card is auto-detected
    func sendNewCardDetected(cardName: String) async {
        let content = UNMutableNotificationContent()
        content.title = "🆕 New Card Detected"
        content.body = "Found a new card: \(cardName)! We'll optimize recommendations for it."
        content.sound = .default
        content.categoryIdentifier = "NEW_CARD"

        let request = UNNotificationRequest(
            identifier: "new-card-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
        } catch {
            print("❌ Failed to send new card notification: \(error)")
        }
    }

    // MARK: - Weekly Digest

    /// Schedule a weekly rewards digest notification
    func scheduleWeeklyDigest(
        transactionCount: Int,
        missedRewards: Double
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "📊 Weekly Rewards Digest"
        content.body = "This week: \(transactionCount) transactions, " +
            "\(formatCurrency(missedRewards)) in missed rewards. See details."
        content.sound = .default
        content.categoryIdentifier = "WEEKLY_DIGEST"

        // Schedule for next Monday at 9 AM
        var dateComponents = DateComponents()
        dateComponents.weekday = 2 // Monday
        dateComponents.hour = 9
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "weekly-digest",
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            print("✅ Weekly digest scheduled")
        } catch {
            print("❌ Failed to schedule weekly digest: \(error)")
        }
    }

    // MARK: - Monthly Report

    /// Send a monthly report notification
    func sendMonthlyReport(
        month: String,
        missedRewards: Double,
        topCard: String
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "📈 \(month) Report"
        content.body = "\(month) report: \(formatCurrency(missedRewards)) left on the table. " +
            "Your most-used optimal card: \(topCard)."
        content.sound = .default
        content.categoryIdentifier = "MONTHLY_REPORT"

        let request = UNNotificationRequest(
            identifier: "monthly-report-\(month)",
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
        } catch {
            print("❌ Failed to send monthly report: \(error)")
        }
    }

    // MARK: - Cap Warning

    /// Send a notification when approaching a reward cap
    func sendCapWarning(
        cardName: String,
        category: String,
        currentSpend: Double,
        cap: Double
    ) async {
        let remaining = cap - currentSpend
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Reward Cap Warning"
        content.body = "You've hit \(formatCurrency(currentSpend))/\(formatCurrency(cap)) on \(cardName) \(category) this month. " +
            "\(formatCurrency(remaining)) remaining."
        content.sound = .default
        content.categoryIdentifier = "CAP_WARNING"

        let request = UNNotificationRequest(
            identifier: "cap-warning-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
        } catch {
            print("❌ Failed to send cap warning: \(error)")
        }
    }

    // MARK: - Register Categories

    /// Register notification action categories
    func registerCategories() {
        let viewAction = UNNotificationAction(
            identifier: "VIEW_DETAILS",
            title: "View Details",
            options: .foreground
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: .destructive
        )

        let wrongCardCategory = UNNotificationCategory(
            identifier: "WRONG_CARD",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        let newCardCategory = UNNotificationCategory(
            identifier: "NEW_CARD",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )

        let weeklyCategory = UNNotificationCategory(
            identifier: "WEEKLY_DIGEST",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([wrongCardCategory, newCardCategory, weeklyCategory])
    }

    // MARK: - Helpers

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "SGD"
        return formatter.string(from: NSNumber(value: value)) ?? "$\(String(format: "%.2f", value))"
    }
}
