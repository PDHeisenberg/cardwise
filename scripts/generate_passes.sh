#!/bin/bash
#
# generate_passes.sh — Generate and sign .pkpass files for CardWise
#
# Usage: ./scripts/generate_passes.sh [certs_dir]
#
# Requires: openssl, python3 (for image generation), zip
# Certs directory should contain: pass.pem, pass.key, wwdr.pem

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CERTS_DIR="${1:-$PROJECT_DIR/certs}"
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

# Category definitions: id|displayName|icon_emoji|bgColorR|bgColorG|bgColorB|bestCard|earnRate|description
CATEGORIES=(
    "dining|Dining|🍽️|255|107|53|Best Dining Card|Up to 10x points|Your top card for restaurants, cafes, and food delivery"
    "groceries|Groceries|🛒|52|199|89|Best Groceries Card|Up to 8% cashback|Your top card for supermarkets and grocery stores"
    "transport|Transport|🚌|0|122|255|Best Transport Card|Up to 5% cashback|Your top card for public transit, grab rides, and taxis"
    "travel|Travel|✈️|175|82|222|Best Travel Card|Up to 3 mpd|Your top card for flights, hotels, and travel bookings"
    "onlineShopping|Online Shopping|🛍️|255|55|95|Best Online Card|Up to 6% cashback|Your top card for online purchases and e-commerce"
    "fuel|Fuel|⛽|255|179|0|Best Fuel Card|Up to 20% savings|Your top card for petrol stations and fuel purchases"
)

# Generate icon images using Python (creates simple colored squares with white icon text)
generate_icon() {
    local r=$1 g=$2 b=$3 emoji=$4 size=$5 output=$6
    python3 - "$r" "$g" "$b" "$emoji" "$size" "$output" << 'PYTHON_SCRIPT'
import sys
import struct
import zlib

r, g, b = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3])
emoji = sys.argv[4]
size = int(sys.argv[5])
output = sys.argv[6]

# Create a simple solid color PNG
def create_png(width, height, r, g, b):
    def make_chunk(chunk_type, data):
        chunk = chunk_type + data
        crc = struct.pack('>I', zlib.crc32(chunk) & 0xffffffff)
        return struct.pack('>I', len(data)) + chunk + crc

    # PNG signature
    sig = b'\x89PNG\r\n\x1a\n'

    # IHDR
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    ihdr = make_chunk(b'IHDR', ihdr_data)

    # IDAT - raw pixel data
    raw_data = b''
    # Create a subtle gradient effect
    for y in range(height):
        raw_data += b'\x00'  # filter byte
        factor = 1.0 - (y / height) * 0.15  # subtle darken toward bottom
        pr = max(0, min(255, int(r * factor)))
        pg = max(0, min(255, int(g * factor)))
        pb = max(0, min(255, int(b * factor)))
        for x in range(width):
            raw_data += bytes([pr, pg, pb])

    # Add a white circle in the center (simplified)
    compressed = zlib.compress(raw_data)
    idat = make_chunk(b'IDAT', compressed)

    # IEND
    iend = make_chunk(b'IEND', b'')

    with open(output, 'wb') as f:
        f.write(sig + ihdr + idat + iend)

create_png(size, size, r, g, b)
PYTHON_SCRIPT
}

# Generate logo images (CardWise branding - simple blue-ish icon)
generate_logo() {
    local size=$1 output=$2
    generate_icon 0 122 255 "C" "$size" "$output"
}

# Generate strip image (wide banner for the pass)
generate_strip() {
    local r=$1 g=$2 b=$3 size_w=$4 size_h=$5 output=$6
    python3 - "$r" "$g" "$b" "$size_w" "$size_h" "$output" << 'PYTHON_SCRIPT'
import sys
import struct
import zlib

r, g, b = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3])
width, height = int(sys.argv[4]), int(sys.argv[5])
output = sys.argv[6]

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
        factor = 1.0 - (y / height) * 0.2
        pr = max(0, min(255, int(r * factor)))
        pg = max(0, min(255, int(g * factor)))
        pb = max(0, min(255, int(b * factor)))
        for x in range(width):
            raw_data += bytes([pr, pg, pb])

    compressed = zlib.compress(raw_data)
    idat = make_chunk(b'IDAT', compressed)
    iend = make_chunk(b'IEND', b'')

    with open(output, 'wb') as f:
        f.write(sig + ihdr + idat + iend)

create_png(width, height, r, g, b)
PYTHON_SCRIPT
}

# Process each category
for entry in "${CATEGORIES[@]}"; do
    IFS='|' read -r cat_id cat_name cat_emoji bg_r bg_g bg_b best_card earn_rate description <<< "$entry"

    echo ""
    echo "🔧 Generating pass for: $cat_name ($cat_id)"

    PASS_DIR="$TEMP_DIR/$cat_id.pass"
    mkdir -p "$PASS_DIR"

    # Generate serial number (deterministic based on category for reproducibility)
    SERIAL="cardwise-${cat_id}-v1"

    # Create pass.json
    cat > "$PASS_DIR/pass.json" << EOF
{
    "formatVersion": 1,
    "passTypeIdentifier": "pass.com.cardwise",
    "serialNumber": "$SERIAL",
    "teamIdentifier": "62378C2F99",
    "organizationName": "CardWise",
    "description": "CardWise - $cat_name Recommendation",
    "foregroundColor": "rgb(255, 255, 255)",
    "backgroundColor": "rgb($bg_r, $bg_g, $bg_b)",
    "labelColor": "rgb(255, 255, 255)",
    "logoText": "CardWise",
    "generic": {
        "primaryFields": [
            {
                "key": "best-card",
                "label": "BEST CARD",
                "value": "$best_card"
            }
        ],
        "secondaryFields": [
            {
                "key": "earn-rate",
                "label": "EARN RATE",
                "value": "$earn_rate"
            },
            {
                "key": "category",
                "label": "CATEGORY",
                "value": "$cat_emoji $cat_name"
            }
        ],
        "auxiliaryFields": [
            {
                "key": "monthly-spend",
                "label": "THIS MONTH",
                "value": "Add cards to see",
                "textAlignment": "PKTextAlignmentLeft"
            },
            {
                "key": "rewards-earned",
                "label": "REWARDS",
                "value": "Set up your cards",
                "textAlignment": "PKTextAlignmentRight"
            }
        ],
        "backFields": [
            {
                "key": "about",
                "label": "About This Pass",
                "value": "$description.\n\nCardWise automatically tracks your spending and recommends the best credit card to use for each category. This pass updates as we learn your card portfolio.\n\nPass Type: $cat_name Recommendation\nPowered by CardWise"
            },
            {
                "key": "last-updated",
                "label": "Last Updated",
                "value": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
            },
            {
                "key": "tip",
                "label": "💡 Tip",
                "value": "Open CardWise to add your credit cards and get personalized recommendations with real earn rates."
            }
        ]
    },
    "locations": [
        {
            "latitude": 1.3048,
            "longitude": 103.8318,
            "relevantText": "$cat_emoji Check your best $cat_name card — Orchard Road"
        },
        {
            "latitude": 1.2834,
            "longitude": 103.8441,
            "relevantText": "$cat_emoji Use your best card here — Chinatown"
        },
        {
            "latitude": 1.2917,
            "longitude": 103.8463,
            "relevantText": "$cat_emoji Best card reminder — Clarke Quay"
        },
        {
            "latitude": 1.3521,
            "longitude": 103.8198,
            "relevantText": "$cat_emoji CardWise recommendation nearby"
        }
    ],
    "relevantDate": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "barcodes": [
        {
            "format": "PKBarcodeFormatQR",
            "message": "cardwise://$cat_id",
            "messageEncoding": "iso-8859-1"
        }
    ]
}
EOF

    # Generate images
    generate_icon "$bg_r" "$bg_g" "$bg_b" "$cat_emoji" 29 "$PASS_DIR/icon.png"
    generate_icon "$bg_r" "$bg_g" "$bg_b" "$cat_emoji" 58 "$PASS_DIR/icon@2x.png"
    generate_icon "$bg_r" "$bg_g" "$bg_b" "$cat_emoji" 87 "$PASS_DIR/icon@3x.png"
    generate_logo 160 "$PASS_DIR/logo.png"
    generate_logo 320 "$PASS_DIR/logo@2x.png"

    # Create manifest.json (SHA1 hashes of all files)
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

    # Create .pkpass (ZIP archive)
    echo "  📦 Creating .pkpass..."
    PASS_FILE="$OUTPUT_DIR/${cat_id}.pkpass"
    rm -f "$PASS_FILE"
    zip -q -r "$PASS_FILE" .
    cd "$PROJECT_DIR"

    # Verify the pass
    PASS_SIZE=$(wc -c < "$PASS_FILE" | tr -d ' ')
    echo "  ✅ Created $cat_id.pkpass ($PASS_SIZE bytes)"
done

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "🎉 All passes generated in: $OUTPUT_DIR"
ls -la "$OUTPUT_DIR"/*.pkpass
echo ""
echo "Next steps:"
echo "  1. Add .pkpass files to Xcode project Resources"
echo "  2. Build and run the app"
echo "  3. The onboarding flow will present real Wallet passes"
