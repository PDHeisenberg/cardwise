// RewardOptimizationEngine.swift
// CardWise
//
// Determines the optimal card for any spending category and calculates rewards deltas

import Foundation

/// Engine that computes optimal card recommendations and reward calculations
final class RewardOptimizationEngine {
    private let database = CardDatabase.shared

    /// Result of an optimization calculation
    struct OptimizationResult {
        let optimalCard: CardProduct?
        let optimalTier: RewardTier?
        let usedCard: CardProduct?
        let usedTier: RewardTier?
        let actualRewards: Double
        let optimalRewards: Double
        let rewardsDelta: Double
        let isOptimal: Bool
        let allRankings: [(CardProduct, RewardTier, Double)] // card, tier, reward amount
    }

    // MARK: - Public API

    /// Find the optimal card for a given category from the user's portfolio
    func findOptimalCard(
        for category: MerchantCategory,
        amount: Double,
        userCardProductIds: [String],
        usedCardProductId: String?
    ) -> OptimizationResult {
        let userProducts = userCardProductIds.compactMap { database.product(byId: $0) }

        guard !userProducts.isEmpty else {
            return OptimizationResult(
                optimalCard: nil, optimalTier: nil,
                usedCard: nil, usedTier: nil,
                actualRewards: 0, optimalRewards: 0,
                rewardsDelta: 0, isOptimal: true,
                allRankings: []
            )
        }

        // Rank all cards for this category
        var rankings: [(CardProduct, RewardTier, Double)] = []

        for product in userProducts {
            if let tier = product.bestRate(for: category) {
                let reward = calculateReward(amount: amount, tier: tier)
                rankings.append((product, tier, reward))
            } else if let generalTier = product.generalRate {
                let reward = calculateReward(amount: amount, tier: generalTier)
                rankings.append((product, generalTier, reward))
            }
        }

        // Sort by reward value (highest first)
        rankings.sort { $0.2 > $1.2 }

        // Best card
        let best = rankings.first
        let optimalRewards = best?.2 ?? 0

        // What the user actually used
        let usedProduct = usedCardProductId.flatMap { database.product(byId: $0) }
        let usedTier = usedProduct.flatMap { $0.bestRate(for: category) ?? $0.generalRate }
        let actualRewards = usedTier.map { calculateReward(amount: amount, tier: $0) } ?? 0

        let delta = optimalRewards - actualRewards
        let isOptimal = usedCardProductId == best?.0.id || delta < 0.01

        return OptimizationResult(
            optimalCard: best?.0,
            optimalTier: best?.1,
            usedCard: usedProduct,
            usedTier: usedTier,
            actualRewards: actualRewards,
            optimalRewards: optimalRewards,
            rewardsDelta: max(0, delta),
            isOptimal: isOptimal,
            allRankings: rankings
        )
    }

    /// Calculate all category recommendations for a user's card portfolio
    func generateAllRecommendations(
        userCardProductIds: [String]
    ) -> [MerchantCategory: (CardProduct, RewardTier)] {
        var recommendations: [MerchantCategory: (CardProduct, RewardTier)] = [:]

        for category in MerchantCategory.allCases where category != .general && category != .contactless {
            let result = findOptimalCard(
                for: category,
                amount: 100, // Reference amount for comparison
                userCardProductIds: userCardProductIds,
                usedCardProductId: nil
            )
            if let card = result.optimalCard, let tier = result.optimalTier {
                recommendations[category] = (card, tier)
            }
        }

        return recommendations
    }

    /// Calculate total missed rewards over a period
    func calculateTotalMissedRewards(transactions: [Transaction]) -> RewardsSummary {
        let totalDelta = transactions.reduce(0.0) { $0 + $1.rewardsDelta }
        let totalActual = transactions.reduce(0.0) { $0 + $1.actualRewards }
        let totalOptimal = transactions.reduce(0.0) { $0 + $1.optimalRewards }
        let totalSpend = transactions.reduce(0.0) { $0 + $1.amount }
        let wrongCardCount = transactions.filter { !$0.isOptimal }.count
        let totalCount = transactions.count

        // Category breakdown
        var categoryBreakdown: [MerchantCategory: CategorySummary] = [:]
        for txn in transactions {
            let cat = txn.category
            var summary = categoryBreakdown[cat] ?? CategorySummary(
                category: cat, totalSpend: 0, missedRewards: 0, transactionCount: 0
            )
            summary.totalSpend += txn.amount
            summary.missedRewards += txn.rewardsDelta
            summary.transactionCount += 1
            categoryBreakdown[cat] = summary
        }

        return RewardsSummary(
            totalSpend: totalSpend,
            totalActualRewards: totalActual,
            totalOptimalRewards: totalOptimal,
            totalMissedRewards: totalDelta,
            transactionCount: totalCount,
            wrongCardCount: wrongCardCount,
            categoryBreakdown: categoryBreakdown
        )
    }

    // MARK: - Private Helpers

    private func calculateReward(amount: Double, tier: RewardTier) -> Double {
        switch tier.rateType {
        case .cashback:
            return amount * (tier.rate / 100.0)
        case .points:
            // Convert points to dollar value: typical 10x points ≈ 2.5% cashback
            return amount * (tier.rate * 0.25 / 100.0)
        case .miles:
            // Convert miles to dollar value: 1 mile ≈ $0.018
            return amount * tier.rate * 0.018
        }
    }
}

// MARK: - Summary Models

struct RewardsSummary {
    let totalSpend: Double
    let totalActualRewards: Double
    let totalOptimalRewards: Double
    let totalMissedRewards: Double
    let transactionCount: Int
    let wrongCardCount: Int
    let categoryBreakdown: [MerchantCategory: CategorySummary]

    var optimizationRate: Double {
        guard transactionCount > 0 else { return 1.0 }
        return Double(transactionCount - wrongCardCount) / Double(transactionCount)
    }

    var formattedMissedRewards: String {
        String(format: "$%.2f", totalMissedRewards)
    }
}

struct CategorySummary {
    let category: MerchantCategory
    var totalSpend: Double
    var missedRewards: Double
    var transactionCount: Int
}
