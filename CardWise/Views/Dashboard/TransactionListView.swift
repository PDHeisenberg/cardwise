// TransactionListView.swift
// CardWise
//
// Full transaction history with filtering and optimal card indicators

import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.timestamp, order: .reverse) private var transactions: [Transaction]

    @State private var searchText = ""
    @State private var selectedCategory: MerchantCategory?
    @State private var showOptimalOnly = false

    private var filteredTransactions: [Transaction] {
        var result = transactions

        if !searchText.isEmpty {
            result = result.filter { txn in
                txn.merchantName.localizedCaseInsensitiveContains(searchText) ||
                txn.cardName.localizedCaseInsensitiveContains(searchText)
            }
        }

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        if showOptimalOnly {
            result = result.filter { !$0.isOptimal }
        }

        return result
    }

    private var groupedTransactions: [(String, [Transaction])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        let grouped = Dictionary(grouping: filteredTransactions) { txn in
            formatter.string(from: txn.timestamp)
        }

        return grouped.sorted { a, b in
            guard let dateA = filteredTransactions.first(where: { formatter.string(from: $0.timestamp) == a.key }),
                  let dateB = filteredTransactions.first(where: { formatter.string(from: $0.timestamp) == b.key }) else {
                return false
            }
            return dateA.timestamp > dateB.timestamp
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if transactions.isEmpty {
                    emptyState
                } else {
                    transactionList
                }
            }
            .navigationTitle("Transactions")
            .searchable(text: $searchText, prompt: "Search merchants or cards")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle("Wrong Card Only", isOn: $showOptimalOnly)

                        Picker("Category", selection: $selectedCategory) {
                            Text("All Categories").tag(nil as MerchantCategory?)
                            ForEach(MerchantCategory.allCases) { category in
                                Label(category.displayName, systemImage: category.icon)
                                    .tag(category as MerchantCategory?)
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
    }

    private var transactionList: some View {
        List {
            // Summary bar
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text("\(filteredTransactions.count) transactions")
                            .font(.headline)
                        let missed = filteredTransactions.reduce(0.0) { $0 + $1.rewardsDelta }
                        Text("Missed: \(String(format: "$%.2f", missed))")
                            .font(.caption)
                            .foregroundStyle(missed > 0 ? .red : .green)
                    }
                    Spacer()
                    let total = filteredTransactions.reduce(0.0) { $0 + $1.amount }
                    Text(String(format: "$%.2f", total))
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }

            // Grouped by month
            ForEach(groupedTransactions, id: \.0) { month, txns in
                Section(header: Text(month)) {
                    ForEach(txns) { txn in
                        TransactionRowView(transaction: txn)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Transactions", systemImage: "tray")
        } description: {
            Text("Your Apple Pay transactions will appear here once the Shortcut is set up.")
        }
    }
}

#Preview {
    TransactionListView()
        .modelContainer(for: [Transaction.self, Card.self], inMemory: true)
}
