// PKPassGeneratorService.swift
// CardWise
//
// Loads the single pre-signed CardWise .pkpass bundle from Resources/Passes/
// and presents it via PKAddPassesViewController for Apple Wallet integration.
//
// ONE pass. Not six. The pass is the product.

import Foundation
import PassKit
import UIKit
import CoreLocation
import SwiftUI

/// Service that loads and presents the single CardWise Apple Wallet pass.
final class PKPassGeneratorService: ObservableObject {
    static let shared = PKPassGeneratorService()

    /// Serial number for the single CardWise pass
    static let passSerial = "cardwise-main-v1"

    /// Published state
    @Published var passAddedToWallet: Bool = false
    @Published var loadError: String?

    private let passLibrary = PKPassLibrary()

    private init() {
        loadInstalledState()
    }

    // MARK: - Public API

    /// Check if Wallet passes are supported on this device
    var isWalletAvailable: Bool {
        PKPassLibrary.isPassLibraryAvailable()
    }

    /// Check if passes can be added
    var canAddPasses: Bool {
        PKAddPassesViewController.canAddPasses()
    }

    /// Load the single CardWise .pkpass from the bundle
    func loadCardWisePass() -> PKPass? {
        // Try Passes/ subdirectory first, then flat bundle
        if let url = Bundle.main.url(forResource: "cardwise", withExtension: "pkpass", subdirectory: "Passes") {
            return loadPassFromURL(url)
        }
        if let url = Bundle.main.url(forResource: "cardwise", withExtension: "pkpass") {
            return loadPassFromURL(url)
        }
        print("⚠️ cardwise.pkpass not found in bundle")
        loadError = "Pass file not found"
        return nil
    }

    private func loadPassFromURL(_ url: URL) -> PKPass? {
        do {
            let data = try Data(contentsOf: url)
            let pass = try PKPass(data: data)
            return pass
        } catch {
            print("❌ Failed to load pass: \(error)")
            loadError = error.localizedDescription
            return nil
        }
    }

    /// Check if the CardWise pass is already in the wallet
    func isCardWisePassInWallet() -> Bool {
        guard isWalletAvailable else { return false }
        let passes = passLibrary.passes()
        return passes.contains { $0.serialNumber == Self.passSerial }
    }

    /// Request location permission for pass geofencing
    func requestLocationPermission() {
        let manager = CLLocationManager()
        manager.requestWhenInUseAuthorization()
    }

    // MARK: - Persistence

    func markPassAdded() {
        passAddedToWallet = true
        UserDefaults.standard.set(true, forKey: "cardwise_pass_added")
    }

    private func loadInstalledState() {
        passAddedToWallet = UserDefaults.standard.bool(forKey: "cardwise_pass_added")
    }

    // MARK: - Category Colors

    func colorForCategory(_ category: MerchantCategory) -> (red: Double, green: Double, blue: Double) {
        switch category {
        case .dining: return (1.0, 0.42, 0.21) // #FF6B35
        case .groceries: return (0.20, 0.78, 0.35) // #34C759
        case .transport: return (0.0, 0.48, 1.0) // #007AFF
        case .travel: return (0.69, 0.32, 0.87) // #AF52DE
        case .onlineShopping: return (1.0, 0.22, 0.37) // #FF375F
        case .fuel: return (1.0, 0.80, 0.0) // #FFCC00
        default: return (0.04, 0.52, 1.0) // #0A84FF
        }
    }
}

// MARK: - SwiftUI wrapper for PKAddPassButton

struct PKAddPassButtonWrapper: UIViewRepresentable {
    func makeUIView(context: Context) -> PKAddPassButton {
        let button = PKAddPassButton(addPassButtonStyle: .black)
        button.isUserInteractionEnabled = false
        return button
    }

    func updateUIView(_ uiView: PKAddPassButton, context: Context) {}
}
