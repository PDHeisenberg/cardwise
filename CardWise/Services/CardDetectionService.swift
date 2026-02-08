// CardDetectionService.swift
// CardWise
//
// Fuzzy matches raw card names from Apple Pay to known card products

import Foundation
import SwiftData

/// Service that detects which card product a raw card name corresponds to.
/// Uses fuzzy string matching with alias support.
@Observable
final class CardDetectionService {
    private let database = CardDatabase.shared
    private let confidenceThreshold: Double = 0.8

    /// Match result from card detection
    struct MatchResult {
        let product: CardProduct
        let confidence: Double
        let matchedOn: String // Which alias or name matched
    }

    // MARK: - Public API

    /// Detect the card product from a raw card name (e.g., "DBS Live Fresh Visa")
    func detectCard(rawName: String) -> MatchResult? {
        let normalized = rawName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        var bestMatch: MatchResult?

        for product in database.products {
            // Check full name
            let fullNameScore = similarityScore(normalized, product.fullName.lowercased())
            if fullNameScore > (bestMatch?.confidence ?? 0) {
                bestMatch = MatchResult(product: product, confidence: fullNameScore, matchedOn: product.fullName)
            }

            // Check display name
            let displayScore = similarityScore(normalized, product.displayName.lowercased())
            if displayScore > (bestMatch?.confidence ?? 0) {
                bestMatch = MatchResult(product: product, confidence: displayScore, matchedOn: product.displayName)
            }

            // Check aliases
            for alias in product.aliases {
                let aliasScore = similarityScore(normalized, alias.lowercased())
                if aliasScore > (bestMatch?.confidence ?? 0) {
                    bestMatch = MatchResult(product: product, confidence: aliasScore, matchedOn: alias)
                }
            }
        }

        return bestMatch
    }

    /// Auto-detect and update card in SwiftData context
    func detectAndSaveCard(rawName: String, context: ModelContext) -> Card {
        let match = detectCard(rawName: rawName)

        // Check if we already have this card in the portfolio
        let fetchDescriptor = FetchDescriptor<Card>(
            predicate: #Predicate { card in
                card.isActive == true
            }
        )

        let existingCards = (try? context.fetch(fetchDescriptor)) ?? []

        // Check if raw name already maps to an existing card
        if let existing = existingCards.first(where: { card in
            card.rawNames.contains(where: { $0.lowercased() == rawName.lowercased() }) ||
            (match != nil && card.matchedProductId == match!.product.id)
        }) {
            // Update existing card
            if !existing.rawNames.contains(rawName) {
                existing.rawNames.append(rawName)
            }
            existing.lastUsed = Date()
            existing.transactionCount += 1
            return existing
        }

        // Create new card
        let card = Card(
            name: match?.product.name ?? rawName,
            issuer: match?.product.issuer ?? extractIssuer(from: rawName),
            matchedProductId: match?.product.id,
            rawNames: [rawName],
            matchConfidence: match?.confidence ?? 0
        )

        context.insert(card)
        return card
    }

    // MARK: - Fuzzy String Matching

    /// Calculate similarity score between two strings (0.0 - 1.0)
    private func similarityScore(_ s1: String, _ s2: String) -> Double {
        // Exact match
        if s1 == s2 { return 1.0 }

        // Contains check (one fully contains the other)
        if s1.contains(s2) || s2.contains(s1) {
            let minLen = Double(min(s1.count, s2.count))
            let maxLen = Double(max(s1.count, s2.count))
            return 0.7 + (0.3 * minLen / maxLen)
        }

        // Token-based matching
        let tokens1 = Set(s1.split(separator: " ").map(String.init))
        let tokens2 = Set(s2.split(separator: " ").map(String.init))
        let intersection = tokens1.intersection(tokens2)

        if !intersection.isEmpty {
            let unionCount = Double(tokens1.union(tokens2).count)
            let intersectionCount = Double(intersection.count)
            let jaccardSimilarity = intersectionCount / unionCount

            // Weighted: matching important tokens (issuer, product name) counts more
            return jaccardSimilarity
        }

        // Levenshtein distance based similarity
        let distance = levenshteinDistance(s1, s2)
        let maxLength = max(s1.count, s2.count)
        guard maxLength > 0 else { return 0 }

        return 1.0 - (Double(distance) / Double(maxLength))
    }

    /// Levenshtein edit distance
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count

        if m == 0 { return n }
        if n == 0 { return m }

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,       // deletion
                    matrix[i][j - 1] + 1,       // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }

        return matrix[m][n]
    }

    /// Try to extract the card issuer from a raw name
    private func extractIssuer(from rawName: String) -> String {
        let knownIssuers = ["DBS", "POSB", "OCBC", "UOB", "Citi", "Citibank", "HSBC",
                           "AMEX", "American Express", "Standard Chartered", "StanChart",
                           "Maybank", "CIMB", "BOC", "Bank of China"]

        let upper = rawName.uppercased()
        for issuer in knownIssuers {
            if upper.contains(issuer.uppercased()) {
                // Normalize
                switch issuer.uppercased() {
                case "CITIBANK": return "Citi"
                case "AMERICAN EXPRESS": return "AMEX"
                case "STANCHART": return "Standard Chartered"
                case "BANK OF CHINA": return "BOC"
                case "POSB": return "DBS"
                default: return issuer
                }
            }
        }
        return "Unknown"
    }
}
