# SiriusScan Demo - Continuous Rebuild Infrastructure

> **Automated demo environment for SiriusScan that rebuilds nightly and on every code change**

## 🎯 Quick Start

```bash
# Trigger a rebuild (requires GitHub Actions access)
gh workflow run rebuild-demo.yml

# Access the demo
# URL will be provided after deployment: http://<ec2-public-ip>:3000
```

**Demo Credentials** (displayed on login page in demo mode):

- Username: `demo@siriusscan.io`
- Password: `demo`

## 📋 Project Overview

This repository contains the Infrastructure as Code (IaC) and automation for a continuously rebuilt demo environment of SiriusScan. The demo:

- **Rebuilds automatically** every night at 23:59 UTC
- **Rebuilds on code changes** when pushed to `demo` branch in SiriusScan repo
- **Seeds realistic data** representing "Ellingson Mineral Company" corporate network
- **Validates deployability** by ensuring the stack can build from scratch

### Why This Exists

1. **Always Fresh**: Prospects and users always see the latest version
2. **Deployment Validation**: Continuous verification that SiriusScan can be deployed cleanly
3. **Sales Enablement**: Reliable demo environment for sales and community engagement
4. **Foundation for Scale**: Architecture ready to scale to multi-tenant demo platform

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     GitHub Actions                          │
│  Triggers: Nightly Schedule + Push to demo branch          │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│                      Terraform                              │
│  Destroys old infrastructure → Creates fresh EC2 instance   │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│                   EC2 Instance (t3.medium)                  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Bootstrap Script (user-data):                       │  │
│  │  1. Install Docker, dependencies                     │  │
│  │  2. Clone SiriusScan repo (demo branch)             │  │
│  │  3. Launch docker-compose stack                      │  │
│  │  4. Wait for API health                              │  │
│  │  5. Seed demo data (Ellingson fixtures)             │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  Running Services:                                          │
│  • sirius-ui (port 3000)                                   │
│  • sirius-api (port 9001)                                  │
│  • sirius-engine (port 5174)                               │
│  • PostgreSQL, RabbitMQ, Valkey                            │
└─────────────────────────────────────────────────────────────┘
```

## 📁 Repository Structure

```
sirius-demo/
├── .github/
│   └── workflows/
│       └── rebuild-demo.yml        # CI/CD automation
├── infra/
│   └── demo/
│       ├── main.tf                 # Terraform infrastructure
│       ├── variables.tf            # Configurable parameters
│       ├── outputs.tf              # Exported values (URLs, IPs)
│       └── user_data.sh            # EC2 bootstrap script
├── scripts/
│   ├── wait_for_api.sh             # Health check poller
│   └── seed_demo.sh                # Data seeding automation
├── fixtures/
│   ├── it-environment/             # Corporate IT hosts
│   ├── ot-environment/             # Industrial OT hosts
│   ├── index.json                  # Master fixture list
│   └── README.md                   # Demo data documentation
├── docs/
│   ├── RUNBOOK.md                  # Operational procedures
│   ├── TROUBLESHOOTING.md          # Issue resolution guide
│   └── ARCHITECTURE.md             # Detailed design
├── tasks/
│   └── tasks.json                  # Project task breakdown
├── PROJECT_PLAN.md                 # High-level project plan
├── PRD.txt                         # Product requirements
└── README.md                       # This file
```

## 🚀 Deployment

### Prerequisites

- AWS account with EC2 access
- GitHub repository access
- Terraform installed locally (for testing)

### Initial Setup

**USER ACTION REQUIRED**: Complete these steps before first deployment:

1. **Create GitHub Repository Secrets**:

   - `AWS_ACCESS_KEY_ID`: AWS access key
   - `AWS_SECRET_ACCESS_KEY`: AWS secret key
   - `AWS_REGION`: Deployment region (e.g., `us-east-1`)

2. **Configure Terraform Variables**:

   - Copy `infra/demo/terraform.tfvars.example` to `terraform.tfvars`
   - Update with your VPC ID and Subnet ID

3. **Trigger First Build**:
   ```bash
   gh workflow run rebuild-demo.yml
   ```

### Ongoing Operation

Once set up, the demo automatically rebuilds:

- **Nightly**: Every day at 23:59 UTC
- **On Push**: When code is pushed to `demo` branch in SiriusScan repo

## 🎭 Demo Data: Ellingson Mineral Company

The demo environment simulates a corporate network for "Ellingson Mineral Company" (a nod to Hackers, 1995):

- **IT Environment** (10.0.0.0/16): Domain controllers, file servers, web servers, workstations
- **OT Environment** (192.168.50.0/24): SCADA systems, PLCs, HMI stations
- **Total Hosts**: 12-15 hosts with realistic vulnerabilities
- **OS Mix**: Windows Server (2012-2019), Windows 10, Ubuntu, CentOS
- **Vulnerabilities**: Mix of critical, high, and medium severity CVEs

See [`fixtures/README.md`](fixtures/README.md) for complete network topology.

## 📊 Monitoring

### Rebuild Status

- **GitHub Actions**: Check workflow runs at `.github/workflows/rebuild-demo.yml`
- **Artifacts**: Seed logs and Terraform outputs available in workflow artifacts

### Demo Health

- **Health Endpoint**: `http://<demo-ip>:9001/health`
- **UI**: `http://<demo-ip>:3000`

### Troubleshooting

See [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) for common issues and solutions.

## 🔧 Configuration

### Environment Variables (Demo Mode)

The SiriusScan application detects demo mode via `DEMO_MODE=true` environment variable, which:

- Hides scan functionality
- Shows login tutorial panel with credentials
- Displays "This is a demo" banner

### Terraform Variables

Key configurable parameters in `infra/demo/variables.tf`:

- `instance_type`: EC2 instance size (default: `t3.medium`)
- `root_volume_size`: Disk size in GB (default: `30`)
- `vpc_id`, `subnet_id`: Network configuration
- `allowed_cidrs`: IP ranges allowed to access demo (default: `0.0.0.0/0`)

## 💰 Cost Estimate

**Monthly AWS costs** (approximate):

- EC2 t3.medium: ~$30-35/month
- EBS storage (30GB): ~$2.40/month
- Data transfer: ~$1-5/month
- **Total**: ~$35-45/month

## 🛠️ Development

### Testing Locally

```bash
# Test Terraform configuration
cd infra/demo
terraform init
terraform plan

# Test demo data seeding
cd ../../
./scripts/wait_for_api.sh http://localhost:9001
./scripts/seed_demo.sh http://localhost:9001
```

### Adding Demo Hosts

1. Create new fixture file in `fixtures/it-environment/` or `fixtures/ot-environment/`
2. Follow schema from existing examples
3. Add to `fixtures/index.json`
4. Test with local API: `curl -X POST http://localhost:9001/host -d @fixtures/your-new-host.json`

## 📚 Documentation

- **[Project Plan](PROJECT_PLAN.md)**: High-level overview and timeline
- **[PRD](PRD.txt)**: Detailed product requirements
- **[Runbook](docs/RUNBOOK.md)**: Operational procedures
- **[Troubleshooting](docs/TROUBLESHOOTING.md)**: Common issues and fixes
- **[Architecture](docs/ARCHITECTURE.md)**: Detailed design documentation

## 🗺️ Roadmap

### ✅ MVP (Current)

- Automated nightly rebuilds
- Demo data seeding
- Basic monitoring via GitHub Actions

### 🔜 Future Enhancements

- Slack/email notifications on failures
- TLS/HTTPS with custom domain
- Blue/green deployments (zero downtime)
- Usage analytics
- Multi-region deployments

See [Phase 8 in tasks.json](tasks/tasks.json) for complete future roadmap.

## 🤝 Contributing

This is an internal infrastructure project for SiriusScan demo. To contribute:

1. Update demo data: Add/modify fixtures in `fixtures/`
2. Improve infrastructure: Update Terraform in `infra/demo/`
3. Enhance automation: Modify GitHub Actions workflow
4. Document issues: Add to `docs/TROUBLESHOOTING.md`

## 📄 License

This infrastructure code is part of the SiriusScan project.

## 📞 Support

- **Issues**: Create GitHub issue in this repository
- **Emergency**: Contact project maintainer
- **Documentation**: See `docs/` directory

---

**Status**: 🚧 In Development  
**Last Updated**: 2025-10-01  
**Maintained By**: SiriusScan Team
