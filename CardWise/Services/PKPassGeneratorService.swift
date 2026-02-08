// PKPassGeneratorService.swift
// CardWise
//
// Loads pre-signed .pkpass bundles from the app's Resources/Passes/ directory
// and presents them via PKAddPassesViewController for real Apple Wallet integration.

import Foundation
import PassKit
import UIKit
import CoreLocation

/// Service that loads and presents real Apple Wallet passes for card recommendations.
///
/// Strategy: .pkpass files are pre-signed at build time using the generate_passes.sh script.
/// The app bundles these signed passes and presents them to the user via PKAddPassesViewController
/// during onboarding. Each pass represents a spending category (dining, groceries, etc.)
/// and shows the user's best card recommendation for that category.
final class PKPassGeneratorService: ObservableObject {
    static let shared = PKPassGeneratorService()

    /// Spending categories that have bundled passes
    static let passCategories: [MerchantCategory] = [
        .dining, .groceries, .transport, .travel, .onlineShopping, .fuel
    ]

    /// Published state
    @Published var passesAddedToWallet: Set<String> = []
    @Published var loadError: String?

    private let passLibrary = PKPassLibrary()
    private let locationManager = CLLocationManager()

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

    /// Load a single .pkpass file from the bundle
    func loadPass(for category: MerchantCategory) -> PKPass? {
        let filename = category.rawValue
        guard let url = Bundle.main.url(forResource: filename, withExtension: "pkpass", subdirectory: "Passes") else {
            // Also try without subdirectory (flat bundle)
            guard let flatUrl = Bundle.main.url(forResource: filename, withExtension: "pkpass") else {
                print("⚠️ Pass file not found: \(filename).pkpass")
                return nil
            }
            return loadPassFromURL(flatUrl)
        }
        return loadPassFromURL(url)
    }

    private func loadPassFromURL(_ url: URL) -> PKPass? {
        do {
            let data = try Data(contentsOf: url)
            let pass = try PKPass(data: data)
            return pass
        } catch {
            print("❌ Failed to load pass from \(url.lastPathComponent): \(error)")
            loadError = error.localizedDescription
            return nil
        }
    }

    /// Load all bundled passes
    func loadAllPasses() -> [PKPass] {
        var passes: [PKPass] = []
        for category in Self.passCategories {
            if let pass = loadPass(for: category) {
                passes.append(pass)
            }
        }
        return passes
    }

    /// Present the "Add to Wallet" UI for a single pass
    func presentAddPass(
        _ pass: PKPass,
        from viewController: UIViewController,
        completion: (() -> Void)? = nil
    ) {
        guard canAddPasses else {
            loadError = "This device cannot add passes to Wallet"
            return
        }

        let addController = PKAddPassesViewController(pass: pass)
        addController?.delegate = AddPassDelegate.shared
        AddPassDelegate.shared.completion = { [weak self] in
            self?.markPassAdded(pass)
            completion?()
        }

        if let addController = addController {
            viewController.present(addController, animated: true)
        }
    }

    /// Present the "Add to Wallet" UI for multiple passes at once
    func presentAddPasses(
        _ passes: [PKPass],
        from viewController: UIViewController,
        completion: (() -> Void)? = nil
    ) {
        guard canAddPasses else {
            loadError = "This device cannot add passes to Wallet"
            return
        }

        guard !passes.isEmpty else {
            loadError = "No passes to add"
            return
        }

        let addController = PKAddPassesViewController(passes: passes)
        addController?.delegate = AddPassDelegate.shared
        AddPassDelegate.shared.completion = { [weak self] in
            for pass in passes {
                self?.markPassAdded(pass)
            }
            completion?()
        }

        if let addController = addController {
            viewController.present(addController, animated: true)
        }
    }

    /// Add passes directly to wallet without UI (requires user permission)
    func addPassesSilently(_ passes: [PKPass]) {
        guard isWalletAvailable else { return }
        passLibrary.addPasses(passes) { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .shouldReviewPasses:
                    // User needs to review — passes will show in Wallet pending
                    for pass in passes {
                        self?.markPassAdded(pass)
                    }
                case .didAddPasses:
                    for pass in passes {
                        self?.markPassAdded(pass)
                    }
                case .didCancelAddPasses:
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    /// Check if a specific category pass is already in the wallet
    func isPassInWallet(for category: MerchantCategory) -> Bool {
        guard isWalletAvailable else { return false }

        let serial = "cardwise-\(category.rawValue)-v1"
        let passes = passLibrary.passes()
        return passes.contains { $0.serialNumber == serial }
    }

    /// Check which passes are already installed
    func checkInstalledPasses() -> Set<MerchantCategory> {
        guard isWalletAvailable else { return [] }

        var installed = Set<MerchantCategory>()
        let walletPasses = passLibrary.passes()

        for category in Self.passCategories {
            let serial = "cardwise-\(category.rawValue)-v1"
            if walletPasses.contains(where: { $0.serialNumber == serial }) {
                installed.insert(category)
            }
        }

        return installed
    }

    /// Get the number of available passes in the bundle
    var availablePassCount: Int {
        var count = 0
        for category in Self.passCategories {
            let filename = category.rawValue
            if Bundle.main.url(forResource: filename, withExtension: "pkpass", subdirectory: "Passes") != nil ||
               Bundle.main.url(forResource: filename, withExtension: "pkpass") != nil {
                count += 1
            }
        }
        return count
    }

    // MARK: - Location-based (supplements Wallet pass geofencing)

    /// Register for location updates to complement pass location triggers
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    // MARK: - Persistence

    private func markPassAdded(_ pass: PKPass) {
        passesAddedToWallet.insert(pass.serialNumber)
        saveInstalledState()
    }

    private func saveInstalledState() {
        let serials = Array(passesAddedToWallet)
        UserDefaults.standard.set(serials, forKey: "cardwise_installed_passes")
    }

    private func loadInstalledState() {
        if let serials = UserDefaults.standard.stringArray(forKey: "cardwise_installed_passes") {
            passesAddedToWallet = Set(serials)
        }
    }

    // MARK: - Pass Colors (for UI)

    func backgroundColorForCategory(_ category: MerchantCategory) -> (red: Double, green: Double, blue: Double) {
        switch category {
        case .dining: return (255/255, 107/255, 53/255)
        case .groceries: return (52/255, 199/255, 89/255)
        case .transport: return (0/255, 122/255, 255/255)
        case .travel: return (175/255, 82/255, 222/255)
        case .onlineShopping: return (255/255, 55/255, 95/255)
        case .entertainment: return (255/255, 59/255, 48/255)
        case .fuel: return (255/255, 179/255, 0/255)
        case .utilities: return (90/255, 200/255, 250/255)
        case .insurance: return (88/255, 86/255, 214/255)
        case .healthcare: return (0/255, 199/255, 190/255)
        case .education: return (50/255, 173/255, 230/255)
        case .departmentStore: return (162/255, 132/255, 94/255)
        case .contactless: return (142/255, 142/255, 147/255)
        case .general: return (99/255, 99/255, 102/255)
        }
    }
}

// MARK: - PKAddPassesViewControllerDelegate

private class AddPassDelegate: NSObject, PKAddPassesViewControllerDelegate {
    static let shared = AddPassDelegate()
    var completion: (() -> Void)?

    func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
        controller.dismiss(animated: true) { [weak self] in
            self?.completion?()
            self?.completion = nil
        }
    }
}

// MARK: - SwiftUI Bridge for PKAddPassesViewController

import SwiftUI

/// SwiftUI wrapper for presenting PKAddPassesViewController
struct AddPassesView: UIViewControllerRepresentable {
    let passes: [PKPass]
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let host = UIViewController()
        // Present in the next run loop to avoid presentation conflicts
        DispatchQueue.main.async {
            let addController = PKAddPassesViewController(passes: passes)
            addController?.delegate = context.coordinator
            if let addController = addController {
                host.present(addController, animated: true)
            }
        }
        return host
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    class Coordinator: NSObject, PKAddPassesViewControllerDelegate {
        let onDismiss: () -> Void

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
            controller.dismiss(animated: true) { [weak self] in
                self?.onDismiss()
            }
        }
    }
}

/// SwiftUI view that presents the native "Add to Apple Wallet" button
struct AddToWalletButton: View {
    let passes: [PKPass]
    @Binding var isPresented: Bool
    let onComplete: () -> Void

    var body: some View {
        Button(action: {
            isPresented = true
        }) {
            PKAddPassButtonWrapper()
                .frame(width: 280, height: 48)
        }
        .sheet(isPresented: $isPresented) {
            if !passes.isEmpty {
                AddPassesView(passes: passes) {
                    isPresented = false
                    onComplete()
                }
            }
        }
    }
}

/// Wraps PKAddPassButton for use in SwiftUI
struct PKAddPassButtonWrapper: UIViewRepresentable {
    func makeUIView(context: Context) -> PKAddPassButton {
        let button = PKAddPassButton(addPassButtonStyle: .black)
        button.isUserInteractionEnabled = false  // Handled by parent SwiftUI button
        return button
    }

    func updateUIView(_ uiView: PKAddPassButton, context: Context) {}
}
