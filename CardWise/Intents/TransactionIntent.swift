// TransactionIntent.swift
// CardWise
//
// App Intent for iOS Shortcuts Transaction Trigger integration.
// Receives transaction data automatically when Apple Pay is used.

import AppIntents
import SwiftData

/// App Intent that receives transaction data from the iOS Shortcuts Transaction Trigger.
/// This is the primary integration point — the Shortcut fires after each Apple Pay transaction.
struct LogTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Transaction"
    static var description = IntentDescription(
        "Logs an Apple Pay transaction for card optimization analysis.",
        categoryName: "Transactions"
    )

    @Parameter(title: "Merchant Name", description: "Name of the merchant")
    var merchantName: String

    @Parameter(title: "Amount", description: "Transaction amount in dollars")
    var amount: Double

    @Parameter(title: "Card Name", description: "Name of the card/pass used (from Apple Pay)")
    var cardName: String

    @Parameter(title: "Currency", description: "Currency code (default: SGD)", default: "SGD")
    var currency: String

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) at \(\.$merchantName) with \(\.$cardName)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let container = try ModelContainer(for: Transaction.self, Card.self)
        let context = container.mainContext

        let ingestionService = TransactionIngestionService()
        let transaction = await ingestionService.ingestTransaction(
            merchantName: merchantName,
            amount: amount,
            cardName: cardName,
            currency: currency,
            context: context
        )

        let resultMessage: String
        if transaction.isOptimal {
            resultMessage = "✅ Great choice! \(cardName) is optimal for \(transaction.category.displayName)."
        } else if let optimalName = transaction.optimalCardName {
            resultMessage = "💡 \(optimalName) would've been better for \(transaction.category.displayName) (saved \(transaction.formattedDelta))."
        } else {
            resultMessage = "📝 Transaction logged: \(transaction.formattedAmount) at \(merchantName)."
        }

        return .result(value: resultMessage)
    }
}

/// Shortcut for querying the best card for a merchant
struct BestCardForMerchantIntent: AppIntent {
    static var title: LocalizedStringResource = "Best Card for Merchant"
    static var description = IntentDescription(
        "Tells you which card to use at a specific merchant.",
        categoryName: "Recommendations"
    )

    @Parameter(title: "Merchant Name", description: "Name of the merchant you're about to pay at")
    var merchantName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Best card for \(\.$merchantName)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let container = try ModelContainer(for: Transaction.self, Card.self)
        let context = container.mainContext

        // Get user's card portfolio
        let descriptor = FetchDescriptor<Card>(
            predicate: #Predicate { $0.isActive == true && $0.matchedProductId != nil }
        )
        let cards = (try? context.fetch(descriptor)) ?? []
        let productIds = cards.compactMap(\.matchedProductId)

        guard !productIds.isEmpty else {
            return .result(value: "No cards detected yet. Use Apple Pay a few times and I'll learn your cards!")
        }

        let categoryService = MerchantCategoryService.shared
        let category = categoryService.categorize(merchantName)

        let engine = RewardOptimizationEngine()
        let result = engine.findOptimalCard(
            for: category,
            amount: 100,
            userCardProductIds: productIds,
            usedCardProductId: nil
        )

        if let card = result.optimalCard, let tier = result.optimalTier {
            return .result(value: "💳 Use \(card.displayName) at \(merchantName) (\(category.displayName)) — earn \(tier.rateDescription)")
        } else {
            return .result(value: "Any card works for \(merchantName). Category: \(category.displayName)")
        }
    }
}

/// Provider for the Shortcuts app to discover these intents
struct CardWiseShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogTransactionIntent(),
            phrases: [
                "Log a transaction in \(.applicationName)",
                "Record payment in \(.applicationName)",
                "\(.applicationName) log purchase"
            ],
            shortTitle: "Log Transaction",
            systemImageName: "creditcard.fill"
        )

        AppShortcut(
            intent: BestCardForMerchantIntent(),
            phrases: [
                "Best card for \(\.$merchantName) in \(.applicationName)",
                "Which card at \(\.$merchantName) \(.applicationName)",
                "\(.applicationName) recommend card for \(\.$merchantName)"
            ],
            shortTitle: "Best Card",
            systemImageName: "star.fill"
        )
    }
}
