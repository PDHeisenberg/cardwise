// ContentView.swift
// CardWise
//
// Root view — onboarding flow → single home screen. No tabs.

import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if hasCompletedOnboarding {
            HomeView()
        } else {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Transaction.self, Card.self], inMemory: true)
}
