# CardWise — Product Plan

## One-Liner
One card in your Apple Wallet that tells you which credit card to use, right when you need it.

---

## The Concept

When you double-tap the side button to pay, you see one CardWise pass alongside your payment cards. It knows where you are and tells you:

> **🍽️ Din Tai Fung — Use Citi Rewards**
> **4x points on dining**

Walk into FairPrice:

> **🛒 FairPrice — Use OCBC 365**
> **5% cashback on groceries**

Standing at a petrol station:

> **⛽ Shell — Use DBS Live Fresh**
> **5% cashback on fuel**

One pass. Always relevant. Zero thinking.

---

## How It Works

### The Pass
- **Single PKPass** in Apple Wallet
- Updates dynamically based on GPS location
- Shows: merchant/location name, best card to use, reward rate, category icon
- Location-aware: pass auto-surfaces on lock screen when near merchants
- Beautiful, clean design — dark card with accent color matching the category

### The Intelligence
- **Transaction Trigger** (iOS 17+): automatically captures every Apple Pay transaction
- Learns which cards you have from your real usage
- Matches merchants to reward categories
- Calculates the optimal card per category from your portfolio
- Post-transaction alert if you used the wrong card

### The Onboarding (2 screens)
1. **"Never use the wrong card again"** — value prop, single CTA
2. **"Add to Wallet"** — installs the one CardWise pass + guides Shortcut setup

That's it. No tabs, no complex UI. The app is a thin shell — the product IS the Wallet pass.

---

## Architecture

```
┌─────────────────────────────────────┐
│         Apple Wallet                │
│                                     │
│  ┌───────────────────────────────┐  │
│  │ 💳 CardWise                   │  │
│  │                               │  │
│  │ 🍽️ Din Tai Fung              │  │
│  │ Use: Citi Rewards             │  │
│  │ Earn: 4x points              │  │
│  │                               │  │
│  │ Updated just now              │  │
│  └───────────────────────────────┘  │
│                                     │
│  [Citi Rewards ****4521]           │
│  [DBS Live Fresh ****8832]         │
│  [OCBC 365 ****1190]              │
└─────────────────────────────────────┘

        ↑ Pass updates via
        
┌─────────────────────────────────────┐
│         CardWise App                │
│                                     │
│  ┌─────────────┐ ┌──────────────┐  │
│  │ Location     │ │ Transaction  │  │
│  │ Service      │ │ Trigger      │  │
│  │ (CoreLoc)    │ │ (Shortcuts)  │  │
│  └──────┬──────┘ └──────┬───────┘  │
│         │               │          │
│  ┌──────┴───────────────┴───────┐  │
│  │     Recommendation Engine    │  │
│  │  merchant → category → card  │  │
│  └──────────────┬───────────────┘  │
│                 │                   │
│  ┌──────────────┴───────────────┐  │
│  │     Pass Update Service      │  │
│  │  (PassKit web service or     │  │
│  │   regenerate + re-add)       │  │
│  └──────────────────────────────┘  │
│                                     │
│  Data: SwiftData (on-device)       │
│  Cards DB: sg_cards.json           │
└─────────────────────────────────────┘
```

---

## Pass Design

### Visual Layout
```
┌─────────────────────────────────────┐
│                                     │
│  ⚡ CardWise              📍 Near  │
│                                     │
│  ┌─────────────────────────────┐    │
│  │  🍽️                        │    │
│  │  Din Tai Fung               │    │
│  │                             │    │
│  │  USE: Citi Rewards          │    │
│  │  EARN: 4x Points           │    │
│  └─────────────────────────────┘    │
│                                     │
│  Updated just now                   │
│                                     │
└─────────────────────────────────────┘
```

### Pass Fields
- **Header:** CardWise logo + "Near" indicator
- **Primary:** Location/merchant name (dynamic)
- **Secondary:** Best card name + earn rate
- **Auxiliary:** Category + last updated
- **Back:** Full card portfolio summary, link to app

### Color Scheme
- **Base:** Dark (#1C1C1E) — matches iOS dark mode
- **Accent:** Changes with category
  - Dining: Orange (#FF6B35)
  - Groceries: Green (#34C759)
  - Transport: Blue (#007AFF)
  - Travel: Purple (#AF52DE)
  - Shopping: Pink (#FF375F)
  - Fuel: Yellow (#FFCC00)
  - Default: Blue (#0A84FF)
- **Text:** White primary, white/70% secondary

---

## Dynamic Pass Updates

### Option A: Pass regeneration (MVP)
- App detects location change → determines best card
- Regenerates .pkpass with updated content
- Uses `PKPassLibrary.replacePass(with:)` to swap in Wallet
- Requires: pass signing on-device or pre-computed passes

### Option B: PassKit Web Service (Better, Phase 2)
- Register a web service URL in the pass
- Apple Wallet polls for updates automatically
- Server pushes updates via APNs when location changes
- Requires: backend server (could be a simple CloudFlare Worker)

### Option C: Notification-based (MVP companion)
- Location change triggers a push notification
- "You're at Din Tai Fung — use Citi Rewards (4x points)"
- Works alongside static pass as a backup

### MVP Recommendation
Start with **Option A + C**: regenerate pass on location change + send notification. No backend needed. Everything on-device.

---

## App UI (Minimal)

The app is NOT the product. The Wallet pass is. The app exists for:
1. Onboarding (add pass + set up shortcut)
2. Viewing transaction history and savings
3. Managing card portfolio (auto-detected)

### Screens

**Onboarding (first launch only):**
- Screen 1: Value prop → "One card to rule them all"
- Screen 2: Add to Wallet + Shortcut setup

**Main App (after onboarding):**
- Single scrollable home screen:
  - Current recommendation (mirrors the Wallet pass)
  - "$ left on the table this month" stat
  - Recent transactions (last 5)
  - Detected cards list
  - "Set up Shortcut" prompt if not done yet

No tabs. No navigation complexity. One screen.

---

## Data Model

### Transaction
- id, merchantName, amount, currency
- cardName (raw from Apple Pay)
- category (auto-detected)
- optimalCardName, rewardsDelta
- timestamp

### Card (auto-detected)
- id, name, issuer
- matchedProductId (link to rewards DB)
- firstSeen, transactionCount

### CardProduct (bundled JSON)
- id, name, issuer, country
- rewards: [{ category, rate, rateType, monthlyCap, minSpend }]

---

## Singapore Card Database (MVP)

~40 cards across: DBS, OCBC, UOB, Citi, HSBC, Amex, Standard Chartered, Maybank, CIMB, POSB, BOC

Already built in `sg_cards.json`.

---

## Merchant Category Matching

200+ Singapore merchant keywords already built. Maps:
- "Din Tai Fung", "McDonald's", "Hai Di Lao" → Dining
- "FairPrice", "Cold Storage", "Sheng Siong" → Groceries
- "Grab", "ComfortDelGro", "Gojek" → Transport
- "Shell", "SPC", "Esso" → Fuel
- "Lazada", "Shopee", "Amazon" → Online Shopping
- etc.

Fallback: MCC code matching (future enhancement with transaction data).

---

## Development Phases

### Phase 1 — MVP (Current Sprint)
- [ ] Single beautiful PKPass (dark theme, location-aware)
- [ ] Clean 2-screen onboarding
- [ ] Single home screen (no tabs)
- [ ] Transaction Trigger integration
- [ ] Auto card detection from Apple Pay
- [ ] Reward optimization engine
- [ ] Post-transaction wrong-card notification
- [ ] "Money left on table" stat
- [ ] Singapore card database (40 cards)
- [ ] Merchant category matching (200+ merchants)

### Phase 2 — Dynamic Pass
- [ ] CoreLocation background tracking
- [ ] Pass regeneration on location change (PKPassLibrary.replacePass)
- [ ] Pass content updates based on detected location
- [ ] Apple Maps / Google Places integration for merchant identification
- [ ] Monthly cap tracking per card

### Phase 3 — Intelligence
- [ ] Live Activity on Dynamic Island (location-aware recommendation)
- [ ] Apple Watch complication
- [ ] Weekly/monthly savings report (shareable)
- [ ] "Cards you're missing" recommendations
- [ ] Card comparison tool
- [ ] Siri: "CardWise here" / "CardWise for Starbucks"

### Phase 4 — Growth
- [ ] PassKit web service for push-based pass updates
- [ ] Multi-country support (start: SG, MY, HK)
- [ ] Open Banking integration (SGFinDex)
- [ ] Card application affiliate links
- [ ] Social sharing ("I saved $X this month with CardWise")

---

## Tech Stack
- **Swift 6, SwiftUI, SwiftData**
- **iOS 17.0+** (Transaction Trigger requirement)
- **PassKit** (PKPass, PKPassLibrary, PKAddPassesViewController)
- **CoreLocation** (geofencing, background location)
- **App Intents** (Shortcuts integration)
- **UserNotifications** (wrong-card alerts)
- **No backend** (Phase 1-2), simple API (Phase 3+)

---

## Success Metrics
- Pass added to Wallet: >90% of installs
- Auto-detected cards: >3 within first week
- Wrong card alerts opened: >40%
- Monthly "money saved" awareness: >$30 average shown
- 7-day retention: >60%

---

## Competitive Edge
- **CardPointers** (US only, $50/yr, no auto-detect, multiple passes)
- **CardWise** (SG-first, free MVP, auto-detect, ONE pass, location-aware)

The single-pass UX is the differentiator. CardPointers clutters your Wallet with category passes. We give you one intelligent card that knows where you are.

---

*Last updated: Feb 8, 2026*
