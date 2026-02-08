# CardWise — Credit Card Optimizer for Singapore

> Never use the wrong credit card again. CardWise auto-detects your cards from Apple Pay and tells you which one to use — right inside Apple Wallet.

![iOS 17+](https://img.shields.io/badge/iOS-17.0+-blue.svg)
![Swift 5.9+](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-green.svg)
![SwiftData](https://img.shields.io/badge/SwiftData-✓-purple.svg)

## What It Does

Most people carry 3-6 credit cards but always tap the same default card. Each card has different reward categories (dining 4x, groceries 5%, transport 3x). **You're leaving $30-50/month in rewards on the table** simply because you don't remember which card is best where.

CardWise fixes this by:

1. **Auto-detecting your card portfolio** from Apple Pay transactions (via iOS Shortcuts Transaction Trigger)
2. **Recommending the optimal card** for each spending category via Apple Wallet passes
3. **Alerting you in real-time** when you use the wrong card ("You paid $45 at Din Tai Fung with DBS. Citi Rewards would've earned 4x points!")
4. **Showing you exactly how much you're missing** with weekly/monthly "You left $X on the table" reports

### 🇸🇬 Built for Singapore

Includes an accurate rewards database of **35+ Singapore credit cards** from DBS, OCBC, UOB, Citi, HSBC, AMEX, Standard Chartered, Maybank, CIMB, POSB, and BOC with real cashback/miles/points rates.

## How to Build

### Prerequisites
- Xcode 15.0 or later
- iOS 17.0+ target device or simulator
- Apple Developer account (for App Intents and PassKit)

### Steps

1. **Clone the repo:**
   ```bash
   git clone <repo-url>
   cd cardwise
   ```

2. **Open in Xcode:**
   ```bash
   open CardWise.xcodeproj
   ```

3. **Set your development team:**
   - Select the `CardWise` target
   - Go to Signing & Capabilities
   - Select your Apple Developer Team
   - Change the Bundle Identifier to something unique (e.g., `com.yourname.cardwise`)

4. **Build and run:**
   - Select your target device/simulator (iPhone with iOS 17+)
   - Press `Cmd+R` to build and run

5. **Set up the Shortcut** (see below)

## Setting Up the iOS Shortcut (Transaction Trigger)

This is how CardWise automatically captures your Apple Pay transactions. The Transaction Trigger automation in iOS Shortcuts fires every time you complete an Apple Pay payment.

### Step-by-Step:

1. **Open the Shortcuts app** on your iPhone

2. **Go to the Automation tab** (bottom bar)

3. **Create a new Personal Automation:**
   - Tap the `+` button in the top-right
   - Scroll down and select **Transaction**
   - This trigger fires after every Apple Pay transaction

4. **Add the CardWise action:**
   - Tap "New Blank Automation"
   - Tap "Add Action"
   - Search for **"Log Transaction"** (this is the CardWise App Intent)
   - Select it

5. **Wire the parameters:**
   - **Merchant Name** → tap the field → select **"Merchant"** from Shortcut Input
   - **Amount** → tap the field → select **"Amount"** from Shortcut Input
   - **Card Name** → tap the field → select **"Card/Pass Name"** from Shortcut Input

6. **Configure the automation:**
   - Toggle **"Run Immediately"** to ON
   - Disable **"Notify When Run"** (for seamless background operation)
   - Tap **Done**

7. **That's it!** Every Apple Pay transaction will now be automatically logged, categorized, and analyzed.

### What Gets Captured:
- Merchant name (e.g., "Din Tai Fung")
- Transaction amount (e.g., $45.80)
- Card/pass name (e.g., "DBS Live Fresh Visa")
- Timestamp

### Privacy:
- ✅ All data stays on your device
- ✅ No data is sent to any server
- ✅ Uses SwiftData for on-device storage
- ✅ No analytics or tracking

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                   CardWise iOS App                   │
│                                                     │
│  ┌───────────────────────────────────────────────┐  │
│  │              SwiftUI Views                     │  │
│  │  OnboardingView → DashboardView                │  │
│  │  TransactionListView · CardsView · ReportView  │  │
│  └─────────────────────┬─────────────────────────┘  │
│                        │                            │
│  ┌─────────────────────┴─────────────────────────┐  │
│  │             Services Layer                     │  │
│  │  TransactionIngestionService (pipeline)        │  │
│  │  ├── MerchantCategoryService (categorize)      │  │
│  │  ├── CardDetectionService (fuzzy match)        │  │
│  │  ├── RewardOptimizationEngine (find best)      │  │
│  │  ├── NotificationService (alerts)              │  │
│  │  └── PKPassGeneratorService (wallet passes)    │  │
│  └─────────────────────┬─────────────────────────┘  │
│                        │                            │
│  ┌─────────────────────┴─────────────────────────┐  │
│  │             Data Layer                         │  │
│  │  SwiftData: Transaction, Card                  │  │
│  │  Bundled JSON: sg_cards.json (35+ SG cards)    │  │
│  └───────────────────────────────────────────────┘  │
│                                                     │
│  ┌───────────────────────────────────────────────┐  │
│  │          iOS Integrations                      │  │
│  │  App Intents (Shortcuts Transaction Trigger)   │  │
│  │  PassKit · UserNotifications · CoreLocation    │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

### Key Components:

| Component | Purpose |
|-----------|---------|
| **TransactionIngestionService** | Main pipeline: receives transaction → categorizes → matches card → optimizes → stores → notifies |
| **MerchantCategoryService** | Maps merchant names to spending categories using 200+ Singapore-specific keywords |
| **CardDetectionService** | Fuzzy-matches raw Apple Pay card names (e.g., "DBS Live Fresh Visa") to the rewards database |
| **RewardOptimizationEngine** | Ranks all user's cards for a given category and calculates the rewards delta |
| **PKPassGeneratorService** | Generates Apple Wallet `.pkpass` bundles showing best card per category |
| **NotificationService** | Sends wrong-card alerts, new card detection, weekly digests, cap warnings |
| **sg_cards.json** | Comprehensive database of 35+ Singapore credit cards with real reward tiers, rates, caps |

### Transaction Flow:

```
Apple Pay Tap
    → iOS Shortcuts Transaction Trigger
    → LogTransactionIntent (App Intent)
    → TransactionIngestionService.ingestTransaction()
        1. MerchantCategoryService.categorize("Din Tai Fung") → .dining
        2. CardDetectionService.detectAndSaveCard("DBS Live Fresh Visa") → matched!
        3. RewardOptimizationEngine.findOptimalCard(.dining, userCards) → Citi Rewards 4x
        4. Calculate delta: optimal $1.83 - actual $0.14 = $1.69 missed
        5. Store Transaction in SwiftData
        6. NotificationService.sendWrongCardAlert() → 💳 push notification
```

## Project Structure

```
CardWise/
├── CardWise.xcodeproj/
├── CardWise/
│   ├── App/
│   │   ├── CardWiseApp.swift          # Entry point, SwiftData container setup
│   │   └── ContentView.swift          # Root view + tab navigation
│   ├── Models/
│   │   ├── Transaction.swift          # SwiftData model for transactions
│   │   ├── Card.swift                 # SwiftData model for detected cards
│   │   ├── CardProduct.swift          # Codable model + CardDatabase loader
│   │   └── MerchantCategory.swift     # Spending category enum
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
│   │       └── ReportView.swift
│   ├── Data/
│   │   └── sg_cards.json              # Singapore card rewards database
│   ├── Intents/
│   │   └── TransactionIntent.swift    # App Intents for Shortcuts
│   ├── Resources/
│   │   └── Assets.xcassets
│   └── Info.plist
├── SPEC.md                             # Full product specification
└── README.md                           # This file
```

## Singapore Card Database

The `sg_cards.json` database includes **35+ cards** with accurate reward tiers:

| Issuer | Cards | Notable Rates |
|--------|-------|---------------|
| **DBS** | Live Fresh, Altitude, Woman's World, yuu, Takashimaya, Vantage | 6% shopping, 4 mpd online, 5% groceries |
| **OCBC** | 365, FRANK, Titanium, Voyage | 6% fuel, 5% dining, 8% online |
| **UOB** | One, Preferred Platinum, PRVI Miles, Visa Signature, Lady's Solitaire | 10% cashback, 4 mpd contactless |
| **Citi** | Rewards, PremierMiles, Cash Back+, Cash Back, SMRT, Prestige | 4 mpd online, 8% fuel, 1.6% flat |
| **HSBC** | Revolution, Live+, Advance, TravelOne, Visa Infinite | 4 mpd contactless, 8% dining |
| **AMEX** | True Cashback, KrisFlyer, KrisFlyer Ascend | 3% everything, 2 mpd SIA |
| **Standard Chartered** | Simply Cash, Unlimited, Journey, Smart | 1.5% flat unlimited |
| **Maybank** | Horizon Visa Signature, Family & Friends, XL Rewards | 2.8 mpd overseas, 8% chosen categories |
| **Others** | CIMB Visa Signature, POSB Everyday, BOC Elite Miles, KrisFlyer UOB | 10% online, 5% groceries, 2.8 mpd |

## Tech Stack

- **Swift 5.9+** / SwiftUI
- **SwiftData** (on-device persistence)
- **App Intents** (Shortcuts integration)
- **PassKit** (Apple Wallet passes)
- **UserNotifications** (wrong-card alerts)
- **Observation** framework

## License

MIT

