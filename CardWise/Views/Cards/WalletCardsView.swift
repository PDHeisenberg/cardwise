// WalletCardsView.swift
// CardWise
//
// Displays in-app wallet recommendation cards that mirror what would appear in Apple Wallet.
// Each card shows the best credit card for a spending category.

import SwiftUI

struct WalletCardsView: View {
    @StateObject private var passService = PKPassGeneratorService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                if passService.walletCards.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(passService.walletCards) { card in
                            WalletCardView(card: card)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Wallet Cards")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        passService.generateDefaultCards()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "wallet.pass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No Wallet Cards Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Complete onboarding to generate your recommendation cards.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Generate Cards") {
                passService.generateDefaultCards()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)

            Spacer()
        }
    }
}

struct WalletCardView: View {
    let card: PKPassGeneratorService.WalletCard

    private var category: MerchantCategory {
        card.merchantCategory ?? .general
    }

    private var bgColor: Color {
        let c = PKPassGeneratorService.shared.backgroundColorForCategory(category)
        return Color(red: c.red, green: c.green, blue: c.blue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: category.icon)
                    .font(.title3)
                Text(category.displayName.uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(1.5)
                Spacer()
                Text("CardWise")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Main content
            VStack(alignment: .leading, spacing: 4) {
                Text("BEST CARD")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .opacity(0.7)
                Text(card.cardName)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)

            // Earn rate
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("EARN")
                        .font(.caption2)
                        .opacity(0.7)
                    Text(card.rewardRate)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                Spacer()

                if card.monthlySpend > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("THIS MONTH")
                            .font(.caption2)
                            .opacity(0.7)
                        Text(String(format: "$%.0f", card.monthlySpend))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)

            // Location text
            HStack {
                Image(systemName: "location.fill")
                    .font(.caption2)
                Text(card.relevantText)
                    .font(.caption)
                Spacer()
            }
            .foregroundStyle(.white.opacity(0.8))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.white.opacity(0.15))

            // Updated timestamp
            HStack {
                Spacer()
                Text("Updated \(card.updatedAt.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .background(
            LinearGradient(
                colors: [bgColor, bgColor.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: bgColor.opacity(0.4), radius: 8, y: 4)
    }
}

#Preview {
    WalletCardsView()
}
