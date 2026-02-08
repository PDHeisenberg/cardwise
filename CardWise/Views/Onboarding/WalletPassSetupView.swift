// WalletPassSetupView.swift
// CardWise
//
// Screen 3 of onboarding: Install initial Wallet passes

import SwiftUI

struct WalletPassSetupView: View {
    let onComplete: () -> Void
    @State private var installedCategories: Set<MerchantCategory> = []
    @State private var isInstalling = false

    private let featuredCategories: [MerchantCategory] = [
        .dining, .groceries, .transport, .travel, .onlineShopping, .fuel
    ]

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "wallet.pass.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 16) {
                Text("Add to your Wallet")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Install smart passes that show your best card for each category — right inside Apple Wallet.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text("These update with personalized recommendations as we learn your cards.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Category passes preview
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 12) {
                ForEach(featuredCategories) { category in
                    WalletPassPreview(
                        category: category,
                        isInstalled: installedCategories.contains(category)
                    )
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 12) {
                Button(action: {
                    installAllPasses()
                }) {
                    HStack {
                        if isInstalling {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isInstalling ? "Installing..." : "Add to Wallet")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(isInstalling)

                Button(action: onComplete) {
                    Text("Skip for now")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 60)
        }
    }

    private func installAllPasses() {
        isInstalling = true

        // Simulate pass installation (actual implementation requires Apple Developer cert)
        Task {
            for category in featuredCategories {
                try? await Task.sleep(for: .milliseconds(200))
                withAnimation(.spring(response: 0.3)) {
                    installedCategories.insert(category)
                }
            }
            isInstalling = false

            try? await Task.sleep(for: .milliseconds(500))
            onComplete()
        }
    }
}

struct WalletPassPreview: View {
    let category: MerchantCategory
    let isInstalled: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(categoryGradient)
                    .frame(height: 80)

                VStack(spacing: 4) {
                    Image(systemName: category.icon)
                        .font(.title2)
                        .foregroundStyle(.white)

                    Text(category.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isInstalled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white, .green)
                        .font(.title3)
                        .offset(x: 4, y: -4)
                }
            }
        }
    }

    private var categoryGradient: LinearGradient {
        let baseColor: Color = {
            switch category {
            case .dining: return .orange
            case .groceries: return .green
            case .transport: return .blue
            case .travel: return .purple
            case .onlineShopping: return .pink
            case .fuel: return .yellow
            default: return .gray
            }
        }()

        return LinearGradient(
            colors: [baseColor, baseColor.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    WalletPassSetupView(onComplete: {})
}
