// HomeView.swift
// CardWise
//
// Single scrollable home screen — no tabs. Shows:
// - Current recommendation (mirrors Wallet pass)
// - Money left on the table
// - Recent transactions
// - Detected cards
// - Shortcut setup prompt

import SwiftUI
import SwiftData
import PassKit

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.timestamp, order: .reverse) private var transactions: [Transaction]
    @Query(filter: #Predicate<Card> { $0.isActive == true }) private var cards: [Card]
    @State private var showSettings = false

    private var recentTransactions: [Transaction] {
        Array(transactions.prefix(5))
    }

    private var thisMonthTransactions: [Transaction] {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        return transactions.filter { $0.timestamp >= startOfMonth }
    }

    private var totalMissedThisMonth: Double {
        thisMonthTransactions.reduce(0) { $0 + $1.rewardsDelta }
    }

    // Get current recommendation from the engine
    private var currentRecommendation: (category: MerchantCategory, cardName: String, earnRate: String)? {
        let matchedIds = cards.compactMap(\.matchedProductId)
        guard !matchedIds.isEmpty else { return nil }

        let engine = RewardOptimizationEngine()
        let recs = engine.generateAllRecommendations(userCardProductIds: matchedIds)

        // Pick the most relevant category (dining as default, or the one with most recent transaction)
        let recentCategory = recentTransactions.first?.category
        let category = recentCategory ?? .dining

        if let (card, tier) = recs[category] {
            return (category, card.displayName, tier.rateDescription)
        }

        // Fallback to first available
        if let (cat, (card, tier)) = recs.first {
            return (cat, card.displayName, tier.rateDescription)
        }

        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Current recommendation card
                    recommendationCard

                    // Money left on the table
                    missedRewardsLabel

                    // Recent transactions
                    if !recentTransactions.isEmpty {
                        recentTransactionsSection
                    }

                    // Detected cards
                    if !cards.isEmpty {
                        cardsSection
                    }

                    // Empty state
                    if transactions.isEmpty && cards.isEmpty {
                        emptyStateView
                    }

                    // Shortcut setup prompt
                    if !UserDefaults.standard.bool(forKey: "shortcutSetupDismissed") {
                        shortcutPrompt
                    }
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .navigationTitle("CardWise")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Recommendation Card

    private var recommendationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CURRENT RECOMMENDATION")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(0.5)

            if let rec = currentRecommendation {
                HStack(spacing: 12) {
                    Image(systemName: rec.category.icon)
                        .font(.title2)
                        .foregroundStyle(categoryColor(rec.category))
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(rec.category.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))

                        Text("Use: \(rec.cardName)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        Text("Earn: \(rec.earnRate)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(categoryColor(rec.category))
                    }

                    Spacer()
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("🍽️ Dining")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Add cards to get recommendations")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Use Apple Pay to auto-detect your cards")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.11, green: 0.11, blue: 0.118))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Missed Rewards

    private var missedRewardsLabel: some View {
        HStack {
            if totalMissedThisMonth > 0.01 {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text(String(format: "$%.2f left on the table this month", totalMissedThisMonth))
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            } else if !thisMonthTransactions.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                Text("Perfect card usage this month! 🎉")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Recent Transactions

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT TRANSACTIONS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            VStack(spacing: 0) {
                ForEach(Array(recentTransactions.enumerated()), id: \.element.id) { index, txn in
                    TransactionRow(transaction: txn)

                    if index < recentTransactions.count - 1 {
                        Divider()
                            .background(.white.opacity(0.1))
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    // MARK: - Cards Section

    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MY CARDS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            VStack(spacing: 0) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    HStack(spacing: 12) {
                        Text("💳")
                            .font(.title3)

                        Text(card.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()

                        Text("\(card.transactionCount) txn")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 10)

                    if index < cards.count - 1 {
                        Divider()
                            .background(.white.opacity(0.1))
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "creditcard.and.123")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)

            Text("No transactions yet")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Use Apple Pay to make a purchase and CardWise will start learning your cards automatically.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Shortcut Prompt

    private var shortcutPrompt: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.title3)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Set up Shortcut")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Auto-detect cards from Apple Pay")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: {
                if let url = URL(string: "shortcuts://create-automation") {
                    UIApplication.shared.open(url)
                }
            }) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func categoryColor(_ category: MerchantCategory) -> Color {
        switch category {
        case .dining: return Color(red: 1, green: 0.42, blue: 0.21)
        case .groceries: return .green
        case .transport: return .blue
        case .travel: return .purple
        case .onlineShopping: return .pink
        case .fuel: return .yellow
        default: return .blue
        }
    }
}

// MARK: - Transaction Row (inline)

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            Image(systemName: transaction.category.icon)
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(categoryColor)
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchantName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text("Used \(transaction.cardName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if !transaction.isOptimal, let optimal = transaction.optimalCardName {
                        Text("→ \(optimal)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(transaction.formattedAmount)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if transaction.isOptimal {
                    Text("✅")
                        .font(.caption)
                } else {
                    Text("❌")
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var categoryColor: Color {
        switch transaction.category {
        case .dining: return Color(red: 1, green: 0.42, blue: 0.21)
        case .groceries: return .green
        case .transport: return .blue
        case .travel: return .purple
        case .onlineShopping: return .pink
        case .fuel: return .yellow
        default: return .gray
        }
    }
}

// MARK: - Settings Sheet

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showAddPass = false
    @State private var loadedPass: PKPass?

    var body: some View {
        NavigationStack {
            List {
                Section("Wallet Pass") {
                    Button(action: {
                        loadedPass = PKPassGeneratorService.shared.loadCardWisePass()
                        if loadedPass != nil {
                            showAddPass = true
                        }
                    }) {
                        Label("Re-add CardWise Pass", systemImage: "wallet.pass.fill")
                    }
                }

                Section("Automation") {
                    Button(action: {
                        if let url = URL(string: "shortcuts://create-automation") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Label("Set up Shortcuts", systemImage: "arrow.triangle.2.circlepath")
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0")
                    LabeledContent("Cards Database", value: "\(CardDatabase.shared.products.count) cards")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddPass) {
                if let pass = loadedPass {
                    SinglePassAddView(pass: pass, onDismiss: {
                        showAddPass = false
                    })
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Transaction.self, Card.self], inMemory: true)
}
