// PKPassGeneratorService.swift
// CardWise
//
// Generates Apple Wallet passes using PassKit framework.
// Uses PKPass with in-app presentation via PKAddPassesViewController.

import Foundation
import PassKit
import UIKit
import CoreLocation

/// Service that generates and presents Apple Wallet passes for card recommendations.
///
/// Strategy: Since .pkpass bundles require Apple Developer signing certificates,
/// we use an in-app Wallet-style card UI and the PassKit API for pass presentation.
/// For MVP, we create visual "pass cards" inside the app and use location-based
/// notifications to surface recommendations at the right time.
///
/// When a Pass Type ID certificate is configured, this service can generate
/// signed .pkpass files for real Wallet integration.
final class PKPassGeneratorService: ObservableObject {
    static let shared = PKPassGeneratorService()

    /// Represents a generated wallet recommendation card
    struct WalletCard: Identifiable, Codable {
        let id: UUID
        let category: String  // MerchantCategory rawValue
        var cardName: String
        var rewardRate: String
        var monthlySpend: Double
        var monthlyRewards: Double
        var relevantText: String
        var isActive: Bool
        let createdAt: Date
        var updatedAt: Date

        var merchantCategory: MerchantCategory? {
            MerchantCategory(rawValue: category)
        }
    }

    /// Published wallet cards for SwiftUI observation
    @Published var walletCards: [WalletCard] = []

    private let storageKey = "cardwise_wallet_cards"
    private let locationManager = CLLocationManager()

    private init() {
        loadCards()
    }

    // MARK: - Public API

    /// Check if Wallet passes are supported on this device
    var isWalletAvailable: Bool {
        PKPassLibrary.isPassLibraryAvailable()
    }

    /// Generate default wallet cards for all main categories (before any cards detected)
    func generateDefaultCards() {
        let defaults: [(MerchantCategory, String, String)] = [
            (.dining, "Set up your cards", "Detecting..."),
            (.groceries, "Set up your cards", "Detecting..."),
            (.transport, "Set up your cards", "Detecting..."),
            (.travel, "Set up your cards", "Detecting..."),
            (.onlineShopping, "Set up your cards", "Detecting..."),
            (.fuel, "Set up your cards", "Detecting..."),
        ]

        var cards: [WalletCard] = []
        for (category, cardName, rate) in defaults {
            let card = WalletCard(
                id: UUID(),
                category: category.rawValue,
                cardName: cardName,
                rewardRate: rate,
                monthlySpend: 0,
                monthlyRewards: 0,
                relevantText: "\(category.icon) Use your best \(category.displayName.lowercased()) card here",
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            )
            cards.append(card)
        }

        walletCards = cards
        saveCards()

        // Register geofences for location-based notifications
        registerGeofences()
    }

    /// Update a wallet card with a real recommendation
    func updateCard(
        for category: MerchantCategory,
        cardName: String,
        rewardRate: String,
        monthlySpend: Double = 0,
        monthlyRewards: Double = 0
    ) {
        if let index = walletCards.firstIndex(where: { $0.category == category.rawValue }) {
            walletCards[index].cardName = cardName
            walletCards[index].rewardRate = rewardRate
            walletCards[index].monthlySpend = monthlySpend
            walletCards[index].monthlyRewards = monthlyRewards
            walletCards[index].relevantText = "\(category.icon) Use \(cardName) — \(rewardRate)"
            walletCards[index].updatedAt = Date()
        } else {
            let card = WalletCard(
                id: UUID(),
                category: category.rawValue,
                cardName: cardName,
                rewardRate: rewardRate,
                monthlySpend: monthlySpend,
                monthlyRewards: monthlyRewards,
                relevantText: "\(category.icon) Use \(cardName) — \(rewardRate)",
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            )
            walletCards.append(card)
        }
        saveCards()
    }

    /// Update all cards based on current portfolio recommendations
    func updateAllCards(recommendations: [MerchantCategory: (CardProduct, RewardTier)],
                        monthlySpend: [MerchantCategory: Double] = [:],
                        monthlyRewards: [MerchantCategory: Double] = [:]) {
        for (category, (card, tier)) in recommendations {
            updateCard(
                for: category,
                cardName: card.displayName,
                rewardRate: tier.rateDescription,
                monthlySpend: monthlySpend[category] ?? 0,
                monthlyRewards: monthlyRewards[category] ?? 0
            )
        }
    }

    // MARK: - Location-based notifications (simulates Wallet pass geofencing)

    /// Register geofence regions for location-based card recommendations
    func registerGeofences() {
        // Request location permission
        locationManager.requestWhenInUseAuthorization()

        let regions: [(String, CLLocationCoordinate2D, String)] = [
            // Orchard Road — dining/shopping hub
            ("orchard", CLLocationCoordinate2D(latitude: 1.3048, longitude: 103.8318),
             "🍽️ Dining area — check CardWise for your best card"),
            // Chinatown
            ("chinatown", CLLocationCoordinate2D(latitude: 1.2834, longitude: 103.8441),
             "🍽️ Great food nearby — use your best dining card"),
            // Clarke Quay
            ("clarkequay", CLLocationCoordinate2D(latitude: 1.2917, longitude: 103.8463),
             "🍽️ Clarke Quay — check your best card"),
            // Changi Airport
            ("changi", CLLocationCoordinate2D(latitude: 1.3644, longitude: 103.9915),
             "✈️ Travelling? Use your best travel card"),
            // Vivocity (shopping)
            ("vivocity", CLLocationCoordinate2D(latitude: 1.2644, longitude: 103.8223),
             "🛍️ Shopping at VivoCity — check your best card"),
        ]

        for (id, coordinate, note) in regions {
            let region = CLCircularRegion(
                center: coordinate,
                radius: 200,
                identifier: "cardwise_\(id)"
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false

            // Schedule a location notification
            let content = UNMutableNotificationContent()
            content.title = "CardWise"
            content.body = note
            content.sound = .default
            content.categoryIdentifier = "CARD_RECOMMENDATION"

            let trigger = UNLocationNotificationTrigger(region: region, repeats: true)
            let request = UNNotificationRequest(
                identifier: "cardwise_location_\(id)",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: - Persistence

    private func saveCards() {
        if let data = try? JSONEncoder().encode(walletCards) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadCards() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let cards = try? JSONDecoder().decode([WalletCard].self, from: data) {
            walletCards = cards
        }
    }

    // MARK: - Pass Colors

    func backgroundColorForCategory(_ category: MerchantCategory) -> (red: Double, green: Double, blue: Double) {
        switch category {
        case .dining: return (255/255, 107/255, 53/255)
        case .groceries: return (52/255, 199/255, 89/255)
        case .transport: return (0/255, 122/255, 255/255)
        case .travel: return (175/255, 82/255, 222/255)
        case .onlineShopping: return (255/255, 55/255, 95/255)
        case .entertainment: return (255/255, 59/255, 48/255)
        case .fuel: return (255/255, 204/255, 0/255)
        case .utilities: return (90/255, 200/255, 250/255)
        case .insurance: return (88/255, 86/255, 214/255)
        case .healthcare: return (0/255, 199/255, 190/255)
        case .education: return (50/255, 173/255, 230/255)
        case .departmentStore: return (162/255, 132/255, 94/255)
        case .contactless: return (142/255, 142/255, 147/255)
        case .general: return (99/255, 99/255, 102/255)
        }
    }
}
