// TransactionIntent.swift
// CardWise
//
// App Intent for iOS Shortcuts Transaction Trigger integration.
// Receives transaction data automatically when Apple Pay is used.

import AppIntents
import SwiftData

// MARK: - Merchant Name Entity for AppIntent parameter support

/// A simple transient entity representing a merchant name string.
/// Required because AppIntent @Parameter in AppShortcut phrases
/// only supports AppEntity/AppEnum types, not raw String.
struct MerchantNameEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Merchant")
    static var defaultQuery = MerchantNameQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    init(name: String) {
        self.id = name
        self.name = name
    }
}

struct MerchantNameQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [MerchantNameEntity] {
        identifiers.map { MerchantNameEntity(id: $0, name: $0) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<MerchantNameEntity> {
        // Return the typed string as a merchant entity
        let entity = MerchantNameEntity(name: string)
        return IntentItemCollection(items: [entity])
    }

    func suggestedEntities() async throws -> IntentItemCollection<MerchantNameEntity> {
        // Could return recent merchants here in the future
        IntentItemCollection(items: [])
    }
}

// MARK: - Log Transaction Intent

/// App Intent that receives transaction data from the iOS Shortcuts Transaction Trigger.
/// This is the primary integration point — the Shortcut fires after each Apple Pay transaction.
///
/// NOTE: This intent is designed to be called from a Shortcuts Automation
/// (Transaction Trigger), not via Siri phrases. The parameters are plain
/// String/Double which work fine when wired up manually in Shortcuts.
struct LogTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Transaction"
    static var description = IntentDescription(
        "Logs a payment transaction for card optimization analysis.",
        categoryName: "Transactions"
    )

    @Parameter(title: "Merchant Name", description: "Name of the merchant")
    var merchantName: String

    @Parameter(title: "Amount", description: "Transaction amount in dollars")
    var amount: Double

    @Parameter(title: "Card Name", description: "Name of the card/pass used for payment")
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

// MARK: - Best Card Intent (Siri-enabled)

/// Shortcut for querying the best card for a merchant.
/// Uses MerchantNameEntity so it can be used in AppShortcut phrases with Siri.
struct BestCardForMerchantIntent: AppIntent {
    static var title: LocalizedStringResource = "Best Card for Merchant"
    static var description = IntentDescription(
        "Tells you which card to use at a specific merchant.",
        categoryName: "Recommendations"
    )

    @Parameter(title: "Merchant Name", description: "Name of the merchant you're about to pay at")
    var merchant: MerchantNameEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Best card for \(\.$merchant)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let merchantName = merchant.name

        let container = try ModelContainer(for: Transaction.self, Card.self)
        let context = container.mainContext

        // Get user's card portfolio
        let descriptor = FetchDescriptor<Card>(
            predicate: #Predicate { $0.isActive == true && $0.matchedProductId != nil }
        )
        let cards = (try? context.fetch(descriptor)) ?? []
        let productIds = cards.compactMap(\.matchedProductId)

        guard !productIds.isEmpty else {
            return .result(value: "No cards detected yet. Make a few payments and I'll learn your cards!")
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

// MARK: - App Shortcuts Provider

/// Provider for the Shortcuts app to discover these intents.
/// Only BestCardForMerchantIntent is exposed via Siri phrases (uses AppEntity param).
/// LogTransactionIntent is used via manual Shortcuts Automation setup (Transaction Trigger).
struct CardWiseShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: BestCardForMerchantIntent(),
            phrases: [
                "Best card for \(\.$merchant) in \(.applicationName)",
                "Which card at \(\.$merchant) \(.applicationName)",
                "\(.applicationName) for \(\.$merchant)"
            ],
            shortTitle: "Best Card",
            systemImageName: "star.fill"
        )
    }
}
