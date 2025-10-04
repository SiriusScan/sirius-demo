# DNS Setup Guide for SiriusScan Demo

This guide explains how to set up dynamic DNS for your SiriusScan demo deployment, so you can access it via a consistent domain name instead of changing IP addresses.

## 🎯 Overview

The demo deployment can automatically update DNS records when a new instance is created, giving you a stable URL like `demo.yourdomain.com` instead of changing IP addresses.

## 🌐 DNS Options

### Option 1: AWS Route 53 (Recommended)

**Best for:** Production demos, AWS-integrated workflows

**Setup Steps:**

1. **Create Route 53 Hosted Zone**

   ```bash
   # Via AWS CLI
   aws route53 create-hosted-zone \
     --name yourdomain.com \
     --caller-reference $(date +%s)
   ```

2. **Update Your Domain's Nameservers**

   - Copy the nameservers from Route 53
   - Update your domain registrar with these nameservers
   - Wait for propagation (can take up to 48 hours)

3. **Deploy with DNS**
   ```bash
   # Trigger deployment with DNS
   gh workflow run deploy-demo.yml \
     --field domain="yourdomain.com" \
     --field subdomain="demo"
   ```

**Result:** `http://demo.yourdomain.com:3000`

### Option 2: Cloudflare (Alternative)

**Best for:** Free DNS management, global CDN

**Setup Steps:**

1. **Add Domain to Cloudflare**

   - Sign up at cloudflare.com
   - Add your domain
   - Update nameservers at your registrar

2. **Get API Token**

   - Go to Cloudflare Dashboard → My Profile → API Tokens
   - Create token with Zone:Edit permissions

3. **Add Cloudflare Secrets to GitHub**
   ```bash
   gh secret set CLOUDFLARE_API_TOKEN --body "your-api-token"
   gh secret set CLOUDFLARE_ZONE_ID --body "your-zone-id"
   ```

### Option 3: AWS Application Load Balancer

**Best for:** Production-ready, SSL termination, health checks

**Benefits:**

- Static IP address
- SSL certificate support
- Built-in health checks
- More reliable than direct EC2 access

## 🚀 Usage Examples

### Basic Deployment (IP only)

```bash
gh workflow run deploy-demo.yml
# Result: http://34.219.87.111:3000
```

### Deployment with DNS

```bash
gh workflow run deploy-demo.yml \
  --field domain="yourdomain.com" \
  --field subdomain="demo"
# Result: http://demo.yourdomain.com:3000
```

### Custom Subdomain

```bash
gh workflow run deploy-demo.yml \
  --field domain="yourdomain.com" \
  --field subdomain="sirius-demo"
# Result: http://sirius-demo.yourdomain.com:3000
```

## 🔧 Manual DNS Update

If you need to update DNS manually:

```bash
# Update DNS record
./scripts/update-dns.sh 34.219.87.111 yourdomain.com demo

# Check current DNS
nslookup demo.yourdomain.com
```

## 📋 Required AWS Permissions

For Route 53 DNS updates, your AWS access keys need:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:GetHostedZone",
        "route53:ChangeResourceRecordSets",
        "route53:GetChange"
      ],
      "Resource": "*"
    }
  ]
}
```

## 🐛 Troubleshooting

### DNS Not Updating

- Check if hosted zone exists: `aws route53 list-hosted-zones`
- Verify nameservers are updated at your registrar
- Check AWS permissions for Route 53

### Domain Not Resolving

- Wait for DNS propagation (up to 48 hours)
- Check with `nslookup` or `dig`
  . Verify the subdomain is correct

### Workflow Fails on DNS Step

- Check GitHub Actions logs for specific error
- Verify domain format (no http://, no trailing slash)
- Ensure subdomain doesn't conflict with existing records

## 💡 Pro Tips

1. **Use a dedicated subdomain** like `demo.yourdomain.com` to avoid conflicts
2. **Set TTL to 300 seconds** for faster updates during development
3. **Monitor DNS propagation** using tools like `whatsmydns.net`
4. **Keep backup access** via IP address in case DNS fails

## 🔒 Security Considerations

- DNS updates are logged in AWS CloudTrail
- Use least-privilege IAM permissions
- Consider using AWS Secrets Manager for sensitive data
- Monitor for unauthorized DNS changes

---

_This guide is part of the SiriusScan demo project. For more information, see the main [README.md](../README.md)._
