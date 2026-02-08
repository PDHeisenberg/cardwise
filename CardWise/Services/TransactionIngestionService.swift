// TransactionIngestionService.swift
// CardWise
//
// Receives transaction data from Shortcuts and processes it through the pipeline

import Foundation
import SwiftData

/// Service that handles the full pipeline of ingesting a new transaction:
/// 1. Parse raw transaction data
/// 2. Categorize the merchant
/// 3. Detect the card used
/// 4. Determine optimal card
/// 5. Calculate rewards delta
/// 6. Store in SwiftData
@Observable
final class TransactionIngestionService {
    private let categoryService = MerchantCategoryService.shared
    private let cardDetection = CardDetectionService()
    private let optimizationEngine = RewardOptimizationEngine()
    private let notificationService = NotificationService.shared

    // MARK: - Public API

    /// Ingest a transaction from the Shortcuts Transaction Trigger
    @MainActor
    func ingestTransaction(
        merchantName: String,
        amount: Double,
        cardName: String,
        date: Date = Date(),
        currency: String = "SGD",
        context: ModelContext
    ) async -> Transaction {
        // Step 1: Categorize the merchant
        let category = categoryService.categorize(merchantName)

        // Step 2: Detect/update card in portfolio
        let card = cardDetection.detectAndSaveCard(rawName: cardName, context: context)

        // Step 3: Get all user's cards for optimization
        let allCardsDescriptor = FetchDescriptor<Card>(
            predicate: #Predicate { $0.isActive == true }
        )
        let allCards = (try? context.fetch(allCardsDescriptor)) ?? []
        let matchedProductIds = allCards.compactMap(\.matchedProductId)

        // Step 4: Determine optimal card
        let optimization = optimizationEngine.findOptimalCard(
            for: category,
            amount: amount,
            userCardProductIds: matchedProductIds,
            usedCardProductId: card.matchedProductId
        )

        // Step 5: Create and save transaction
        let transaction = Transaction(
            merchantName: merchantName,
            amount: amount,
            currency: currency,
            cardName: cardName,
            cardId: card.id,
            category: category,
            optimalCardId: optimization.optimalCard != nil ?
                allCards.first(where: { $0.matchedProductId == optimization.optimalCard?.id })?.id : nil,
            rewardsDelta: optimization.rewardsDelta,
            actualRewards: optimization.actualRewards,
            optimalRewards: optimization.optimalRewards,
            optimalCardName: optimization.optimalCard?.displayName,
            timestamp: date,
            isOptimal: optimization.isOptimal
        )

        context.insert(transaction)

        // Step 6: Send notification if wrong card used
        if !optimization.isOptimal, let optimalCard = optimization.optimalCard {
            await notificationService.sendWrongCardAlert(
                merchantName: merchantName,
                amount: amount,
                usedCardName: card.displayName,
                optimalCardName: optimalCard.displayName,
                rewardsDelta: optimization.rewardsDelta,
                optimalRateDescription: optimization.optimalTier?.rateDescription ?? ""
            )
        }

        // Detect if this is a new card
        if card.transactionCount == 1 {
            await notificationService.sendNewCardDetected(cardName: card.displayName)
        }

        try? context.save()
        return transaction
    }

    /// Quick preview of what the optimal card would be (no saving)
    func previewOptimalCard(
        merchantName: String,
        userCardProductIds: [String]
    ) -> CardProduct? {
        let category = categoryService.categorize(merchantName)
        let result = optimizationEngine.findOptimalCard(
            for: category,
            amount: 0,
            userCardProductIds: userCardProductIds,
            usedCardProductId: nil
        )
        return result.optimalCard
    }
}
