# AWS Setup Guide - Quick Start

## Finding Your Default VPC (2 minutes)

### Option 1: AWS Console (Easiest)

1. **Log into AWS Console**: https://console.aws.amazon.com/
2. **Go to VPC Dashboard**:
   - Search for "VPC" in the top search bar
   - Click "VPC"
3. **Find Default VPC**:
   - Click "Your VPCs" in left sidebar
   - Look for VPC with "Default VPC" column = "Yes"
   - Copy the **VPC ID** (looks like `vpc-0a1b2c3d4e5f6g7h8`)
4. **Find Public Subnet**:
   - Click "Subnets" in left sidebar
   - Find subnet in your default VPC
   - Pick one with "Auto-assign Public IP" = "Yes"
   - Copy the **Subnet ID** (looks like `subnet-0a1b2c3d4e5f6g7h8`)

### Option 2: AWS CLI (If you have it installed)

```bash
# Find default VPC
aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text

# Find public subnet in that VPC
aws ec2 describe-subnets --filters "Name=vpc-id,Values=YOUR_VPC_ID" --query "Subnets[0].SubnetId" --output text
```

### Option 3: Don't Have Default VPC? (Rare)

If you don't have a default VPC (maybe it was deleted):

```bash
# Create a new default VPC
aws ec2 create-default-vpc
```

---

## AWS Credentials for GitHub Actions

GitHub Actions needs AWS credentials to create/destroy the EC2 instance.

### Creating IAM User for Demo (Recommended for MVP)

1. **Go to IAM Console**: https://console.aws.amazon.com/iam/
2. **Create User**:
   - Click "Users" → "Create user"
   - Username: `sirius-demo-github-actions`
   - Click "Next"
3. **Set Permissions**:
   - Select "Attach policies directly"
   - Add these policies:
     - `AmazonEC2FullAccess` (to create/destroy instances)
     - `IAMFullAccess` (to create instance roles) - OR use pre-created role
   - Click "Next" → "Create user"
4. **Create Access Key**:
   - Click on the user you just created
   - Click "Security credentials" tab
   - Click "Create access key"
   - Choose "Application running outside AWS"
   - Click "Next" → "Create access key"
   - **SAVE THESE SECURELY**:
     - Access Key ID (starts with `AKIA...`)
     - Secret Access Key (shown only once!)

### Alternative: Using Your Root Credentials (Quick but not recommended)

For **MVP testing only**, you can use your root AWS credentials:
- Go to AWS Console → Click your name (top right) → "Security credentials"
- Create access key under "Access keys"
- **NOT recommended for production** - create dedicated IAM user instead

---

## Adding Credentials to GitHub

Once you have:
- ✅ VPC ID
- ✅ Subnet ID  
- ✅ AWS Access Key ID
- ✅ AWS Secret Access Key

### Add to GitHub Repository:

1. Go to your GitHub repo: https://github.com/SiriusScan/sirius-demo
2. Click "Settings" → "Secrets and variables" → "Actions"
3. Click "New repository secret" and add:

**Secret 1:**
- Name: `AWS_ACCESS_KEY_ID`
- Value: Your access key ID (AKIA...)

**Secret 2:**
- Name: `AWS_SECRET_ACCESS_KEY`  
- Value: Your secret access key

**Secret 3:**
- Name: `AWS_REGION`
- Value: `us-east-1` (or your preferred region)

---

## Quick Reference

### What You Need to Provide:

```
VPC_ID=vpc-xxxxxxxxxxxxxxxxx
SUBNET_ID=subnet-xxxxxxxxxxxxxxxxx
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
```

### What Terraform Does With These:

1. **Uses existing VPC/Subnet** (doesn't create or destroy them)
2. **Creates EC2 instance** in that subnet
3. **Creates Security Group** in that VPC (allows ports 3000, 9001)
4. **Destroys EC2 + Security Group** on next rebuild
5. **VPC stays untouched** - ready for next rebuild

---

## Minimum Required IAM Permissions

If you want to be more restrictive than `AmazonEC2FullAccess`, here's the minimum:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:RunInstances",
        "ec2:TerminateInstances",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus",
        "ec2:DescribeImages",
        "ec2:DescribeSecurityGroups",
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:CreateTags",
        "ec2:DescribeSubnets",
        "ec2:DescribeVpcs"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:GetRole",
        "iam:DeleteRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:CreateInstanceProfile",
        "iam:DeleteInstanceProfile",
        "iam:AddRoleToInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile",
        "iam:GetInstanceProfile",
        "iam:PassRole"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## Testing Your Setup

Before running GitHub Actions, test Terraform locally:

```bash
cd infra/demo

# Create tfvars file
cat > terraform.tfvars << EOF
vpc_id    = "vpc-YOUR_VPC_ID"
subnet_id = "subnet-YOUR_SUBNET_ID"
aws_region = "us-east-1"
sirius_repo_url = "git@github.com:SiriusScan/Sirius.git"
EOF

# Initialize Terraform
terraform init

# See what will be created (doesn't actually create anything)
terraform plan

# If plan looks good, you can test create:
terraform apply
# Wait ~5 minutes for instance to bootstrap
# Access demo at: http://<public-ip>:3000
# When done testing:
terraform destroy
```

---

## Troubleshooting

### "No default VPC found"
Run: `aws ec2 create-default-vpc`

### "Access Denied" errors
- Check IAM user has correct permissions
- Verify credentials are correct in GitHub secrets

### "Subnet has no internet gateway"
- Use a public subnet (not private)
- Ensure subnet has route to Internet Gateway (0.0.0.0/0 → igw-xxx)

### "Instance not accessible"
- Check security group allows ports 3000, 9001 from your IP
- Verify instance has public IP assigned
- Wait 5-10 minutes for Docker containers to start

---

## Cost Management

- **EC2 t3.medium running 24/7**: ~$30-35/month
- **Storage (30GB)**: ~$2.40/month
- **Data transfer**: ~$1-5/month
- **Total**: ~$35-40/month

To save costs during testing:
```bash
# Stop instance when not in use (keeps data, stops billing for compute)
terraform destroy
```

