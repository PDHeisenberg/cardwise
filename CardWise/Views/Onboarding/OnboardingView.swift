// OnboardingView.swift
// CardWise
//
// 3-screen onboarding flow

import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    var body: some View {
        TabView(selection: $currentPage) {
            // Screen 1: Value Proposition
            OnboardingPageView(
                icon: "creditcard.trianglebadge.exclamationmark",
                iconColor: .blue,
                title: "Never use the wrong card again",
                subtitle: "CardWise detects your credit cards and tells you which one to use — right inside Apple Wallet.",
                detail: "Most people leave $30-50/month in rewards on the table by using the wrong card. We fix that.",
                buttonTitle: "Get Started",
                buttonAction: { withAnimation { currentPage = 1 } }
            )
            .tag(0)

            // Screen 2: Shortcut Setup
            ShortcutSetupView(
                onContinue: { withAnimation { currentPage = 2 } }
            )
            .tag(1)

            // Screen 3: Wallet Setup
            WalletPassSetupView(
                onComplete: {
                    withAnimation {
                        hasCompletedOnboarding = true
                    }
                }
            )
            .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}

struct OnboardingPageView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let detail: String
    let buttonTitle: String
    let buttonAction: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundStyle(iconColor)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 16) {
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button(action: buttonAction) {
                Text(buttonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 60)
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
