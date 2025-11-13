# SiriusScan Demo - Automated Infrastructure as Code

[![Deploy Demo](https://github.com/SiriusScan/sirius-demo/actions/workflows/deploy-demo.yml/badge.svg)](https://github.com/SiriusScan/sirius-demo/actions/workflows/deploy-demo.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A fully automated, production-ready demo deployment of SiriusScan using Infrastructure as Code (IaC) with GitHub Actions CI/CD, AWS Route 53 DNS management, and comprehensive monitoring.

## 🚀 Quick Start

### **Live Demo Access**

- **UI**: http://sirius.opensecurity.com:3000
- **API**: http://sirius.opensecurity.com:9001
- **Health Check**: http://sirius.opensecurity.com:9001/health

### **Deploy Your Own**

```bash
# Clone the repository
git clone https://github.com/SiriusScan/sirius-demo.git
cd sirius-demo

# Configure AWS credentials
aws configure

# Deploy with GitHub Actions
gh workflow run deploy-demo.yml

# Or deploy manually
cd infra/demo
terraform init
terraform apply
```

## 🏗️ Architecture

### **Infrastructure Stack**

- **Compute**: AWS EC2 (t3.small, 2 vCPU, 2GB RAM) - Cost-optimized for demo
- **Networking**: VPC with public subnet, security groups
- **Static IP**: Elastic IP for consistent domain access
- **DNS**: AWS Route 53 with automatic A record updates
- **Monitoring**: CloudWatch integration
- **Access**: AWS SSM Session Manager (no SSH keys needed)

### **Application Stack**

- **Frontend**: Next.js UI (Port 3000)
- **Backend**: Go API with PostgreSQL (Port 9001)
- **Engine**: SiriusScan scanning engine
- **Database**: PostgreSQL with automated migrations
- **Message Queue**: RabbitMQ for async processing
- **Cache**: Valkey (Redis-compatible)

### **CI/CD Pipeline**

- **Automated Deployments**: GitHub Actions workflows
- **Canary Behavior**: Demo automatically rebuilds on every push to Sirius main branch to catch bad commits
- **Infrastructure as Code**: Terraform with remote state
- **Static IP Management**: Elastic IP for consistent access
- **DNS Management**: Automatic Route 53 A record updates
- **Health Monitoring**: Comprehensive service checks with 20-minute timeout
- **Cost Management**: Automatic cleanup of old resources
- **Resource Cleanup**: Comprehensive AWS resource cleanup before deployment

**Canary Deployment**: The demo acts as a canary deployment - it automatically rebuilds whenever code is pushed to the Sirius main branch. This ensures that any breaking changes or bad commits are caught immediately by the demo deployment failing. The demo rebuilds on:
- Every push to Sirius main branch (via repository_dispatch)
- Every push to sirius-demo main branch (direct push trigger)
- Scheduled daily rebuilds (2 AM UTC)
- Manual workflow dispatch

## 📁 Repository Structure

```
sirius-demo/
├── .github/
│   └── workflows/
│       ├── deploy-demo.yml         # Main deployment workflow
│       ├── cleanup.yml             # Resource cleanup workflow
│       ├── test-deployment.yml     # Configuration validation
│       ├── monitor-demo.yml        # Health monitoring
│       └── README.md               # Workflow documentation
├── infra/
│   └── demo/
│       ├── main.tf                 # Terraform infrastructure
│       ├── variables.tf            # Configurable parameters
│       ├── outputs.tf              # Exported values (URLs, IPs)
│       └── user_data.sh            # EC2 bootstrap script
├── scripts/
│   ├── cleanup-aws-resources.sh    # Comprehensive AWS cleanup
│   ├── update-dns.sh               # DNS update automation
│   ├── monitor_demo.sh             # Deployment monitoring
│   ├── wait_for_api.sh             # Health check poller
│   └── seed_demo.sh                # Data seeding automation
├── docs/
│   ├── DNS_SETUP_GUIDE.md          # DNS configuration guide
│   └── AWS_ACCESS_KEYS_SETUP.md    # AWS setup instructions
├── fixtures/
│   ├── it-environment/             # Corporate IT hosts
│   ├── ot-environment/             # Industrial OT hosts
│   ├── index.json                  # Master fixture list
│   └── README.md                   # Demo data documentation
└── data/
    └── host-record.json            # Example host data
```

## 🤖 GitHub Actions Workflows

### **Core Workflows**

| Workflow            | Purpose                                  | Trigger                | Frequency         |
| ------------------- | ---------------------------------------- | ---------------------- | ----------------- |
| **Deploy Demo**     | Deploy/rebuild demo environment          | Schedule, Push, Manual | Daily at 2 AM UTC |
| **Cleanup**         | Remove old resources to manage costs     | Schedule, Manual       | Every 6 hours     |
| **Test Deployment** | Validate configuration without deploying | PR, Manual             | On every PR       |
| **Monitor Demo**    | Health checks and status monitoring      | Schedule, Manual       | Every 2 hours     |

### **Key Features**

- **Static IP Management**: Elastic IP ensures consistent domain access
- **Automatic DNS Updates**: Updates `sirius.opensecurity.com` A record on every deployment
- **Comprehensive Cleanup**: Removes all AWS resources before new deployment
- **Health Monitoring**: 20-minute health checks with detailed error reporting
- **Cost Management**: Automatic cleanup of unused resources including Elastic IPs
- **PR Integration**: Validation and deployment testing on pull requests
- **Resource Naming**: Prevents conflicts with `name_prefix` and lifecycle management

### **Manual Deployment**

```bash
# Deploy with all features
gh workflow run deploy-demo.yml

# Deploy without data seeding
gh workflow run deploy-demo.yml --field skip_seeding=true

# Force rebuild even if no changes
gh workflow run deploy-demo.yml --field force_rebuild=true
```

## 🌐 Static IP & DNS Management

### **Elastic IP Implementation**

The demo uses an **Elastic IP (EIP)** to provide a static IP address that never changes, even when instances are recreated. This ensures consistent domain access without requiring DNS updates.

#### **How It Works:**

1. **Static IP**: Elastic IP `44.224.189.56` is allocated and associated with the instance
2. **One-Time DNS Setup**: A record `sirius.opensecurity.com` → `44.224.189.56` is created once
3. **Automatic Reassociation**: When instances are recreated, Terraform automatically reassociates the same EIP
4. **No DNS Updates**: The domain always points to the same IP address

#### **Benefits:**

- ✅ **Consistent Access**: Always accessible at `http://sirius.opensecurity.com:3000`
- ✅ **No DNS Complexity**: No need for CNAME records or dynamic DNS updates
- ✅ **Cost Effective**: EIPs are free when attached to running instances
- ✅ **Simple Management**: Terraform handles all the complexity

#### **DNS Configuration:**

```bash
# Current DNS setup (one-time configuration)
sirius.opensecurity.com.    A    44.224.189.56

# Access URLs (never change)
UI:  http://sirius.opensecurity.com:3000
API: http://sirius.opensecurity.com:9001
```

## 🔧 Configuration

### **Environment Variables**

```bash
# Required
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key

# Optional (with defaults)
AWS_REGION=us-west-2
DEMO_INSTANCE_TYPE=t3.small
```

### **Terraform Variables**

```hcl
# Network Configuration
vpc_id    = "vpc-416eeb39"      # Your VPC ID
subnet_id = "subnet-d31ffe8e"    # Your public subnet ID

# Instance Configuration
instance_type    = "t3.small"    # 2 vCPU, 2GB RAM (cost-optimized)
root_volume_size = 20            # GB

# Access Control
allowed_cidrs = ["0.0.0.0/0"]    # Public access for demo

# Repository Configuration
sirius_repo_url = "https://github.com/SiriusScan/Sirius.git"
demo_branch     = "demo"
```

## 🌐 DNS Management

### **Automatic DNS Updates**

The deployment automatically updates DNS records for consistent access:

- **Domain**: `sirius.opensecurity.com`
- **UI**: `http://sirius.opensecurity.com:3000`
- **API**: `http://sirius.opensecurity.com:9001`

### **DNS Setup Requirements**

1. **Route 53 Hosted Zone**: `opensecurity.com` (already configured)
2. **Nameservers**: Update your domain registrar with AWS nameservers
3. **Propagation**: Allow 24-48 hours for full DNS propagation

### **Manual DNS Update**

```bash
# Update DNS manually
./scripts/update-dns.sh 34.219.87.111 opensecurity.com sirius

# Check DNS resolution
nslookup sirius.opensecurity.com
```

## 📊 Monitoring & Health Checks

### **Service Health**

- **API Health**: `http://sirius.opensecurity.com:9001/health`
- **UI Health**: `http://sirius.opensecurity.com:3000`
- **Instance Status**: AWS EC2 Console

### **Monitoring Features**

- **Automatic Health Checks**: 20-minute timeout with retry logic
- **Service Verification**: API and UI endpoint validation
- **Error Reporting**: Detailed logs for troubleshooting
- **Cost Monitoring**: Automatic cleanup of unused resources

### **Access Logs**

#### SSH Access (Recommended for Troubleshooting)

```bash
# If SSH is configured with public key
ssh ubuntu@<instance-ip>

# Check service logs
docker compose logs sirius-api
docker compose logs sirius-ui
```

#### SSM Session Manager (Backup Access)

```bash
# Connect to instance via SSM
aws ssm start-session --target i-xxxxxxxxx --region us-west-2

# Check service logs
docker compose logs sirius-api
docker compose logs sirius-ui
```

#### Setting Up SSH Access

```bash
# Update terraform.tfvars with your public key
public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCrV4Rtby+n9V5Ku90icvg2lLAILwwxa1qgf4FyQogrfiA8gzMAd73iHObiEWNniLUmBnGBe1kqu6xEr5+L9D1eCa7HsUZdYDWAwKclxB0ay39URgKHBbbySeSta1VAUS8tJ3mVGikbZPi2CxhGlM7Z2L3rQnLtYJyrA5Bd11FyCTKVaxzxdyB63vznjbwxE490FRWtDUuSU+Kn81qIwG+kYvqzF8KyCX33eRcfXVt7uyLCYaR7Nrws8NpuK2cfC+iRhuqIzT7PNNaDnv2UURCIAGju8YMUAU8N1yN/nEcqUjwX1TdGPzd0d0MqZ2oT9+HEeTG8O/3/1pshpRl2Ips9"

# Apply changes
terraform apply
```

## 💰 Cost Management

### **Cost Optimization**

The demo infrastructure is optimized for cost efficiency while maintaining full functionality:

- **Instance Type**: t3.small (2 vCPU, 2GB RAM) - 77% cost savings vs t2.large
- **Storage**: 20GB EBS volume - sufficient for demo workloads
- **Resource Usage**: Current utilization ~800MB RAM, well within 2GB limit
- **Estimated Monthly Cost**: ~$15-20/month (vs ~$67/month with t2.large)

### **Resource Costs**

- **EC2 Instance**: ~$0.0208/hour (t3.small) - Cost-optimized
- **Elastic IP**: $0.00/hour when attached to running instance
- **EBS Storage**: ~$0.10/GB/month (~$2.00 for 20GB)
- **Route 53**: ~$0.50/month per hosted zone
- **Data Transfer**: Minimal for demo usage (~$1-2/month)

### **Cost Optimization**

- **Automatic Cleanup**: Old resources removed every 6 hours including Elastic IPs
- **Scheduled Deployments**: Daily rebuilds to prevent long-running instances
- **Elastic IP Management**: EIPs are automatically released when not attached
- **Resource Tagging**: Clear ownership and purpose tags
- **Monitoring**: Cost alerts and usage tracking

### **Estimated Monthly Cost**

- **Current Configuration (t3.small)**: ~$18/month (if running 24/7)
- **With Cleanup**: ~$15/month (regular rebuilds)
- **Production**: Contact for enterprise pricing

**Cost Savings**: Using t3.small instead of t2.large saves $52.56/month ($630/year)

## 🛠️ Development

### **Local Development**

```bash
# Clone the main SiriusScan repository
git clone https://github.com/SiriusScan/Sirius.git
cd Sirius

# Switch to demo branch
git checkout demo

# Run locally with Docker Compose
docker compose up -d
```

### **Contributing**

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `gh workflow run test-deployment.yml`
5. Submit a pull request

### **Testing**

```bash
# Test Terraform configuration
cd infra/demo
terraform init
terraform validate
terraform plan

# Test deployment workflow
gh workflow run test-deployment.yml

# Test cleanup script
./scripts/cleanup-aws-resources.sh
```

## 🔒 Security

### **Security Features**

- **No SSH Keys**: Uses AWS SSM Session Manager
- **Encrypted Storage**: EBS volumes encrypted at rest
- **Network Security**: Security groups with minimal required access
- **IAM Roles**: Least privilege access for EC2 instances
- **Resource Tagging**: Clear ownership and purpose

### **Access Control**

- **Public Demo**: Open access for demonstration purposes
- **Production**: Contact for enterprise security configuration
- **Monitoring**: All actions logged in AWS CloudTrail

## 🚨 Troubleshooting

### **Common Issues**

#### **Deployment Fails**

```bash
# Check GitHub Actions logs
gh run view --log

# Verify AWS credentials
aws sts get-caller-identity

# Check resource cleanup
./scripts/cleanup-aws-resources.sh
```

#### **Services Not Responding**

```bash
# Check instance status
aws ec2 describe-instances --region us-west-2

# Connect to instance
aws ssm start-session --target i-xxxxxxxxx --region us-west-2

# Check service logs
docker compose logs
```

#### **DNS Not Resolving**

```bash
# Check DNS record
aws route53 list-resource-record-sets --hosted-zone-id Z0946222JHY5QRB4CPV2

# Test DNS resolution
nslookup sirius.opensecurity.com
dig sirius.opensecurity.com
```

### **Debug Commands**

```bash
# Check all demo resources
aws ec2 describe-instances --filters "Name=tag:Name,Values=sirius-demo"
aws ec2 describe-security-groups --filters "Name=group-name,Values=sirius-demo-sg*"
aws iam list-roles --query "Roles[?contains(RoleName, 'sirius-demo')]"

# Check Elastic IP status
aws ec2 describe-addresses --filters "Name=tag:Name,Values=sirius-demo-eip*"
aws ec2 describe-addresses --public-ips 44.224.189.56

# Test health endpoints
curl -f http://sirius.opensecurity.com:9001/health
curl -I http://sirius.opensecurity.com:3000

# Test direct IP access (if DNS issues)
curl -f http://44.224.189.56:9001/health
curl -I http://44.224.189.56:3000
```

## 🆕 Recent Updates

### **v2.1 - Configuration Fixes & Cost Optimization (October 2025)**

- ✅ **Cost Optimization**: Fixed instance type from t2.large to t3.small (77% cost reduction)
- ✅ **Configuration Consistency**: Resolved CI/CD vs manual deployment inconsistencies
- ✅ **Health Endpoint Fix**: Standardized API health checks to `/health` endpoint
- ✅ **Branch Configuration**: Corrected demo branch name throughout all config files
- ✅ **Region Standardization**: Fixed AWS region defaults to us-west-2
- ✅ **Investigation Report**: Created comprehensive analysis of issues and fixes

### **Cost Savings Achieved**

- **Monthly**: $52.56/month saved ($630/year)
- **Instance**: t3.small (2 vCPU, 2GB RAM) vs t2.large (2 vCPU, 8GB RAM)
- **Performance**: No degradation - 2GB RAM sufficient for demo workload

### **v2.0 - Elastic IP Implementation (October 2024)**

- ✅ **Static IP Management**: Implemented Elastic IP for consistent domain access
- ✅ **Simplified DNS**: One-time A record setup, no more dynamic DNS complexity
- ✅ **Enhanced Cleanup**: Comprehensive AWS resource cleanup with proper ordering
- ✅ **Resource Naming**: Fixed naming conflicts with `name_prefix` and lifecycle management
- ✅ **Health Monitoring**: Extended health checks to 20 minutes for reliable deployments
- ✅ **GitHub Actions**: Complete CI/CD pipeline with AWS access key authentication
- ✅ **Documentation**: Comprehensive guides for DNS setup and AWS configuration

## 📚 Documentation

### **Additional Resources**

- [DNS Setup Guide](docs/DNS_SETUP_GUIDE.md) - Complete DNS configuration
- [AWS Setup Guide](docs/AWS_ACCESS_KEYS_SETUP.md) - AWS credentials setup
- [Workflow Documentation](.github/workflows/README.md) - GitHub Actions details
- [Demo Data Guide](fixtures/README.md) - Sample data and fixtures

### **Related Projects**

- [SiriusScan Main Repository](https://github.com/SiriusScan/Sirius) - Core application
- [SiriusScan Website](https://siriusscan.com) - Official website
- [Documentation](https://docs.siriusscan.com) - Complete documentation

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Support

### **Getting Help**

- **Issues**: [GitHub Issues](https://github.com/SiriusScan/sirius-demo/issues)
- **Discussions**: [GitHub Discussions](https://github.com/SiriusScan/sirius-demo/discussions)
- **Email**: support@siriusscan.com

### **Enterprise Support**

For enterprise deployments, custom configurations, or production support, contact:

- **Email**: enterprise@siriusscan.com
- **Website**: https://siriusscan.com/enterprise

---

**Built with ❤️ by the SiriusScan Team**

_Last updated: October 2024_
