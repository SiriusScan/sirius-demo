#!/bin/bash

# monitor_demo.sh - Monitor demo deployment progress
# Usage: ./monitor_demo.sh <public_ip>

PUBLIC_IP="${1:-100.26.170.62}"
API_URL="http://$PUBLIC_IP:9001"
UI_URL="http://$PUBLIC_IP:3000"

echo "========================================="
echo "SiriusScan Demo Deployment Monitor"
echo "========================================="
echo "Public IP: $PUBLIC_IP"
echo "API URL: $API_URL"
echo "UI URL: $UI_URL"
echo ""
echo "Monitoring deployment progress..."
echo "Press Ctrl+C to stop"
echo "========================================="
echo ""

ATTEMPT=0
MAX_ATTEMPTS=120  # 10 minutes

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    
    # Check API health
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/health" --connect-timeout 3 --max-time 5 2>/dev/null || echo "000")
    
    TIMESTAMP=$(date +"%H:%M:%S")
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo "[$TIMESTAMP] ✅ SUCCESS! Demo is ready!"
        echo ""
        echo "========================================="
        echo "🎉 SiriusScan Demo is Live!"
        echo "========================================="
        echo ""
        echo "Access the demo:"
        echo "  UI:  $UI_URL"
        echo "  API: $API_URL"
        echo ""
        echo "Default credentials (displayed on login page):"
        echo "  Username: demo@siriusscan.io"
        echo "  Password: demo"
        echo ""
        echo "========================================="
        exit 0
    elif [ "$HTTP_CODE" = "000" ]; then
        echo "[$TIMESTAMP] ⏳ Attempt $ATTEMPT/$MAX_ATTEMPTS - Waiting for instance to bootstrap..."
    else
        echo "[$TIMESTAMP] 🔄 Attempt $ATTEMPT/$MAX_ATTEMPTS - HTTP $HTTP_CODE (services starting...)"
    fi
    
    sleep 5
done

echo ""
echo "========================================="
echo "⚠️  Timeout after 10 minutes"
echo "========================================="
echo ""
echo "The instance may still be bootstrapping."
echo "You can:"
echo "1. Wait a few more minutes and try: curl $API_URL/health"
echo "2. Check bootstrap logs via SSM:"
echo "   aws ssm start-session --target i-0a723dc23bf403009 --region us-east-1"
echo "   sudo tail -f /var/log/sirius-bootstrap.log"
echo ""

exit 1

