#!/bin/bash

# wait_for_api.sh - Poll API health endpoint until ready
# Usage: ./wait_for_api.sh <api_url>

set -e

API_URL="${1:-http://localhost:9001}"
HEALTH_ENDPOINT="$API_URL/health"
MAX_ATTEMPTS=180  # 15 minutes with 5 second intervals
ATTEMPT=0
BACKOFF=5

echo "========================================="
echo "Waiting for API to become healthy"
echo "Health endpoint: $HEALTH_ENDPOINT"
echo "Max attempts: $MAX_ATTEMPTS ($(($MAX_ATTEMPTS * $BACKOFF / 60)) minutes)"
echo "========================================="

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    
    echo -n "[$(date +%T)] Attempt $ATTEMPT/$MAX_ATTEMPTS: "
    
    # Try to reach health endpoint
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_ENDPOINT" --connect-timeout 5 --max-time 10 || echo "000")
    
    if [ "$HTTP_CODE" = "200" ]; then
        # Verify JSON response contains "healthy" status
        RESPONSE=$(curl -s "$HEALTH_ENDPOINT" --connect-timeout 5 --max-time 10)
        STATUS=$(echo "$RESPONSE" | jq -r '.status' 2>/dev/null || echo "unknown")
        
        if [ "$STATUS" = "healthy" ]; then
            echo "✅ SUCCESS - API is healthy!"
            echo ""
            echo "Health response:"
            echo "$RESPONSE" | jq '.'
            echo ""
            echo "Total wait time: $(($ATTEMPT * $BACKOFF)) seconds"
            exit 0
        else
            echo "⚠️  HTTP 200 but status is '$STATUS', retrying..."
        fi
    elif [ "$HTTP_CODE" = "000" ]; then
        echo "❌ Connection failed, retrying in ${BACKOFF}s..."
    else
        echo "⚠️  HTTP $HTTP_CODE, retrying in ${BACKOFF}s..."
    fi
    
    # Exponential backoff (cap at 30 seconds)
    if [ $BACKOFF -lt 30 ]; then
        BACKOFF=$((BACKOFF + 5))
    fi
    
    sleep $BACKOFF
done

echo ""
echo "========================================="
echo "❌ TIMEOUT: API did not become healthy after $MAX_ATTEMPTS attempts"
echo "========================================="
echo ""
echo "Troubleshooting steps:"
echo "1. Check if services are running:"
echo "   docker compose ps"
echo ""
echo "2. Check API logs:"
echo "   docker compose logs sirius-api"
echo ""
echo "3. Check if API port is listening:"
echo "   netstat -tlnp | grep 9001"
echo ""
echo "4. Try manual health check:"
echo "   curl -v $HEALTH_ENDPOINT"
echo ""

exit 1

