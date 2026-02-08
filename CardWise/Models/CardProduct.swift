// CardProduct.swift
// CardWise
//
// Codable model for the bundled card rewards database

import Foundation

/// Represents a credit card product from the rewards database (sg_cards.json)
struct CardProduct: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let issuer: String
    let fullName: String
    let country: String
    let network: CardNetwork
    let annualFee: Double
    let annualFeeWaived: Bool
    let minIncome: Double
    let rewardTiers: [RewardTier]
    let aliases: [String]

    var displayName: String {
        "\(issuer) \(name)"
    }

    /// Get the best reward rate for a given category
    func bestRate(for category: MerchantCategory) -> RewardTier? {
        rewardTiers
            .filter { $0.categories.contains(category) }
            .max(by: { $0.effectiveCashbackRate < $1.effectiveCashbackRate })
    }

    /// Get the general/fallback rate
    var generalRate: RewardTier? {
        rewardTiers.first(where: { $0.categories.contains(.general) })
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CardProduct, rhs: CardProduct) -> Bool {
        lhs.id == rhs.id
    }
}

/// Reward tier for a specific set of categories
struct RewardTier: Codable, Identifiable, Hashable {
    let id: String
    let categories: [MerchantCategory]
    let rate: Double
    let rateType: RateType
    let monthlyCap: Double?
    let minSpend: Double?
    let conditions: String?

    /// Converts any rate type to an equivalent cashback percentage for comparison
    var effectiveCashbackRate: Double {
        switch rateType {
        case .cashback:
            return rate
        case .points:
            // Typical Singapore points: 1 point ≈ $0.004 value, so 10x = ~2.5% cashback
            return rate * 0.25
        case .miles:
            // Typical miles value: 1 mile ≈ $0.018, so 1.2 mpd ≈ 2.16%
            return rate * 1.8
        }
    }

    /// Human-readable rate description
    var rateDescription: String {
        switch rateType {
        case .cashback:
            return "\(formatRate(rate))% cashback"
        case .points:
            return "\(formatRate(rate))x points"
        case .miles:
            return "\(formatRate(rate)) mpd"
        }
    }

    private func formatRate(_ value: Double) -> String {
        if value == value.rounded() {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

enum CardNetwork: String, Codable {
    case visa
    case mastercard
    case amex
    case unionpay
}

enum RateType: String, Codable {
    case cashback
    case points
    case miles
}

// MARK: - Card Database Loader

final class CardDatabase {
    static let shared = CardDatabase()

    private(set) var products: [CardProduct] = []

    private init() {
        loadDatabase()
    }

    func loadDatabase() {
        guard let url = Bundle.main.url(forResource: "sg_cards", withExtension: "json") else {
            print("⚠️ sg_cards.json not found in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let wrapper = try decoder.decode(CardDatabaseWrapper.self, from: data)
            self.products = wrapper.cards
            print("✅ Loaded \(products.count) card products")
        } catch {
            print("❌ Failed to load card database: \(error)")
        }
    }

    func product(byId id: String) -> CardProduct? {
        products.first(where: { $0.id == id })
    }

    func products(byIssuer issuer: String) -> [CardProduct] {
        products.filter { $0.issuer.lowercased() == issuer.lowercased() }
    }

    func bestCard(for category: MerchantCategory, from cardIds: [String]) -> (CardProduct, RewardTier)? {
        let available = products.filter { cardIds.contains($0.id) }
        var bestProduct: CardProduct?
        var bestTier: RewardTier?

        for product in available {
            if let tier = product.bestRate(for: category) {
                if bestTier == nil || tier.effectiveCashbackRate > bestTier!.effectiveCashbackRate {
                    bestProduct = product
                    bestTier = tier
                }
            }
        }

        if let product = bestProduct, let tier = bestTier {
            return (product, tier)
        }
        return nil
    }
}

struct CardDatabaseWrapper: Codable {
    let version: String
    let lastUpdated: String
    let country: String
    let cards: [CardProduct]
}
