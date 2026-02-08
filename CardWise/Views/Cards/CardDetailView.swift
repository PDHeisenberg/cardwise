// CardDetailView.swift
// CardWise
//
// Detail view for a detected card showing reward tiers and usage stats

import SwiftUI
import SwiftData

struct CardDetailView: View {
    let card: Card
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private var matchedProduct: CardProduct? {
        guard let id = card.matchedProductId else { return nil }
        return CardDatabase.shared.product(byId: id)
    }

    var body: some View {
        NavigationStack {
            List {
                // Card header
                Section {
                    VStack(spacing: 16) {
                        // Card visual
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 180)
                            .overlay {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text(card.issuer)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        Spacer()
                                        if let product = matchedProduct {
                                            Text(product.network.rawValue.uppercased())
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.white.opacity(0.8))
                                        }
                                    }

                                    Spacer()

                                    Text(card.displayName)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)

                                    HStack {
                                        Label(card.matchStatusText, systemImage: card.isMatched ? "checkmark.shield.fill" : "questionmark.circle")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.9))
                                        Spacer()
                                    }
                                }
                                .padding()
                            }
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                // Usage stats
                Section("Usage") {
                    LabeledContent("First Seen", value: card.firstSeen.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("Last Used", value: card.lastUsed.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("Total Transactions", value: "\(card.transactionCount)")
                }

                // Matched raw names
                Section("Detected Names") {
                    ForEach(card.rawNames, id: \.self) { name in
                        Text(name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // Reward tiers (if matched)
                if let product = matchedProduct {
                    Section("Reward Tiers") {
                        ForEach(product.rewardTiers) { tier in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(tier.rateDescription)
                                        .font(.headline)
                                        .foregroundStyle(.green)

                                    Spacer()

                                    if let cap = tier.monthlyCap {
                                        Text("Cap: $\(Int(cap))/mo")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                }

                                // Category pills
                                FlowLayout(spacing: 4) {
                                    ForEach(tier.categories, id: \.self) { category in
                                        Text(category.displayName)
                                            .font(.caption2)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.blue.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                }

                                if let conditions = tier.conditions {
                                    Text(conditions)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if let minSpend = tier.minSpend {
                                    Text("Min spend: $\(Int(minSpend))/month")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Section("Card Info") {
                        LabeledContent("Annual Fee", value: product.annualFee == 0 ? "Free" : String(format: "$%.2f", product.annualFee))
                        if product.annualFeeWaived {
                            LabeledContent("First Year", value: "Waived")
                        }
                        LabeledContent("Network", value: product.network.rawValue.capitalized)
                        LabeledContent("Min Income", value: String(format: "$%.0f", product.minIncome))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Card Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Simple flow layout for category pills
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = flowLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = flowLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func flowLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}

#Preview {
    CardDetailView(card: Card(
        name: "Live Fresh",
        issuer: "DBS",
        matchedProductId: "dbs-live-fresh",
        rawNames: ["DBS Live Fresh Visa"],
        transactionCount: 15,
        matchConfidence: 0.95
    ))
}
