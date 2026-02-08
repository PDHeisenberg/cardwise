// DashboardView.swift
// CardWise
//
// Main dashboard showing recent transactions, savings missed, quick stats

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.timestamp, order: .reverse) private var transactions: [Transaction]
    @Query(filter: #Predicate<Card> { $0.isActive == true }) private var cards: [Card]

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

    private var totalSpendThisMonth: Double {
        thisMonthTransactions.reduce(0) { $0 + $1.amount }
    }

    private var wrongCardCount: Int {
        thisMonthTransactions.filter { !$0.isOptimal }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Hero card — money left on the table
                    heroCard

                    // Quick stats grid
                    statsGrid

                    // Recent transactions
                    if !recentTransactions.isEmpty {
                        recentTransactionsSection
                    } else {
                        emptyStateView
                    }

                    // Category recommendations
                    if !cards.isEmpty {
                        recommendationsSection
                    }
                }
                .padding()
            }
            .navigationTitle("CardWise")
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: 12) {
            Text("This Month")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            if totalMissedThisMonth > 0 {
                Text(String(format: "$%.2f", totalMissedThisMonth))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("left on the table")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.9))
            } else if transactions.isEmpty {
                Text("$0.00")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Start using Apple Pay to track savings")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.9))
            } else {
                Text("$0.00")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Perfect card usage! 🎉")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            LinearGradient(
                colors: totalMissedThisMonth > 0
                    ? [Color.red, Color.orange]
                    : [Color.green, Color.teal],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatCard(
                title: "Transactions",
                value: "\(thisMonthTransactions.count)",
                icon: "list.bullet",
                color: .blue
            )

            StatCard(
                title: "Cards",
                value: "\(cards.count)",
                icon: "creditcard.fill",
                color: .purple
            )

            StatCard(
                title: "Wrong Card",
                value: "\(wrongCardCount)",
                icon: "exclamationmark.triangle.fill",
                color: wrongCardCount > 0 ? .orange : .green
            )
        }
    }

    // MARK: - Recent Transactions

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)
                Spacer()
                // The NavigationLink to full list is in the tab bar
            }

            ForEach(recentTransactions) { txn in
                TransactionRowView(transaction: txn)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "creditcard.and.123")
                .font(.system(size: 60))
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
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Recommendations

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Best Cards")
                .font(.headline)

            let matchedIds = cards.compactMap(\.matchedProductId)
            let engine = RewardOptimizationEngine()
            let recs = engine.generateAllRecommendations(userCardProductIds: matchedIds)

            ForEach(Array(recs.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { category in
                if let (card, tier) = recs[category] {
                    HStack(spacing: 12) {
                        Image(systemName: category.icon)
                            .font(.title3)
                            .frame(width: 32)
                            .foregroundStyle(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(card.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(tier.rateDescription)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Transaction.self, Card.self], inMemory: true)
}
