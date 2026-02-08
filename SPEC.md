# CardWise — Credit Card Optimizer

## Vision
An iOS app that automatically detects which credit cards you use and recommends the optimal card at the moment of payment via Apple Wallet passes — zero friction, zero thinking.

---

## Core Problem
People carry 3-6 credit cards but almost always tap the same default card. Each card has different reward categories (dining 4x, groceries 5%, transport 3x). Users leave hundreds of dollars in rewards on the table every year simply because they don't remember which card is best where.

## Solution
CardWise intercepts the payment moment by placing smart recommendation passes inside Apple Wallet, and learns your card portfolio automatically from your Apple Pay transactions.

---

## MVP (Phase 1) — Auto-Detect + PKPass Recommendations

### Core Features

#### 1. Auto-Detect Card Portfolio (Transaction Trigger)
- On first launch, user grants permission for iOS Shortcuts Transaction Trigger automation
- App guides user through setting up the Shortcut (or auto-installs via deep link)
- Every Apple Pay tap captures: **card name, merchant, amount, date**
- App progressively builds the user's card portfolio from real usage
- When a new card is detected: "You used DBS Live Fresh — added to your portfolio!"
- Minimal onboarding: just use Apple Pay normally and we learn

#### 2. Smart PKPass Wallet Passes
- App generates `.pkpass` files that live inside Apple Wallet
- Passes are organized by **spending category**:
  - 🍽️ Dining — "Use Citi Rewards (4x points)"
  - 🛒 Groceries — "Use OCBC 365 (5% cashback)"  
  - ⛽ Transport — "Use DBS Live Fresh (5% cashback)"
  - ✈️ Travel — "Use Citi PremierMiles (1.2 mpd)"
  - 🛍️ Online Shopping — "Use UOB One (10x points)"
  - 💳 Everything Else — "Use AMEX Gold (1.5x MR)"
- Passes update dynamically as new cards are detected
- **Location-aware**: passes auto-surface on lock screen near relevant merchants (geofencing)

#### 3. Post-Transaction Intelligence
- After each Apple Pay transaction, evaluate if the optimal card was used
- If wrong card: push notification — "You paid $45 at Din Tai Fung with DBS. Citi Rewards would've earned 4x points (saved ~$1.80)"
- Weekly digest: "You left $12.40 on the table this week"
- Monthly report: total optimized vs actual rewards earned

#### 4. Transaction Dashboard
- Simple list view of all Apple Pay transactions captured
- Per-transaction: merchant, amount, card used, optimal card, delta
- Monthly spending breakdown by category
- Per-card spending totals

### Technical Architecture

```
┌─────────────────────────────────────────────────┐
│                   iOS App                        │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │
│  │ Dashboard │  │ Cards    │  │ Settings      │  │
│  │ (SwiftUI)│  │ Portfolio │  │ + Onboarding  │  │
│  └────┬─────┘  └────┬─────┘  └───────┬───────┘  │
│       │              │                │          │
│  ┌────┴──────────────┴────────────────┴───────┐  │
│  │           Core Data / SwiftData            │  │
│  │  - Transactions                            │  │
│  │  - Cards (detected)                        │  │
│  │  - Card Rewards DB (bundled JSON)          │  │
│  └────────────────────┬───────────────────────┘  │
│                       │                          │
│  ┌────────────────────┴───────────────────────┐  │
│  │          Services Layer                     │  │
│  │  - TransactionIngestionService             │  │
│  │  - CardDetectionService                    │  │
│  │  - RewardOptimizationEngine                │  │
│  │  - PKPassGeneratorService                  │  │
│  │  - NotificationService                     │  │
│  │  - MerchantCategoryService                 │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
│  ┌────────────────────────────────────────────┐  │
│  │          iOS Integrations                   │  │
│  │  - Shortcuts App Intent (Transaction)       │  │
│  │  - PassKit (PKPass generation)             │  │
│  │  - CoreLocation (geofencing)               │  │
│  │  - UserNotifications                       │  │
│  │  - WidgetKit (lock screen widget)          │  │
│  └────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

### Data Model

```swift
// Transaction (captured from Shortcuts trigger)
struct Transaction {
    let id: UUID
    let merchantName: String
    let amount: Decimal
    let currency: String
    let cardName: String        // Raw card name from Apple Pay
    let cardId: UUID?           // Linked to detected card
    let category: MerchantCategory
    let optimalCardId: UUID?    // What they should've used
    let rewardsDelta: Decimal   // Missed rewards value
    let timestamp: Date
}

// Card (auto-detected from transactions)
struct Card {
    let id: UUID
    let name: String            // "DBS Live Fresh"
    let issuer: String          // "DBS"
    let matchedProductId: String? // Link to rewards DB
    let firstSeen: Date
    let transactionCount: Int
    let isActive: Bool
}

// CardProduct (bundled rewards database)
struct CardProduct {
    let id: String
    let name: String
    let issuer: String
    let country: String
    let rewards: [RewardTier]
    let annualFee: Decimal
    let cardType: CardType      // visa, mastercard, amex
}

struct RewardTier {
    let category: MerchantCategory
    let rate: Decimal           // e.g., 4.0 (4x points)
    let rateType: RateType      // points, cashback, miles
    let monthlyCap: Decimal?    // e.g., $800
    let minSpend: Decimal?      // e.g., $600/month
    let conditions: String?
}

enum MerchantCategory: String, CaseIterable {
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
    case general
}
```

### Rewards Database (MVP — Singapore)

Bundled as JSON, ~40-50 cards across:
- **DBS**: Live Fresh, Altitude, Woman's Card, Vantage, Takashimaya
- **OCBC**: 365, Frank, Titanium, Voyage, NTUC Plus!
- **UOB**: One, Lady's, PRVI Miles, Preferred Platinum
- **Citi**: Rewards, PremierMiles, Cash Back+, Prestige
- **HSBC**: Revolution, Visa Infinite
- **Amex**: True Cashback, KrisFlyer, CapitaCard
- **Standard Chartered**: Unlimited, Journey, Smart
- **Maybank**: Horizon, Family & Friends

### Card Name Matching

The Transaction Trigger returns raw card names like:
- "DBS Live Fresh Visa"  
- "OCBC 365"
- "Citibank Rewards Card"

Matching logic:
1. Fuzzy string match against known card names in rewards DB
2. Confidence threshold — if >80%, auto-match
3. If ambiguous, ask user: "Is this your Citi Rewards or Citi PremierMiles?"
4. Learn from corrections for future matching

### PKPass Structure

Each pass = one spending category recommendation:

```
┌─────────────────────────────────┐
│  🍽️  DINING                     │
│                                 │
│  Best Card: Citi Rewards        │
│  Earn: 4x Points               │
│                                 │
│  This month: $320 dining        │
│  Rewards earned: $12.80         │
│  ─────────────────────────────  │
│  CardWise                       │
│  Updated: Feb 8, 2026           │
└─────────────────────────────────┘
```

Passes include:
- `locations` array for geofencing (restaurant clusters, malls, supermarkets)
- `relevantDate` for time-based surfacing
- Dynamic updates via PassKit web service

### Onboarding Flow (3 screens)

```
Screen 1: "Never use the wrong card again"
  → Explain value prop: "We detect your cards and tell you 
     which one to use, right inside Apple Wallet"
  → [Get Started]

Screen 2: "Set up auto-detection"  
  → Guide user to add Transaction Trigger shortcut
  → Deep link or step-by-step with screenshots
  → "Just use Apple Pay normally — we'll learn your cards"
  → [Set Up Shortcut] / [I'll do this later]

Screen 3: "Add to your Wallet"
  → Install initial PKPasses (generic until cards are detected)
  → "These will update with personalized recommendations 
     as we learn your cards"
  → [Add to Wallet]

→ Done. App runs in background. 
  No manual card entry needed for MVP.
```

### Notifications

| Trigger | Message |
|---------|---------|
| New card detected | "Found a new card: DBS Live Fresh! We'll optimize recommendations." |
| Wrong card used | "You used DBS at Din Tai Fung. Citi Rewards would've earned 4x here." |
| Weekly digest | "This week: 12 transactions, $8.50 in missed rewards. See details." |
| Monthly report | "January report: $34 left on the table. Your most-used optimal card: Citi Rewards." |
| Cap warning | "You've hit $750/$800 on OCBC 365 groceries this month. 2 transactions to go." |

---

## Phase 2 — Card Database Browser + Manual Add

### Additional Features
- **Searchable card database**: Browse all cards by bank, type, category
- **Manual card add**: Search and tap to add cards you have
- **Card comparison**: Side-by-side reward comparison
- **"Cards you're missing"**: Recommend cards that would fill reward gaps
- **Spending optimization tips**: "If you got Card X, you'd save $Y/month"

---

## Phase 3 — Full Intelligence Layer

### Additional Features
- **Live Activities + Dynamic Island**: Real-time card recommendation based on location
- **Apple Watch complication**: Glanceable best-card-here
- **Open Banking integration** (SGFinDex / Finverse): Pull full transaction history across all cards (not just Apple Pay)
- **Smart category learning**: ML-based merchant → category mapping that improves over time
- **Spending insights**: Category trends, month-over-month, budget alerts
- **Multi-country support**: Expand rewards DB beyond Singapore
- **Card application affiliate**: Recommend new cards with referral links

---

## Tech Stack (MVP)

- **Language**: Swift 6
- **UI**: SwiftUI
- **Data**: SwiftData (on-device, privacy-first)
- **Passes**: PassKit framework + local `.pkpass` generation
- **Location**: CoreLocation (geofencing for pass surfacing)
- **Notifications**: UserNotifications
- **Shortcuts**: App Intents framework (for Transaction Trigger)
- **Min iOS**: 17.0 (Transaction Trigger requirement)
- **No backend needed for MVP** — everything on-device

---

## File Structure

```
CardWise/
├── CardWise.xcodeproj
├── CardWise/
│   ├── App/
│   │   ├── CardWiseApp.swift
│   │   └── ContentView.swift
│   ├── Models/
│   │   ├── Transaction.swift
│   │   ├── Card.swift
│   │   ├── CardProduct.swift
│   │   └── MerchantCategory.swift
│   ├── Services/
│   │   ├── TransactionIngestionService.swift
│   │   ├── CardDetectionService.swift
│   │   ├── RewardOptimizationEngine.swift
│   │   ├── PKPassGeneratorService.swift
│   │   ├── MerchantCategoryService.swift
│   │   └── NotificationService.swift
│   ├── Views/
│   │   ├── Onboarding/
│   │   │   ├── OnboardingView.swift
│   │   │   ├── ShortcutSetupView.swift
│   │   │   └── WalletPassSetupView.swift
│   │   ├── Dashboard/
│   │   │   ├── DashboardView.swift
│   │   │   ├── TransactionListView.swift
│   │   │   └── TransactionRowView.swift
│   │   ├── Cards/
│   │   │   ├── CardsView.swift
│   │   │   └── CardDetailView.swift
│   │   └── Reports/
│   │       ├── WeeklyReportView.swift
│   │       └── MonthlyReportView.swift
│   ├── Data/
│   │   └── sg_cards.json          // Singapore rewards database
│   ├── Intents/
│   │   └── TransactionIntent.swift // App Intent for Shortcuts
│   ├── Passes/
│   │   ├── PassGenerator.swift
│   │   └── pass_templates/
│   └── Resources/
│       └── Assets.xcassets
├── CardWiseTests/
├── CardWiseWidgetExtension/       // Lock screen widget (Phase 1.5)
└── README.md
```

---

## Success Metrics

- **Cards detected**: >90% auto-match rate within 2 weeks of use
- **Wrong card alerts**: User opens notification >40% of time
- **Monthly savings shown**: Average $30-50/month for 4+ card holders
- **Retention**: 60% weekly active after 1 month
- **Viral hook**: "I left $X on the table" shareable monthly report

---

## Competitive Advantage

| Feature | CardWise | CardPointers | MaxRewards |
|---------|----------|-------------|------------|
| Auto-detect cards | ✅ (Transaction Trigger) | ❌ Manual only | ❌ Manual |
| Wallet passes | ✅ | ✅ | ❌ |
| Wrong-card alerts | ✅ Real-time | ❌ | ❌ |
| "Money left on table" | ✅ | ❌ | Partial |
| Singapore cards | ✅ | ❌ (US only) | ❌ (US only) |
| On-device / private | ✅ | ✅ | ❌ |
| Free tier | ✅ MVP | ❌ $50/yr | ❌ $15/yr |

---

## Monetization (Future)

- **Free**: Auto-detect + 3 category passes + basic alerts
- **Pro ($4.99/mo)**: All categories, detailed reports, cap warnings, Live Activity
- **Affiliate**: Card application referrals ("You're missing out — get Card X")
- **Enterprise**: White-label for banks ("DBS Card Optimizer powered by CardWise")
