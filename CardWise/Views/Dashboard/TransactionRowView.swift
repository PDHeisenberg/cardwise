// TransactionRowView.swift
// CardWise
//
// Single transaction row used in lists

import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            Image(systemName: transaction.category.icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(categoryColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            // Merchant and card info
            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.merchantName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(transaction.cardName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !transaction.isOptimal {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text(transaction.optimalCardName ?? "Better card")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            // Amount and status
            VStack(alignment: .trailing, spacing: 3) {
                Text(transaction.formattedAmount)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if transaction.isOptimal {
                    Label("Optimal", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                } else {
                    Text("-\(transaction.formattedDelta)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var categoryColor: Color {
        switch transaction.category {
        case .dining: return .orange
        case .groceries: return .green
        case .transport: return .blue
        case .travel: return .purple
        case .onlineShopping: return .pink
        case .entertainment: return .red
        case .fuel: return .yellow
        case .utilities: return .teal
        case .insurance: return .indigo
        case .healthcare: return .mint
        case .education: return .cyan
        case .departmentStore: return .brown
        case .contactless: return .gray
        case .general: return .secondary
        }
    }
}

#Preview {
    VStack {
        TransactionRowView(transaction: Transaction(
            merchantName: "Din Tai Fung",
            amount: 45.80,
            cardName: "DBS Live Fresh",
            category: .dining,
            rewardsDelta: 1.83,
            optimalCardName: "Citi Rewards",
            isOptimal: false
        ))

        TransactionRowView(transaction: Transaction(
            merchantName: "NTUC FairPrice",
            amount: 67.20,
            cardName: "OCBC 365",
            category: .groceries,
            isOptimal: true
        ))
    }
    .padding()
}
