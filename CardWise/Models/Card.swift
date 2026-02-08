// Card.swift
// CardWise
//
// SwiftData model for auto-detected credit cards in user's portfolio

import Foundation
import SwiftData

@Model
final class Card {
    var id: UUID
    var name: String
    var issuer: String
    var matchedProductId: String?
    var rawNames: [String]
    var firstSeen: Date
    var lastUsed: Date
    var transactionCount: Int
    var isActive: Bool
    var matchConfidence: Double

    init(
        id: UUID = UUID(),
        name: String,
        issuer: String,
        matchedProductId: String? = nil,
        rawNames: [String] = [],
        firstSeen: Date = Date(),
        lastUsed: Date = Date(),
        transactionCount: Int = 1,
        isActive: Bool = true,
        matchConfidence: Double = 0
    ) {
        self.id = id
        self.name = name
        self.issuer = issuer
        self.matchedProductId = matchedProductId
        self.rawNames = rawNames
        self.firstSeen = firstSeen
        self.lastUsed = lastUsed
        self.transactionCount = transactionCount
        self.isActive = isActive
        self.matchConfidence = matchConfidence
    }
}

extension Card {
    var displayName: String {
        "\(issuer) \(name)"
    }

    var isMatched: Bool {
        matchedProductId != nil && matchConfidence >= 0.8
    }

    var matchStatusText: String {
        if isMatched {
            return "Matched (\(Int(matchConfidence * 100))%)"
        } else if matchConfidence > 0 {
            return "Possible match (\(Int(matchConfidence * 100))%)"
        } else {
            return "Unknown card"
        }
    }

    var matchStatusColor: String {
        if isMatched { return "green" }
        if matchConfidence > 0.5 { return "orange" }
        return "red"
    }
}
