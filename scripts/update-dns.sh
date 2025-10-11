#!/bin/bash

# Update DNS record for SiriusScan demo
# Usage: ./update-dns.sh <elastic-ip> <domain> [subdomain]

set -e

ELASTIC_IP="$1"
DOMAIN="$2"
SUBDOMAIN="${3:-demo}"

if [ -z "$ELASTIC_IP" ] || [ -z "$DOMAIN" ]; then
    echo "Usage: $0 <elastic-ip> <domain> [subdomain]"
    echo "Example: $0 34.219.87.111 yourdomain.com demo"
    exit 1
fi

FULL_DOMAIN="${SUBDOMAIN}.${DOMAIN}"

echo "🌐 Updating DNS A record for $FULL_DOMAIN -> $ELASTIC_IP"

# Check if Route 53 hosted zone exists
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='${DOMAIN}.'].Id" --output text)

if [ -z "$HOSTED_ZONE_ID" ]; then
    echo "❌ No Route 53 hosted zone found for $DOMAIN"
    echo "Please create a hosted zone in Route 53 first:"
    echo "1. Go to Route 53 in AWS Console"
    echo "2. Create hosted zone for $DOMAIN"
    echo "3. Update your domain's nameservers"
    exit 1
fi

# Remove leading slash from hosted zone ID
HOSTED_ZONE_ID=$(echo $HOSTED_ZONE_ID | sed 's|/hostedzone/||')

echo "📋 Found hosted zone: $HOSTED_ZONE_ID"

# Create change batch
cat > /tmp/dns-change.json << EOF
{
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "$FULL_DOMAIN",
                "Type": "A",
                "TTL": 300,
                "ResourceRecords": [
                    {
                        "Value": "$ELASTIC_IP"
                    }
                ]
            }
        }
    ]
}
EOF

# Apply DNS change
echo "🔄 Updating DNS record..."
CHANGE_ID=$(aws route53 change-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONE_ID" \
    --change-batch file:///tmp/dns-change.json \
    --query 'ChangeInfo.Id' \
    --output text)

echo "✅ DNS change submitted: $CHANGE_ID"

# Wait for change to propagate
echo "⏳ Waiting for DNS propagation (this may take a few minutes)..."
aws route53 wait resource-record-sets-changed --id "$CHANGE_ID"

echo "🎉 DNS record updated successfully!"
echo "🌐 Demo available at: http://$FULL_DOMAIN:3000"
echo "🔗 API available at: http://$FULL_DOMAIN:9001"

# Cleanup
rm -f /tmp/dns-change.json
