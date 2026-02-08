// ShortcutSetupView.swift
// CardWise
//
// Guides user through setting up the iOS Shortcuts Transaction Trigger

import SwiftUI

struct ShortcutSetupView: View {
    let onContinue: () -> Void
    @State private var showingInstructions = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.orange)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 16) {
                Text("Set up auto-detection")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("We use iOS Shortcuts to learn your cards automatically from Apple Pay transactions.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text("Just use Apple Pay normally — we'll learn your cards.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Setup steps
            VStack(alignment: .leading, spacing: 16) {
                SetupStepRow(number: 1, text: "Open the Shortcuts app")
                SetupStepRow(number: 2, text: "Go to Automation tab")
                SetupStepRow(number: 3, text: "Tap + → Transaction")
                SetupStepRow(number: 4, text: "Add 'Log Transaction' action from CardWise")
                SetupStepRow(number: 5, text: "Pass merchant, amount, and card name")
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button(action: {
                    showingInstructions = true
                }) {
                    Text("View Detailed Setup Guide")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }

                Button(action: onContinue) {
                    Text("Set Up Shortcut")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button(action: onContinue) {
                    Text("I'll do this later")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 60)
        }
        .sheet(isPresented: $showingInstructions) {
            ShortcutInstructionsSheet()
        }
    }
}

struct SetupStepRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.orange)
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()
        }
    }
}

struct ShortcutInstructionsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    InstructionSection(
                        title: "1. Open Shortcuts App",
                        detail: "Launch the built-in Shortcuts app on your iPhone. It has a blue and pink icon."
                    )

                    InstructionSection(
                        title: "2. Go to Automation",
                        detail: "Tap the 'Automation' tab at the bottom of the screen."
                    )

                    InstructionSection(
                        title: "3. Create New Automation",
                        detail: "Tap the '+' button in the top right, then select 'Transaction' from the Personal Automation list. This trigger fires every time you complete an Apple Pay transaction."
                    )

                    InstructionSection(
                        title: "4. Add CardWise Action",
                        detail: "In the action step, search for 'Log Transaction' — this is the CardWise action. Select it."
                    )

                    InstructionSection(
                        title: "5. Wire the Parameters",
                        detail: """
                        Connect the Shortcut variables to CardWise:
                        • Merchant Name → Shortcut Input: Merchant
                        • Amount → Shortcut Input: Amount
                        • Card Name → Shortcut Input: Card/Pass Name
                        
                        These are automatically provided by the Transaction trigger.
                        """
                    )

                    InstructionSection(
                        title: "6. Set to Run Immediately",
                        detail: "Toggle 'Run Immediately' to ON and disable 'Notify When Run' for a seamless experience. This ensures the shortcut runs silently in the background."
                    )

                    InstructionSection(
                        title: "7. Done!",
                        detail: "That's it! Every Apple Pay transaction will now be automatically logged and analyzed. CardWise will learn your cards and notify you when a better card is available."
                    )
                }
                .padding()
            }
            .navigationTitle("Setup Guide")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct InstructionSection: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ShortcutSetupView(onContinue: {})
}
