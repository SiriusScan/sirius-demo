#!/bin/bash

# seed_demo.sh - Seed demo data into SiriusScan API
# Usage: ./seed_demo.sh <api_url> [api_key]

set -e

API_URL="${1:-http://localhost:9001}"
API_KEY="${2:-${SIRIUS_API_KEY:-}}"

if [ -z "$API_KEY" ]; then
    echo "Warning: No API key provided. Authenticated endpoints will fail."
    echo "Usage: $0 <api_url> <api_key>"
fi
FIXTURES_DIR="$(dirname "$0")/../fixtures"
INDEX_FILE="$FIXTURES_DIR/index.json"
LOG_FILE="/var/log/sirius/seed-demo.log"

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Log to both file and console
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "========================================="
echo "SiriusScan Demo Data Seeding"
echo "Started at: $(date)"
echo "========================================="
echo "API URL: $API_URL"
echo "Fixtures directory: $FIXTURES_DIR"
echo ""

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "❌ Error: jq is not installed"
    echo "Install with: apt-get install jq"
    exit 1
fi

# Check if index file exists
if [ ! -f "$INDEX_FILE" ]; then
    echo "❌ Error: Fixture index not found: $INDEX_FILE"
    exit 1
fi

# Read fixture list from index
FIXTURE_COUNT=$(jq '.fixtures | length' "$INDEX_FILE")
echo "📊 Found $FIXTURE_COUNT fixtures to load"
echo ""

SUCCESS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# Iterate through fixtures
for i in $(seq 0 $((FIXTURE_COUNT - 1))); do
    FIXTURE_FILE=$(jq -r ".fixtures[$i].file" "$INDEX_FILE")
    DESCRIPTION=$(jq -r ".fixtures[$i].description" "$INDEX_FILE")
    PRIORITY=$(jq -r ".fixtures[$i].priority" "$INDEX_FILE")
    
    FIXTURE_PATH="$FIXTURES_DIR/$FIXTURE_FILE"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "[$((i + 1))/$FIXTURE_COUNT] Loading: $DESCRIPTION"
    echo "File: $FIXTURE_FILE (Priority: $PRIORITY)"
    
    # Check if fixture file exists
    if [ ! -f "$FIXTURE_PATH" ]; then
        echo "⚠️  Fixture file not found: $FIXTURE_PATH"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        continue
    fi
    
    # Validate JSON syntax
    if ! jq empty "$FIXTURE_PATH" 2>/dev/null; then
        echo "❌ Invalid JSON in fixture file"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        continue
    fi
    
    # Get host IP for logging
    HOST_IP=$(jq -r '.ip' "$FIXTURE_PATH" 2>/dev/null || echo "unknown")
    echo "Host: $HOST_IP"
    
    # POST to API with retries
    MAX_RETRIES=3
    RETRY=0
    SUCCESS=false
    
    while [ $RETRY -lt $MAX_RETRIES ] && [ "$SUCCESS" = "false" ]; do
        if [ $RETRY -gt 0 ]; then
            echo "   Retry $RETRY/$MAX_RETRIES..."
            sleep 2
        fi
        
        HTTP_CODE=$(curl -s -o /tmp/seed_response.json -w "%{http_code}" \
            -X POST \
            -H "Content-Type: application/json" \
            -H "X-API-Key: $API_KEY" \
            -d @"$FIXTURE_PATH" \
            "$API_URL/host" \
            --connect-timeout 10 \
            --max-time 30)
        
        if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
            echo "✅ Success (HTTP $HTTP_CODE)"
            SUCCESS=true
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            
            # Show response if verbose
            if [ -f /tmp/seed_response.json ]; then
                RESPONSE=$(cat /tmp/seed_response.json)
                echo "   Response: $RESPONSE"
            fi
        else
            echo "❌ Failed (HTTP $HTTP_CODE)"
            if [ -f /tmp/seed_response.json ]; then
                echo "   Error response:"
                cat /tmp/seed_response.json | jq '.' 2>/dev/null || cat /tmp/seed_response.json
            fi
            RETRY=$((RETRY + 1))
        fi
    done
    
    if [ "$SUCCESS" = "false" ]; then
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    echo ""
done

# Summary
echo "========================================="
echo "Seeding Summary"
echo "========================================="
echo "Total fixtures:    $FIXTURE_COUNT"
echo "✅ Successful:     $SUCCESS_COUNT"
echo "❌ Failed:         $FAIL_COUNT"
echo "⚠️  Skipped:       $SKIP_COUNT"
echo "========================================="
echo "Completed at: $(date)"
echo ""

# Verify hosts in database
echo "🔍 Verifying seeded data..."
TOTAL_HOSTS=$(curl -s -H "X-API-Key: $API_KEY" "$API_URL/host" | jq '. | length' 2>/dev/null || echo "unknown")
echo "Total hosts in database: $TOTAL_HOSTS"
echo ""

# Exit with error if any fixtures failed
if [ $FAIL_COUNT -gt 0 ]; then
    echo "❌ Seeding completed with errors"
    echo "Check log file: $LOG_FILE"
    exit 1
else
    echo "✅ All fixtures seeded successfully!"
    exit 0
fi

