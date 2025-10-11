#!/bin/bash
set -e

# Setup SSH Access for SiriusScan Demo
# This script helps you create an AWS key pair and configure SSH access

echo "🔑 SiriusScan Demo - SSH Access Setup"
echo "======================================"

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS CLI not configured. Please run 'aws configure' first."
    exit 1
fi

# Get current region
AWS_REGION=$(aws configure get region)
if [ -z "$AWS_REGION" ]; then
    AWS_REGION="us-east-1"
    echo "⚠️  No default region set, using us-east-1"
fi

echo "📍 AWS Region: $AWS_REGION"

# Key pair name
KEY_PAIR_NAME="sirius-demo-key"
KEY_FILE="$HOME/.ssh/${KEY_PAIR_NAME}.pem"

echo ""
echo "🔍 Checking for existing key pair..."

# Check if key pair already exists
if aws ec2 describe-key-pairs --key-names "$KEY_PAIR_NAME" --region "$AWS_REGION" > /dev/null 2>&1; then
    echo "✅ Key pair '$KEY_PAIR_NAME' already exists in AWS"
    
    # Check if private key file exists locally
    if [ -f "$KEY_FILE" ]; then
        echo "✅ Private key file exists: $KEY_FILE"
        echo ""
        echo "🎯 To enable SSH access, update your terraform.tfvars:"
        echo "   key_pair_name = \"$KEY_PAIR_NAME\""
        echo ""
        echo "🔗 SSH connection command:"
        echo "   ssh -i $KEY_FILE ubuntu@<instance-ip>"
    else
        echo "❌ Private key file not found: $KEY_FILE"
        echo "💡 You'll need to recreate the key pair or use SSM Session Manager"
        echo ""
        echo "🔄 To recreate the key pair:"
        echo "   1. Delete existing key pair: aws ec2 delete-key-pair --key-name $KEY_PAIR_NAME --region $AWS_REGION"
        echo "   2. Run this script again"
    fi
else
    echo "📝 Creating new key pair: $KEY_PAIR_NAME"
    
    # Create key pair
    aws ec2 create-key-pair \
        --key-name "$KEY_PAIR_NAME" \
        --region "$AWS_REGION" \
        --query 'KeyMaterial' \
        --output text > "$KEY_FILE"
    
    # Set proper permissions
    chmod 600 "$KEY_FILE"
    
    echo "✅ Key pair created successfully!"
    echo "📁 Private key saved to: $KEY_FILE"
    echo ""
    echo "🎯 To enable SSH access, update your terraform.tfvars:"
    echo "   key_pair_name = \"$KEY_PAIR_NAME\""
    echo ""
    echo "🔗 SSH connection command:"
    echo "   ssh -i $KEY_FILE ubuntu@<instance-ip>"
fi

echo ""
echo "📋 Next Steps:"
echo "1. Update terraform.tfvars with: key_pair_name = \"$KEY_PAIR_NAME\""
echo "2. Run: terraform apply"
echo "3. Use SSH to troubleshoot: ssh -i $KEY_FILE ubuntu@<instance-ip>"
echo ""
echo "🛡️  Security Note:"
echo "   - SSH access is restricted to the same CIDR blocks as your demo access"
echo "   - You can further restrict SSH with ssh_allowed_cidrs variable"
echo "   - SSM Session Manager is still available as backup access method"
