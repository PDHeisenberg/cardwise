// CardsView.swift
// CardWise
//
// Auto-detected card portfolio with match status

import SwiftUI
import SwiftData

struct CardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Card.lastUsed, order: .reverse) private var cards: [Card]

    @State private var showingCardDetail: Card?

    var body: some View {
        NavigationStack {
            Group {
                if cards.isEmpty {
                    emptyState
                } else {
                    cardList
                }
            }
            .navigationTitle("My Cards")
            .sheet(item: $showingCardDetail) { card in
                CardDetailView(card: card)
            }
        }
    }

    private var cardList: some View {
        List {
            // Portfolio summary
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(cards.count) Cards Detected")
                            .font(.headline)
                        let matched = cards.filter(\.isMatched).count
                        Text("\(matched) matched to rewards database")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    CircularProgress(
                        value: Double(cards.filter(\.isMatched).count) / max(1, Double(cards.count)),
                        color: .green
                    )
                    .frame(width: 44, height: 44)
                }
            }

            // Card list
            Section("Your Cards") {
                ForEach(cards) { card in
                    CardRowView(card: card)
                        .onTapGesture {
                            showingCardDetail = card
                        }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Cards Detected", systemImage: "creditcard")
        } description: {
            Text("Cards will appear here automatically as you use Apple Pay. Make sure the Shortcut automation is set up.")
        }
    }
}

struct CardRowView: View {
    let card: Card

    var body: some View {
        HStack(spacing: 14) {
            // Issuer badge
            VStack {
                Text(card.issuer.prefix(3).uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 28)
            .background(issuerColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(card.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text("\(card.transactionCount) transactions")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(card.matchStatusText)
                        .font(.caption)
                        .foregroundStyle(matchColor)
                }
            }

            Spacer()

            Image(systemName: card.isMatched ? "checkmark.circle.fill" : "questionmark.circle")
                .foregroundStyle(matchColor)
        }
        .padding(.vertical, 2)
    }

    private var matchColor: Color {
        if card.isMatched { return .green }
        if card.matchConfidence > 0.5 { return .orange }
        return .red
    }

    private var issuerColor: Color {
        switch card.issuer.lowercased() {
        case "dbs", "posb": return .red
        case "ocbc": return Color(red: 0.8, green: 0.1, blue: 0.1)
        case "uob": return .blue
        case "citi", "citibank": return Color(red: 0, green: 0.3, blue: 0.7)
        case "hsbc": return Color(red: 0.8, green: 0, blue: 0.1)
        case "amex", "american express": return Color(red: 0, green: 0.4, blue: 0.8)
        case "standard chartered": return Color(red: 0, green: 0.5, blue: 0.3)
        case "maybank": return Color(red: 1, green: 0.8, blue: 0)
        default: return .gray
        }
    }
}

struct CircularProgress: View {
    let value: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 4)

            Circle()
                .trim(from: 0, to: value)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(value * 100))%")
                .font(.caption2)
                .fontWeight(.bold)
        }
    }
}

#Preview {
    CardsView()
        .modelContainer(for: [Transaction.self, Card.self], inMemory: true)
}
