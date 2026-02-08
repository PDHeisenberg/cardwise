// MerchantCategory.swift
// CardWise
//
// Spending categories for merchant classification

import Foundation

/// All recognized spending categories for card reward matching
enum MerchantCategory: String, CaseIterable, Codable, Identifiable {
    case dining
    case groceries
    case transport
    case travel
    case onlineShopping
    case entertainment
    case fuel
    case utilities
    case insurance
    case healthcare
    case education
    case departmentStore
    case contactless
    case general

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dining: return "Dining"
        case .groceries: return "Groceries"
        case .transport: return "Transport"
        case .travel: return "Travel"
        case .onlineShopping: return "Online Shopping"
        case .entertainment: return "Entertainment"
        case .fuel: return "Fuel"
        case .utilities: return "Utilities"
        case .insurance: return "Insurance"
        case .healthcare: return "Healthcare"
        case .education: return "Education"
        case .departmentStore: return "Department Store"
        case .contactless: return "Contactless"
        case .general: return "General"
        }
    }

    var icon: String {
        switch self {
        case .dining: return "fork.knife"
        case .groceries: return "cart.fill"
        case .transport: return "bus.fill"
        case .travel: return "airplane"
        case .onlineShopping: return "bag.fill"
        case .entertainment: return "film.fill"
        case .fuel: return "fuelpump.fill"
        case .utilities: return "bolt.fill"
        case .insurance: return "shield.fill"
        case .healthcare: return "cross.case.fill"
        case .education: return "graduationcap.fill"
        case .departmentStore: return "building.2.fill"
        case .contactless: return "wave.3.right"
        case .general: return "creditcard.fill"
        }
    }

    var color: String {
        switch self {
        case .dining: return "orange"
        case .groceries: return "green"
        case .transport: return "blue"
        case .travel: return "purple"
        case .onlineShopping: return "pink"
        case .entertainment: return "red"
        case .fuel: return "yellow"
        case .utilities: return "teal"
        case .insurance: return "indigo"
        case .healthcare: return "mint"
        case .education: return "cyan"
        case .departmentStore: return "brown"
        case .contactless: return "gray"
        case .general: return "secondary"
        }
    }
}
