// MerchantCategoryService.swift
// CardWise
//
// Maps merchant names to spending categories using keyword matching

import Foundation

/// Service that maps merchant names to spending categories using keyword-based matching.
/// Optimized for Singapore merchants.
final class MerchantCategoryService {
    static let shared = MerchantCategoryService()

    // MARK: - Category keyword mappings (Singapore-focused)

    private let categoryKeywords: [MerchantCategory: [String]] = [
        .dining: [
            // Restaurant chains
            "din tai fung", "crystal jade", "paradise group", "imperial treasure",
            "hai di lao", "haidilao", "swee choon", "jumbo seafood", "song fa",
            "tim ho wan", "putien", "burnt ends", "jaan", "luke's oyster",
            "ps cafe", "common man coffee", "ya kun", "toast box", "kopitiam",
            "koufu", "foodfare", "food republic", "food court",
            // Fast food
            "mcdonald", "mcdonalds", "mcd", "burger king", "kfc",
            "popeyes", "subway", "jollibee", "mos burger", "shake shack",
            "five guys", "wendy", "texas chicken", "long john silver",
            "pizza hut", "domino", "dominos",
            // Cafés & bakeries
            "starbucks", "coffee bean", "costa coffee", "nana's green tea",
            "cedele", "breadtalk", "bread talk", "delifrance", "paul bakery",
            "tiong bahru bakery", "bacha coffee", "% arabica",
            // Food delivery
            "foodpanda", "food panda", "deliveroo", "grabfood", "grab food",
            // General dining keywords
            "restaurant", "cafe", "bistro", "grill", "kitchen", "eatery",
            "dining", "bakery", "bar", "pub", "hawker", "food", "dim sum",
            "sushi", "ramen", "noodle", "rice", "chicken", "fish",
            "prata", "murtabak", "nasi", "mee", "laksa", "satay",
            "bak kut teh", "char kway teow", "hokkien mee", "cai png",
            "wonton", "seafood", "steamboat", "hotpot", "bbq", "yakiniku",
            "izakaya", "teppanyaki", "korean bbq"
        ],

        .groceries: [
            // Supermarkets
            "fairprice", "fair price", "ntuc", "cold storage", "giant",
            "sheng siong", "don don donki", "donki", "don quijote",
            "redmart", "amazon fresh", "market place", "marketplace",
            "prime supermarket", "hao mart", "scarlett supermarket",
            "meidi-ya", "meidi ya", "isetan supermarket",
            // Online groceries
            "honestbee", "pandamart", "grab mart", "grabmart",
            // General
            "supermarket", "grocer", "market", "provision"
        ],

        .transport: [
            // Ride hailing
            "grab", "gojek", "go-jek", "tada", "ryde", "comfortdelgro",
            "comfort delgro", "cdg zig",
            // Public transport
            "simplygo", "simply go", "ez-link", "ezlink", "ez link",
            "transitlink", "transit link", "smrt", "sbs transit",
            "sbstransit", "bus", "mrt", "lrt",
            // Private hire
            "taxi", "cab"
        ],

        .travel: [
            // Airlines
            "singapore airlines", "sia", "scoot", "jetstar",
            "airasia", "air asia", "cathay", "thai airways",
            "emirates", "qatar airways", "british airways",
            "klm", "lufthansa", "eva air",
            // Hotels
            "marriott", "hilton", "hyatt", "shangri-la", "shangri la",
            "mandarin oriental", "ritz carlton", "fairmont", "swissotel",
            "intercontinental", "holiday inn", "crowne plaza",
            "pan pacific", "capella", "fullerton",
            "hotel", "resort", "hostel",
            // Travel booking
            "agoda", "booking.com", "booking com", "expedia",
            "trip.com", "tripadvisor", "klook", "traveloka",
            "skyscanner", "krisshop", "kris shop",
            // Airport
            "changi", "airport", "duty free", "dfs",
            "airlines", "airline", "airways"
        ],

        .onlineShopping: [
            // E-commerce
            "shopee", "lazada", "amazon", "qoo10", "carousell",
            "taobao", "aliexpress", "shein", "temu", "zalora",
            "asos", "love bonito", "pomelo", "charles & keith",
            // Tech
            "apple.com", "apple store", "google play", "app store",
            // Digital/subscriptions
            "spotify", "netflix", "disney+", "disney plus",
            "youtube premium", "hbo", "amazon prime",
            "apple music", "apple tv", "playstation", "nintendo",
            "steam", "twitch",
            // General
            "online", ".com", ".sg", "ecommerce"
        ],

        .entertainment: [
            // Cinema
            "golden village", "gv", "shaw theatres", "cathay cineplexes",
            "filmgarde", "the projector", "imax",
            // Attractions
            "universal studios", "uss", "sentosa", "marina bay sands",
            "mbs", "gardens by the bay", "zoo", "bird paradise",
            "night safari", "river wonders", "science centre",
            "artscience", "national gallery",
            // Events
            "sistic", "ticketmaster", "eventbrite", "peatix",
            "concert", "theatre", "theater", "show",
            // Leisure
            "karaoke", "ktv", "bowling", "arcade",
            "cinema", "movie", "museum", "gallery"
        ],

        .fuel: [
            "shell", "esso", "caltex", "sinopec", "spc",
            "petrol", "petroleum", "gas station", "fuel",
            "ev charging", "charge+", "bluesg", "blue sg",
            "sp mobility"
        ],

        .utilities: [
            "sp group", "sp services", "singapore power",
            "geneco", "ohm", "tuas power", "senoko",
            "keppel electric", "pacific light", "union power",
            "starhub", "singtel", "m1", "circles.life",
            "giga", "simonly", "tpg",
            "electricity", "utilities", "power supply",
            "water bill", "conservancy", "town council"
        ],

        .insurance: [
            "prudential", "aia", "great eastern", "ntuc income",
            "singlife", "manulife", "aviva", "axa",
            "tokio marine", "msig", "sompo", "chubb",
            "zurich", "allianz", "fwd",
            "insurance", "premium"
        ],

        .healthcare: [
            "raffles medical", "raffles hospital", "mount elizabeth",
            "mt elizabeth", "gleneagles", "parkway", "thomson medical",
            "national university hospital", "nuh", "sgh",
            "singapore general hospital", "tan tock seng", "ttsh",
            "changi general", "cgh", "khoo teck puat",
            "guardian", "watsons", "unity pharmacy",
            "hospital", "clinic", "medical", "dental", "doctor",
            "pharmacy", "health", "polyclinic"
        ],

        .education: [
            "nus", "ntu", "smu", "sutd", "sit",
            "national university", "nanyang technological",
            "polytechnic", "ite", "tuition", "enrichment",
            "school", "university", "college", "academy",
            "course", "training", "education",
            "udemy", "coursera", "skillsfuture"
        ],

        .departmentStore: [
            "takashimaya", "isetan", "tangs", "tang",
            "robinsons", "metro", "marks & spencer", "m&s",
            "ion orchard", "paragon", "vivocity",
            "department store", "uniqlo", "zara", "h&m",
            "cotton on", "mango"
        ]
    ]

    // MARK: - Public API

    /// Categorize a merchant name based on keyword matching
    func categorize(_ merchantName: String) -> MerchantCategory {
        let normalized = merchantName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        var bestMatch: MerchantCategory = .general
        var bestScore = 0

        for (category, keywords) in categoryKeywords {
            for keyword in keywords {
                if normalized.contains(keyword) {
                    let score = keyword.count // Longer matches are more specific
                    if score > bestScore {
                        bestScore = score
                        bestMatch = category
                    }
                }
            }
        }

        return bestMatch
    }

    /// Get all keywords for a given category
    func keywords(for category: MerchantCategory) -> [String] {
        categoryKeywords[category] ?? []
    }

    /// Check if a merchant belongs to a specific category
    func isMerchant(_ merchantName: String, inCategory category: MerchantCategory) -> Bool {
        return categorize(merchantName) == category
    }
}
