// OnboardingView.swift
// CardWise
//
// Clean 2-screen onboarding:
// Screen 1 — Value prop with pass mockup
// Screen 2 — Add to Apple Wallet + Shortcut setup note

import SwiftUI
import PassKit

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            TabView(selection: $currentPage) {
                // Screen 1: Value Prop
                OnboardingValuePropView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        currentPage = 1
                    }
                }
                .tag(0)

                // Screen 2: Add to Wallet
                OnboardingWalletView {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        hasCompletedOnboarding = true
                    }
                }
                .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Screen 1: Value Proposition

struct OnboardingValuePropView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Pass mockup
            PassMockupView()
                .padding(.horizontal, 40)
                .padding(.bottom, 40)

            // Text
            VStack(spacing: 16) {
                Text("One card to rule\nthem all")
                    .font(.system(size: 34, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)

                Text("CardWise tells you which credit card to use, right in Apple Wallet")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            // Button
            Button(action: onContinue) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 60)
        }
    }
}

// MARK: - Pass Mockup (styled card view)

struct PassMockupView: View {
    @State private var appear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("CardWise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Image(systemName: "wallet.pass.fill")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            // Primary field
            Text("Use Citi Rewards")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            // Secondary fields
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CATEGORY")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("🍽️ Dining")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("EARN RATE")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("4x Points")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(red: 1, green: 0.42, blue: 0.21))
                }
            }

            // Auxiliary
            Text("Tap to open CardWise for details")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(20)
        .frame(height: 200)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.11, green: 0.11, blue: 0.118))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
        .scaleEffect(appear ? 1 : 0.9)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                appear = true
            }
        }
    }
}

// MARK: - Screen 2: Add to Wallet

struct OnboardingWalletView: View {
    let onComplete: () -> Void

    @State private var loadedPass: PKPass?
    @State private var showAddPass = false
    @State private var passAdded = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: "wallet.pass.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
                .symbolRenderingMode(.hierarchical)

            // Title
            VStack(spacing: 12) {
                Text("Add to Apple Wallet")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Your CardWise pass will appear alongside your payment cards and surface recommendations when you're near merchants.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            if passAdded {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Pass added to Wallet!")
                        .fontWeight(.semibold)
                }
                .font(.headline)
                .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            // Action buttons
            VStack(spacing: 16) {
                if !passAdded {
                    if loadedPass != nil {
                        Button(action: { showAddPass = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "wallet.pass.fill")
                                Text("Add CardWise to Wallet")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.black)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                    } else {
                        ProgressView("Loading pass...")
                            .padding()
                    }
                }

                // Shortcut setup note
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text("Set up auto-detection via Shortcuts")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button(action: {
                        if let url = URL(string: "shortcuts://create-automation") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("Open Shortcuts App")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.top, 8)

                Button(action: onComplete) {
                    Text(passAdded ? "Done" : "Skip for now")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(passAdded ? Color.blue : Color.clear)
                        .foregroundColor(passAdded ? .white : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 60)
        }
        .onAppear { loadPass() }
        .sheet(isPresented: $showAddPass) {
            if let pass = loadedPass {
                SinglePassAddView(pass: pass, onDismiss: {
                    showAddPass = false
                    checkPassAdded()
                })
            }
        }
    }

    private func loadPass() {
        let service = PKPassGeneratorService.shared
        if let pass = service.loadCardWisePass() {
            loadedPass = pass
        } else {
            errorMessage = "Pass not found. Run scripts/generate_passes.sh first."
        }
    }

    private func checkPassAdded() {
        let service = PKPassGeneratorService.shared
        if service.isCardWisePassInWallet() {
            withAnimation(.spring(response: 0.3)) {
                passAdded = true
            }
        }
    }
}

// MARK: - UIKit Bridge for single pass

struct SinglePassAddView: UIViewControllerRepresentable {
    let pass: PKPass
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        if let controller = PKAddPassesViewController(pass: pass) {
            controller.delegate = context.coordinator
            return UINavigationController(rootViewController: controller)
        }
        let fallback = UIViewController()
        return UINavigationController(rootViewController: fallback)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    class Coordinator: NSObject, PKAddPassesViewControllerDelegate {
        let onDismiss: () -> Void
        init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }

        func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
            controller.dismiss(animated: true) { self.onDismiss() }
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
