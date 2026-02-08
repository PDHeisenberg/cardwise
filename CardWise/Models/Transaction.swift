// Transaction.swift
// CardWise
//
// SwiftData model for captured Apple Pay transactions

import Foundation
import SwiftData

@Model
final class Transaction {
    var id: UUID
    var merchantName: String
    var amount: Double
    var currency: String
    var cardName: String
    var cardId: UUID?
    var categoryRaw: String
    var optimalCardId: UUID?
    var rewardsDelta: Double
    var actualRewards: Double
    var optimalRewards: Double
    var optimalCardName: String?
    var timestamp: Date
    var isOptimal: Bool

    var category: MerchantCategory {
        get { MerchantCategory(rawValue: categoryRaw) ?? .general }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        merchantName: String,
        amount: Double,
        currency: String = "SGD",
        cardName: String,
        cardId: UUID? = nil,
        category: MerchantCategory = .general,
        optimalCardId: UUID? = nil,
        rewardsDelta: Double = 0,
        actualRewards: Double = 0,
        optimalRewards: Double = 0,
        optimalCardName: String? = nil,
        timestamp: Date = Date(),
        isOptimal: Bool = true
    ) {
        self.id = id
        self.merchantName = merchantName
        self.amount = amount
        self.currency = currency
        self.cardName = cardName
        self.cardId = cardId
        self.categoryRaw = category.rawValue
        self.optimalCardId = optimalCardId
        self.rewardsDelta = rewardsDelta
        self.actualRewards = actualRewards
        self.optimalRewards = optimalRewards
        self.optimalCardName = optimalCardName
        self.timestamp = timestamp
        self.isOptimal = isOptimal
    }
}

extension Transaction {
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }

    var formattedDelta: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: rewardsDelta)) ?? "$\(String(format: "%.2f", rewardsDelta))"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}
