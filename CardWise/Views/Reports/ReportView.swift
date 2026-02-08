// ReportView.swift
// CardWise
//
// Weekly/monthly savings report — "You left $X on the table"

import SwiftUI
import SwiftData

struct ReportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.timestamp, order: .reverse) private var allTransactions: [Transaction]
    @Query(filter: #Predicate<Card> { $0.isActive == true }) private var cards: [Card]

    @State private var selectedPeriod: ReportPeriod = .thisMonth

    enum ReportPeriod: String, CaseIterable, Identifiable {
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case lastMonth = "Last Month"
        case allTime = "All Time"

        var id: String { rawValue }
    }

    private var filteredTransactions: [Transaction] {
        let calendar = Calendar.current
        let now = Date()

        switch selectedPeriod {
        case .thisWeek:
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            return allTransactions.filter { $0.timestamp >= startOfWeek }
        case .thisMonth:
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            return allTransactions.filter { $0.timestamp >= startOfMonth }
        case .lastMonth:
            let startOfThisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth)!
            return allTransactions.filter { $0.timestamp >= startOfLastMonth && $0.timestamp < startOfThisMonth }
        case .allTime:
            return allTransactions
        }
    }

    private var summary: RewardsSummary {
        RewardOptimizationEngine().calculateTotalMissedRewards(transactions: filteredTransactions)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Period picker
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(ReportPeriod.allCases) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if filteredTransactions.isEmpty {
                        emptyReportView
                    } else {
                        // Main report card
                        reportHeroCard

                        // Stats breakdown
                        statsSection

                        // Category breakdown
                        categoryBreakdownSection

                        // Shareable insight
                        shareableInsight
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Reports")
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Hero Card

    private var reportHeroCard: some View {
        VStack(spacing: 16) {
            Text(selectedPeriod.rawValue)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.8))

            Text(summary.formattedMissedRewards)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("left on the table")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.9))

            Divider()
                .background(.white.opacity(0.3))

            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    Text(String(format: "$%.2f", summary.totalSpend))
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Total Spend")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }

                VStack(spacing: 4) {
                    Text("\(summary.transactionCount)")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Transactions")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }

                VStack(spacing: 4) {
                    Text("\(Int(summary.optimizationRate * 100))%")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Optimal")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            LinearGradient(
                colors: summary.totalMissedRewards > 5
                    ? [Color(red: 0.6, green: 0.1, blue: 0.1), Color(red: 0.9, green: 0.3, blue: 0.2)]
                    : [Color(red: 0.1, green: 0.5, blue: 0.3), Color(red: 0.2, green: 0.7, blue: 0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ReportStatBox(
                    title: "Actual Rewards",
                    value: String(format: "$%.2f", summary.totalActualRewards),
                    icon: "dollarsign.circle",
                    color: .blue
                )
                ReportStatBox(
                    title: "Optimal Rewards",
                    value: String(format: "$%.2f", summary.totalOptimalRewards),
                    icon: "star.circle.fill",
                    color: .green
                )
            }

            HStack(spacing: 12) {
                ReportStatBox(
                    title: "Wrong Card Used",
                    value: "\(summary.wrongCardCount) times",
                    icon: "exclamationmark.triangle",
                    color: .orange
                )
                ReportStatBox(
                    title: "Cards Active",
                    value: "\(cards.count)",
                    icon: "creditcard.fill",
                    color: .purple
                )
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Category Breakdown

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Category")
                .font(.headline)

            let sortedCategories = summary.categoryBreakdown.values
                .sorted { $0.missedRewards > $1.missedRewards }

            ForEach(sortedCategories, id: \.category) { catSummary in
                HStack(spacing: 12) {
                    Image(systemName: catSummary.category.icon)
                        .font(.body)
                        .frame(width: 28)
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(catSummary.category.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("\(catSummary.transactionCount) transactions • $\(String(format: "%.0f", catSummary.totalSpend)) spent")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if catSummary.missedRewards > 0.01 {
                        Text(String(format: "-$%.2f", catSummary.missedRewards))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .padding(.vertical, 4)

                if catSummary.category != sortedCategories.last?.category {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Shareable Insight

    private var shareableInsight: some View {
        VStack(spacing: 12) {
            Text("Share Your Report")
                .font(.headline)

            Text("\"I tracked \(summary.transactionCount) card transactions this month and found I left \(summary.formattedMissedRewards) in rewards on the table. CardWise showed me the optimal card for each purchase.\"")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .italic()
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            ShareLink(
                item: "I tracked \(summary.transactionCount) transactions and found I left \(summary.formattedMissedRewards) in rewards on the table! 💳 #CardWise",
                subject: Text("My CardWise Report"),
                message: Text("Check out how much I could be saving with better card usage!")
            ) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Empty State

    private var emptyReportView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)

            Text("No data for this period")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Reports will appear once you have transactions. Use Apple Pay and the automation will capture your spending.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

struct ReportStatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.headline)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ReportView()
        .modelContainer(for: [Transaction.self, Card.self], inMemory: true)
}
