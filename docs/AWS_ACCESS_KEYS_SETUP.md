# AWS Access Keys Setup Guide

This guide explains how to set up AWS access keys for the SiriusScan demo GitHub Actions workflows.

## Overview

For simplicity, we use AWS access keys instead of OIDC authentication. This is suitable for:

- Single-use demo accounts
- Development/testing environments
- Simple deployment scenarios

## Step 1: Create AWS Access Keys

1. **Log into AWS Console**

   - Go to [AWS Console](https://console.aws.amazon.com/)
   - Sign in with your account

2. **Navigate to IAM**

   - Go to Services → IAM
   - Click on "Users" in the left sidebar

3. **Create or Select User**

   - If creating a new user: Click "Create user"
   - Enter username: `sirius-demo-github-actions`
   - Select "Programmatic access"
   - Click "Next: Permissions"

4. **Attach Policies**

   - Click "Attach existing policies directly"
   - Search and select these policies:
     - `AmazonEC2FullAccess`
     - `IAMFullAccess`
     - `AmazonS3FullAccess`
     - `DynamoDBFullAccess`
   - Click "Next: Tags" (optional)
   - Click "Next: Review"
   - Click "Create user"

5. **Create Access Keys**
   - Click on the created user
   - Go to "Security credentials" tab
   - Click "Create access key"
   - Select "Application running outside AWS"
   - Click "Next"
   - Add description: "GitHub Actions for SiriusScan Demo"
   - Click "Create access key"
   - **IMPORTANT**: Copy and save both:
     - Access Key ID
     - Secret Access Key

## Step 2: Add Secrets to GitHub Repository

1. **Go to Repository Settings**

   - Navigate to your `sirius-demo` repository
   - Click "Settings" tab
   - Click "Secrets and variables" → "Actions"

2. **Add Repository Secrets**

   - Click "New repository secret"
   - Name: `AWS_ACCESS_KEY_ID`
   - Value: Your access key ID from Step 1
   - Click "Add secret"

   - Click "New repository secret"
   - Name: `AWS_SECRET_ACCESS_KEY`
   - Value: Your secret access key from Step 1
   - Click "Add secret"

   - (Optional) Click "New repository secret"
   - Name: `AWS_REGION`
   - Value: `us-east-1` (or your preferred region)
   - Click "Add secret"

## Step 3: Verify Setup

Run the setup script to verify everything is configured correctly:

```bash
./scripts/setup-github-actions.sh
```

This will check:

- ✅ GitHub CLI is installed and authenticated
- ✅ Repository secrets are configured
- ✅ Workflow files are valid
- ✅ Terraform configuration is ready

## Step 4: Test the Workflows

1. **Test Configuration Validation**

   ```bash
   gh workflow run test-deployment.yml
   ```

2. **Test Manual Deployment**

   ```bash
   gh workflow run deploy-demo.yml
   ```

3. **Monitor Workflow Status**
   ```bash
   gh run list
   gh run view <run-id>
   ```

## Required AWS Permissions

The access keys need these permissions:

### EC2 Permissions

- `ec2:RunInstances`
- `ec2:TerminateInstances`
- `ec2:DescribeInstances`
- `ec2:DescribeImages`
- `ec2:CreateSecurityGroup`
- `ec2:DeleteSecurityGroup`
- `ec2:AuthorizeSecurityGroupIngress`
- `ec2:AuthorizeSecurityGroupEgress`
- `ec2:RevokeSecurityGroupIngress`
- `ec2:RevokeSecurityGroupEgress`
- `ec2:DescribeSecurityGroups`
- `ec2:DescribeVpcs`
- `ec2:DescribeSubnets`

### IAM Permissions

- `iam:CreateRole`
- `iam:DeleteRole`
- `iam:AttachRolePolicy`
- `iam:DetachRolePolicy`
- `iam:CreateInstanceProfile`
- `iam:DeleteInstanceProfile`
- `iam:AddRoleToInstanceProfile`
- `iam:RemoveRoleFromInstanceProfile`
- `iam:ListInstanceProfiles`
- `iam:ListRoles`

### S3 Permissions (for Terraform state)

- `s3:CreateBucket`
- `s3:DeleteBucket`
- `s3:GetObject`
- `s3:PutObject`
- `s3:DeleteObject`
- `s3:ListBucket`

### DynamoDB Permissions (for Terraform state locking)

- `dynamodb:CreateTable`
- `dynamodb:DeleteTable`
- `dynamodb:DescribeTable`
- `dynamodb:GetItem`
- `dynamodb:PutItem`
- `dynamodb:DeleteItem`

## Security Best Practices

1. **Use Dedicated User**: Create a separate IAM user for GitHub Actions
2. **Least Privilege**: Only grant necessary permissions
3. **Regular Rotation**: Rotate access keys periodically
4. **Monitor Usage**: Check AWS CloudTrail for access key usage
5. **Secure Storage**: Never commit access keys to code

## Troubleshooting

### Common Issues

**"Access Denied" Errors**

- Verify access keys are correct
- Check IAM user has required permissions
- Ensure policies are attached to the user

**"Invalid Access Key" Errors**

- Double-check the access key ID
- Verify the secret access key is correct
- Check for extra spaces or characters

**"Insufficient Permissions" Errors**

- Review the required permissions list above
- Ensure all necessary policies are attached
- Check if any service-specific permissions are missing

### Debug Commands

```bash
# Test AWS credentials locally
aws sts get-caller-identity

# List available regions
aws ec2 describe-regions

# Check EC2 permissions
aws ec2 describe-instances --max-items 1

# Check IAM permissions
aws iam list-roles --max-items 1
```

## Cost Considerations

- **EC2 Instances**: ~$15/month per t3.small instance
- **EBS Storage**: ~$2.40/month for 30GB
- **Data Transfer**: ~$1-5/month
- **S3/DynamoDB**: <$1/month for Terraform state

## Next Steps

1. ✅ Set up AWS access keys
2. ✅ Add secrets to GitHub repository
3. ✅ Run setup verification script
4. ✅ Test workflows manually
5. ✅ Enable scheduled deployments

---

For more information, see the main project documentation in the root directory.

