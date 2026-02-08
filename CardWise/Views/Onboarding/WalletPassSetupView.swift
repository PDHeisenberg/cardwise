// WalletPassSetupView.swift
// CardWise
//
// Screen 3 of onboarding: Add real Apple Wallet passes for each spending category.
// Loads pre-signed .pkpass files from the app bundle and presents PKAddPassesViewController.

import SwiftUI
import PassKit

struct WalletPassSetupView: View {
    let onComplete: () -> Void
    @StateObject private var passService = PKPassGeneratorService.shared
    @State private var loadedPasses: [PKPass] = []
    @State private var showAddPasses = false
    @State private var passesAdded = false
    @State private var errorMessage: String?
    @State private var installedCategories: Set<MerchantCategory> = []

    private let featuredCategories: [MerchantCategory] = [
        .dining, .groceries, .transport, .travel, .onlineShopping, .fuel
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: "wallet.pass.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
                .symbolRenderingMode(.hierarchical)

            // Title & description
            VStack(spacing: 12) {
                Text("Add to Apple Wallet")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Add smart recommendation cards to your Wallet. They'll show you which credit card to use — right on your Lock Screen at the right place and time.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
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

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                if passesAdded {
                    // Success state
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Passes added to Wallet!")
                            .fontWeight(.semibold)
                    }
                    .font(.headline)
                    .padding()

                    Button(action: onComplete) {
                        Text("Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                } else if !loadedPasses.isEmpty {
                    // Add to Wallet button
                    Button(action: {
                        showAddPasses = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "wallet.pass.fill")
                            Text("Add \(loadedPasses.count) Passes to Wallet")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .sheet(isPresented: $showAddPasses) {
                        AddPassesSheetView(
                            passes: loadedPasses,
                            onDismiss: {
                                showAddPasses = false
                                checkIfPassesAdded()
                            }
                        )
                    }
                } else {
                    // Loading or no passes available
                    ProgressView("Loading passes...")
                        .padding()
                }

                Button(action: onComplete) {
                    Text(passesAdded ? "" : "Skip for now")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .opacity(passesAdded ? 0 : 1)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 60)
        }
        .onAppear {
            loadPasses()
        }
    }

    private func loadPasses() {
        loadedPasses = passService.loadAllPasses()
        if loadedPasses.isEmpty {
            errorMessage = "No wallet passes found in app bundle. Passes need to be generated with the signing script."
        }
        // Check which passes are already installed
        installedCategories = passService.checkInstalledPasses()
    }

    private func checkIfPassesAdded() {
        let newInstalled = passService.checkInstalledPasses()
        if !newInstalled.isEmpty {
            withAnimation(.spring(response: 0.3)) {
                installedCategories = newInstalled
                passesAdded = true
            }
        }
    }
}

/// UIViewControllerRepresentable wrapper for PKAddPassesViewController
struct AddPassesSheetView: UIViewControllerRepresentable {
    let passes: [PKPass]
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        if let addController = PKAddPassesViewController(passes: passes) {
            addController.delegate = context.coordinator
            let nav = UINavigationController(rootViewController: addController)
            return nav
        }
        // Fallback if controller creation fails
        let fallback = UIViewController()
        fallback.view.backgroundColor = .systemBackground
        let nav = UINavigationController(rootViewController: fallback)
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    class Coordinator: NSObject, PKAddPassesViewControllerDelegate {
        let onDismiss: () -> Void

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
            controller.dismiss(animated: true) {
                self.onDismiss()
            }
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
                    Image(systemName: categoryIcon)
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

    private var categoryIcon: String {
        switch category {
        case .dining: return "fork.knife"
        case .groceries: return "cart.fill"
        case .transport: return "bus.fill"
        case .travel: return "airplane"
        case .onlineShopping: return "bag.fill"
        case .fuel: return "fuelpump.fill"
        default: return "creditcard.fill"
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
