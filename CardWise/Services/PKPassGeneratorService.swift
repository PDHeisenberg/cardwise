// PKPassGeneratorService.swift
// CardWise
//
// Generates .pkpass bundles for Apple Wallet with card recommendations per category

import Foundation
#if canImport(PassKit)
import PassKit
#endif

/// Service that generates Apple Wallet pass bundles (.pkpass) for each spending category
/// showing the user's optimal card recommendation.
///
/// Note: Actual pass signing requires Apple Developer certificates.
/// This generates the pass.json structure and supporting files.
final class PKPassGeneratorService {
    static let shared = PKPassGeneratorService()

    /// Pass template for a category recommendation
    struct PassTemplate {
        let category: MerchantCategory
        let cardName: String
        let rewardRate: String
        let monthlySpend: Double
        let monthlyRewards: Double
    }

    // MARK: - Public API

    /// Generate pass JSON for a category recommendation
    func generatePassJSON(for template: PassTemplate) -> [String: Any] {
        let pass: [String: Any] = [
            "formatVersion": 1,
            "passTypeIdentifier": "pass.com.cardwise.recommendation",
            "serialNumber": "\(template.category.rawValue)-\(UUID().uuidString)",
            "teamIdentifier": "YOUR_TEAM_ID", // Replace with actual Team ID
            "organizationName": "CardWise",
            "description": "\(template.category.displayName) - Best Card",
            "logoText": "CardWise",
            "foregroundColor": "rgb(255, 255, 255)",
            "backgroundColor": backgroundColorForCategory(template.category),
            "labelColor": "rgb(255, 255, 255)",
            "generic": [
                "primaryFields": [
                    [
                        "key": "bestCard",
                        "label": "BEST CARD",
                        "value": template.cardName
                    ]
                ],
                "secondaryFields": [
                    [
                        "key": "earn",
                        "label": "EARN",
                        "value": template.rewardRate
                    ],
                    [
                        "key": "category",
                        "label": "CATEGORY",
                        "value": template.category.displayName
                    ]
                ],
                "auxiliaryFields": [
                    [
                        "key": "monthSpend",
                        "label": "THIS MONTH",
                        "value": String(format: "$%.2f spent", template.monthlySpend),
                        "textAlignment": "PKTextAlignmentLeft"
                    ],
                    [
                        "key": "monthRewards",
                        "label": "REWARDS",
                        "value": String(format: "$%.2f earned", template.monthlyRewards),
                        "textAlignment": "PKTextAlignmentRight"
                    ]
                ],
                "backFields": [
                    [
                        "key": "info",
                        "label": "About CardWise",
                        "value": "CardWise automatically detects your credit cards and recommends the optimal card for each spending category. This pass updates as we learn more about your spending."
                    ],
                    [
                        "key": "updated",
                        "label": "Last Updated",
                        "value": ISO8601DateFormatter().string(from: Date())
                    ]
                ]
            ],
            "locations": locationsForCategory(template.category),
            "relevantDate": ISO8601DateFormatter().string(from: Date())
        ]

        return pass
    }

    /// Generate all category passes for a user's portfolio
    func generateAllPasses(
        recommendations: [MerchantCategory: (CardProduct, RewardTier)],
        monthlySpend: [MerchantCategory: Double] = [:],
        monthlyRewards: [MerchantCategory: Double] = [:]
    ) -> [[String: Any]] {
        var passes: [[String: Any]] = []

        for (category, (card, tier)) in recommendations {
            let template = PassTemplate(
                category: category,
                cardName: card.displayName,
                rewardRate: tier.rateDescription,
                monthlySpend: monthlySpend[category] ?? 0,
                monthlyRewards: monthlyRewards[category] ?? 0
            )
            passes.append(generatePassJSON(for: template))
        }

        return passes
    }

    /// Write pass bundle structure to a directory (for development/testing)
    func writePassBundle(
        passJSON: [String: Any],
        to directory: URL,
        category: MerchantCategory
    ) throws {
        let bundleDir = directory.appendingPathComponent("\(category.rawValue).pass")
        try FileManager.default.createDirectory(at: bundleDir, withIntermediateDirectories: true)

        // Write pass.json
        let jsonData = try JSONSerialization.data(withJSONObject: passJSON, options: .prettyPrinted)
        try jsonData.write(to: bundleDir.appendingPathComponent("pass.json"))

        // Note: In production, you'd also need:
        // - icon.png, icon@2x.png (app icon for the pass)
        // - logo.png, logo@2x.png (logo shown on pass)
        // - manifest.json (SHA1 hashes of all files)
        // - signature (signed with Apple certificate)
    }

    // MARK: - Helpers

    private func backgroundColorForCategory(_ category: MerchantCategory) -> String {
        switch category {
        case .dining: return "rgb(255, 107, 53)"
        case .groceries: return "rgb(52, 199, 89)"
        case .transport: return "rgb(0, 122, 255)"
        case .travel: return "rgb(175, 82, 222)"
        case .onlineShopping: return "rgb(255, 55, 95)"
        case .entertainment: return "rgb(255, 59, 48)"
        case .fuel: return "rgb(255, 204, 0)"
        case .utilities: return "rgb(90, 200, 250)"
        case .insurance: return "rgb(88, 86, 214)"
        case .healthcare: return "rgb(0, 199, 190)"
        case .education: return "rgb(50, 173, 230)"
        case .departmentStore: return "rgb(162, 132, 94)"
        case .contactless: return "rgb(142, 142, 147)"
        case .general: return "rgb(99, 99, 102)"
        }
    }

    /// Pre-defined locations for geofencing (Singapore landmarks)
    private func locationsForCategory(_ category: MerchantCategory) -> [[String: Any]] {
        switch category {
        case .dining:
            return [
                // Orchard Road dining
                ["latitude": 1.3048, "longitude": 103.8318, "relevantText": "🍽️ Use \(category.displayName) card here"],
                // Chinatown
                ["latitude": 1.2834, "longitude": 103.8441, "relevantText": "🍽️ Dining area - use your best card"],
                // Clarke Quay
                ["latitude": 1.2917, "longitude": 103.8463, "relevantText": "🍽️ Use your best dining card"]
            ]
        case .groceries:
            return [
                // General supermarket locations around Singapore
                ["latitude": 1.3521, "longitude": 103.8198, "relevantText": "🛒 Shopping for groceries? Use your best card"]
            ]
        case .transport:
            return [
                // Changi Airport
                ["latitude": 1.3644, "longitude": 103.9915, "relevantText": "🚌 Remember your best transport card"],
                // MRT central
                ["latitude": 1.2996, "longitude": 103.8454, "relevantText": "🚌 Use your best transport card"]
            ]
        case .fuel:
            return [
                ["latitude": 1.3521, "longitude": 103.8198, "relevantText": "⛽ Use your best fuel card"]
            ]
        case .travel:
            return [
                // Changi Airport
                ["latitude": 1.3644, "longitude": 103.9915, "relevantText": "✈️ Use your best travel card"]
            ]
        default:
            return []
        }
    }
}
