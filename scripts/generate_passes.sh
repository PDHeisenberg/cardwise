#!/bin/bash
#
# generate_passes.sh — Generate and sign the SINGLE CardWise .pkpass
#
# Usage: ./scripts/generate_passes.sh [certs_dir]
#
# Requires: openssl, python3 (for image generation), zip
# Certs directory should contain: pass.pem, pass.key, wwdr.pem

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CERTS_DIR="${1:-$HOME/Coding/cardwise/certs}"
OUTPUT_DIR="$PROJECT_DIR/CardWise/Resources/Passes"
TEMP_DIR=$(mktemp -d)

# Validate certs
for f in pass.pem pass.key wwdr.pem; do
    if [ ! -f "$CERTS_DIR/$f" ]; then
        echo "❌ Missing $f in $CERTS_DIR"
        exit 1
    fi
done

echo "📋 Using certs from: $CERTS_DIR"
echo "📦 Output dir: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Clean old passes
rm -f "$OUTPUT_DIR"/*.pkpass

echo ""
echo "🔧 Generating single CardWise pass"

PASS_DIR="$TEMP_DIR/cardwise.pass"
mkdir -p "$PASS_DIR"

SERIAL="cardwise-main-v1"
TODAY=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Create pass.json — ONE beautiful pass
cat > "$PASS_DIR/pass.json" << EOF
{
    "formatVersion": 1,
    "passTypeIdentifier": "pass.com.cardwise",
    "serialNumber": "$SERIAL",
    "teamIdentifier": "62378C2F99",
    "organizationName": "CardWise",
    "description": "CardWise - Smart Card Recommendation",
    "foregroundColor": "rgb(255, 255, 255)",
    "backgroundColor": "rgb(28, 28, 30)",
    "labelColor": "rgb(174, 174, 178)",
    "logoText": "CardWise",
    "generic": {
        "primaryFields": [
            {
                "key": "recommendation",
                "label": "BEST CARD",
                "value": "Use Citi Rewards"
            }
        ],
        "secondaryFields": [
            {
                "key": "category",
                "label": "CATEGORY",
                "value": "🍽️ Dining"
            },
            {
                "key": "earn-rate",
                "label": "EARN RATE",
                "value": "4x Points"
            }
        ],
        "auxiliaryFields": [
            {
                "key": "cta",
                "label": "",
                "value": "Tap to open CardWise for details"
            }
        ],
        "backFields": [
            {
                "key": "portfolio-title",
                "label": "Your Card Portfolio",
                "value": "CardWise recommends the best credit card for every purchase based on your spending category and location."
            },
            {
                "key": "dining-rec",
                "label": "🍽️ Dining",
                "value": "Best: Citi Rewards — 4x Points\nRestaurants, cafes, food delivery"
            },
            {
                "key": "groceries-rec",
                "label": "🛒 Groceries",
                "value": "Best: OCBC 365 — 5% Cashback\nSupermarkets, grocery stores"
            },
            {
                "key": "transport-rec",
                "label": "🚌 Transport",
                "value": "Best: DBS Live Fresh — 5% Cashback\nGrab, taxis, public transit"
            },
            {
                "key": "travel-rec",
                "label": "✈️ Travel",
                "value": "Best: Citi PremierMiles — 1.2 mpd\nFlights, hotels, travel bookings"
            },
            {
                "key": "online-rec",
                "label": "🛍️ Online Shopping",
                "value": "Best: UOB One — 5% Cashback\nLazada, Shopee, Amazon"
            },
            {
                "key": "fuel-rec",
                "label": "⛽ Fuel",
                "value": "Best: DBS Esso — 21.3% Savings\nPetrol stations"
            },
            {
                "key": "app-link",
                "label": "Open CardWise",
                "value": "cardwise://home",
                "dataDetectorTypes": ["PKDataDetectorTypeLink"]
            },
            {
                "key": "updated",
                "label": "Last Updated",
                "value": "$TODAY"
            }
        ]
    },
    "locations": [
        {
            "latitude": 1.3048,
            "longitude": 103.8318,
            "relevantText": "🍽️ Near Orchard — Check your best dining card"
        },
        {
            "latitude": 1.2834,
            "longitude": 103.8441,
            "relevantText": "🍽️ Near Chinatown — Use your best card"
        },
        {
            "latitude": 1.2917,
            "longitude": 103.8463,
            "relevantText": "🍽️ Clarke Quay — Check CardWise"
        },
        {
            "latitude": 1.3000,
            "longitude": 103.8378,
            "relevantText": "🛒 Near grocery stores — Check your best card"
        },
        {
            "latitude": 1.3521,
            "longitude": 103.8198,
            "relevantText": "📍 CardWise recommendation nearby"
        },
        {
            "latitude": 1.2830,
            "longitude": 103.8585,
            "relevantText": "🍽️ Marina Bay — Check your best dining card"
        },
        {
            "latitude": 1.3110,
            "longitude": 103.8370,
            "relevantText": "🍽️ Somerset — Use your best card"
        },
        {
            "latitude": 1.3150,
            "longitude": 103.8546,
            "relevantText": "🛒 Bugis — Check your best card"
        },
        {
            "latitude": 1.3329,
            "longitude": 103.7405,
            "relevantText": "🛒 Jurong East — Check CardWise"
        },
        {
            "latitude": 1.3500,
            "longitude": 103.8722,
            "relevantText": "🍽️ Serangoon — Use your best dining card"
        }
    ],
    "relevantDate": "$TODAY",
    "barcodes": [
        {
            "format": "PKBarcodeFormatQR",
            "message": "cardwise://home",
            "messageEncoding": "iso-8859-1"
        }
    ]
}
EOF

# Generate icon images (dark background with subtle blue accent)
generate_icon() {
    local size=$1 output=$2
    python3 - "$size" "$output" << 'PYTHON_SCRIPT'
import sys, struct, zlib

size = int(sys.argv[1])
output = sys.argv[2]

# Dark background matching pass: #1C1C1E
r, g, b = 28, 28, 30

def create_png(width, height, r, g, b):
    def make_chunk(chunk_type, data):
        chunk = chunk_type + data
        crc = struct.pack('>I', zlib.crc32(chunk) & 0xffffffff)
        return struct.pack('>I', len(data)) + chunk + crc

    sig = b'\x89PNG\r\n\x1a\n'
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    ihdr = make_chunk(b'IHDR', ihdr_data)

    raw_data = b''
    center = size // 2
    radius = size // 3

    for y in range(height):
        raw_data += b'\x00'
        for x in range(width):
            # Simple circle with blue accent in center
            dist = ((x - center) ** 2 + (y - center) ** 2) ** 0.5
            if dist < radius:
                # Blue accent (#0A84FF)
                factor = 1.0 - (dist / radius) * 0.3
                pr = max(0, min(255, int(10 * factor)))
                pg = max(0, min(255, int(132 * factor)))
                pb = max(0, min(255, int(255 * factor)))
            else:
                pr, pg, pb = r, g, b
            raw_data += bytes([pr, pg, pb])

    compressed = zlib.compress(raw_data)
    idat = make_chunk(b'IDAT', compressed)
    iend = make_chunk(b'IEND', b'')

    with open(output, 'wb') as f:
        f.write(sig + ihdr + idat + iend)

create_png(size, size, r, g, b)
PYTHON_SCRIPT
}

# Generate logo images
generate_logo() {
    local size=$1 output=$2
    python3 - "$size" "$output" << 'PYTHON_SCRIPT'
import sys, struct, zlib

size = int(sys.argv[1])
output = sys.argv[2]

# Dark background
r, g, b = 28, 28, 30

def create_png(width, height, r, g, b):
    def make_chunk(chunk_type, data):
        chunk = chunk_type + data
        crc = struct.pack('>I', zlib.crc32(chunk) & 0xffffffff)
        return struct.pack('>I', len(data)) + chunk + crc

    sig = b'\x89PNG\r\n\x1a\n'
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    ihdr = make_chunk(b'IHDR', ihdr_data)

    raw_data = b''
    for y in range(height):
        raw_data += b'\x00'
        for x in range(width):
            raw_data += bytes([r, g, b])

    compressed = zlib.compress(raw_data)
    idat = make_chunk(b'IDAT', compressed)
    iend = make_chunk(b'IEND', b'')

    with open(output, 'wb') as f:
        f.write(sig + ihdr + idat + iend)

create_png(width, height, r, g, b)
PYTHON_SCRIPT
}

echo "  📷 Generating images..."
generate_icon 29 "$PASS_DIR/icon.png"
generate_icon 58 "$PASS_DIR/icon@2x.png"
generate_icon 87 "$PASS_DIR/icon@3x.png"
generate_logo 160 "$PASS_DIR/logo.png"
generate_logo 320 "$PASS_DIR/logo@2x.png"

# Create manifest.json
echo "  📝 Creating manifest..."
cd "$PASS_DIR"
MANIFEST="{"
FIRST=true
for file in $(find . -type f -not -name 'manifest.json' -not -name 'signature' | sort); do
    filename="${file#./}"
    hash=$(openssl sha1 "$filename" | awk '{print $NF}')
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        MANIFEST="$MANIFEST,"
    fi
    MANIFEST="$MANIFEST\"$filename\":\"$hash\""
done
MANIFEST="$MANIFEST}"
echo "$MANIFEST" | python3 -m json.tool > manifest.json

# Sign the manifest
echo "  🔏 Signing pass..."
openssl smime \
    -binary \
    -sign \
    -certfile "$CERTS_DIR/wwdr.pem" \
    -signer "$CERTS_DIR/pass.pem" \
    -inkey "$CERTS_DIR/pass.key" \
    -in manifest.json \
    -out signature \
    -outform DER

# Create .pkpass
echo "  📦 Creating cardwise.pkpass..."
PASS_FILE="$OUTPUT_DIR/cardwise.pkpass"
rm -f "$PASS_FILE"
zip -q -r "$PASS_FILE" .
cd "$PROJECT_DIR"

# Verify
PASS_SIZE=$(wc -c < "$PASS_FILE" | tr -d ' ')
echo "  ✅ Created cardwise.pkpass ($PASS_SIZE bytes)"

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "🎉 Single CardWise pass generated: $OUTPUT_DIR/cardwise.pkpass"
ls -la "$OUTPUT_DIR"/*.pkpass
echo ""
echo "Next steps:"
echo "  1. The .pkpass is in the Xcode project Resources"
echo "  2. Build and run the app"
echo "  3. Onboarding will present the single Wallet pass"
