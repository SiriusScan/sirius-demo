# SiriusScan Demo — Automated Infrastructure as Code

[![Deploy Demo](https://github.com/SiriusScan/sirius-demo/actions/workflows/deploy-demo.yml/badge.svg)](https://github.com/SiriusScan/sirius-demo/actions/workflows/deploy-demo.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Automated demo deployment of [SiriusScan](https://github.com/SiriusScan/Sirius) on AWS EC2 using Terraform, GitHub Actions, and prebuilt container images from the GitHub Container Registry (GHCR).

## Live Demo

| Service | URL |
|---------|-----|
| UI | http://sirius.opensecurity.com:3000 |
| API | http://sirius.opensecurity.com:9001 |
| Health | http://sirius.opensecurity.com:9001/health |

## How It Works

The demo pulls **prebuilt, multi-arch Docker images** from `ghcr.io/siriusscan/*` — it never clones the main Sirius repo or builds from source.

### Deployment Strategies

| Strategy | When | Time |
|----------|------|------|
| **Fast update** | Existing instance is healthy (canary dispatch, push to main) | ~2 min |
| **Full deploy** | No instance / unhealthy / scheduled / force-rebuild | ~10 min |

**Fast update** sends an SSM command to the running instance: `docker compose pull && up -d`.
**Full deploy** tears down the EC2 instance with Terraform and recreates it from scratch.

### Trigger Flow

```
Push to Sirius main
  → CI builds images → pushes to GHCR
  → repository_dispatch to sirius-demo (via DEMO_DISPATCH_TOKEN)
  → Preflight checks existing instance health
  → Fast update (if healthy) or Full deploy (if not)
  → Health check → Seed demo data
```

## Repository Structure

```
sirius-demo/
├── .github/workflows/
│   ├── deploy-demo.yml          # Main deployment (fast update + full deploy)
│   ├── monitor-demo.yml         # Health monitoring (every 2 hours)
│   ├── cleanup.yml              # Resource cleanup
│   └── test-deployment.yml      # PR validation
├── infra/demo/
│   ├── main.tf                  # EC2, SG, IAM, EIP
│   ├── variables.tf             # Terraform variables
│   ├── outputs.tf               # Instance ID, IP, URLs
│   └── user_data.sh             # Bootstrap: Docker + pull images
├── docker-compose.demo.yml      # Standalone compose (GHCR images)
├── scripts/
│   ├── seed_demo.sh             # Seed data (authenticated)
│   ├── cleanup-aws-resources.sh # AWS teardown
│   ├── update-dns.sh            # Route 53 updates
│   └── ...
├── fixtures/                    # Demo data fixtures
│   ├── index.json
│   └── ...
└── docs/
    ├── DNS_SETUP_GUIDE.md
    └── AWS_ACCESS_KEYS_SETUP.md
```

## Key Design Decisions

### Pull-based deployment (no source clone)

The `user_data.sh` bootstrap script:
1. Installs Docker
2. Clones **only this demo repo** (for the compose file and fixtures)
3. Generates random secrets (`SIRIUS_API_KEY`, `NEXTAUTH_SECRET`, `INITIAL_ADMIN_PASSWORD`, `POSTGRES_PASSWORD`)
4. Runs `docker compose -f docker-compose.demo.yml pull` then `up -d`

### Secrets generated at boot

Every fresh deploy generates unique secrets via `openssl rand`. No hardcoded passwords, no committed `.env` files. The API key is retrieved from the instance via SSM for data seeding.

### Authentication-aware seeding

`seed_demo.sh` sends `X-API-Key` headers on all API calls, matching the v1 API's authentication requirements.

## Deploy Your Own

### Prerequisites

- AWS account with EC2, S3, DynamoDB, Route 53 access
- GitHub repo secrets configured (see below)
- `DEMO_DISPATCH_TOKEN` PAT in the main Sirius repo (for cross-repo dispatch)

### Required GitHub Secrets

| Secret | Purpose |
|--------|---------|
| `AWS_ACCESS_KEY_ID` | AWS programmatic access |
| `AWS_SECRET_ACCESS_KEY` | AWS programmatic access |
| `DEMO_SSH_PUBLIC_KEY` | SSH access to EC2 instance (optional) |

### Manual Deploy

```bash
# Via GitHub Actions
gh workflow run deploy-demo.yml

# Skip seeding
gh workflow run deploy-demo.yml --field skip_seeding=true

# Force full rebuild
gh workflow run deploy-demo.yml --field force_rebuild=true

# Deploy specific image tag
gh workflow run deploy-demo.yml --field image_tag=v0.5.0
```

### Terraform (direct)

```bash
cd infra/demo
terraform init
terraform apply \
  -var="vpc_id=vpc-XXXXX" \
  -var="subnet_id=subnet-XXXXX" \
  -var="image_tag=latest"
```

## Infrastructure

| Component | Details |
|-----------|---------|
| Compute | EC2 `t3.small` (2 vCPU, 2 GB RAM) |
| Storage | 30 GB gp3 EBS |
| Networking | Public subnet, SG (ports 3000, 9001, 80, 443) |
| Static IP | Elastic IP (`44.224.189.56`) |
| DNS | Route 53 A record → `sirius.opensecurity.com` |
| Access | SSM Session Manager (no SSH required) |
| State | S3 + DynamoDB lock |

### Estimated Monthly Cost

~$15–20/month (t3.small running 24/7 + EBS + Route 53).

## Monitoring

The `monitor-demo.yml` workflow runs every 2 hours:
- Checks API `/health` and UI availability
- Reports instance type, uptime, and state
- Auto-creates a GitHub issue on health failures

## Troubleshooting

```bash
# SSM into the instance
aws ssm start-session --target <instance-id> --region us-west-2

# Check services
cd /opt/sirius/demo
docker compose -f docker-compose.demo.yml ps
docker compose -f docker-compose.demo.yml logs --tail=50

# Check bootstrap log
tail -200 /var/log/sirius-bootstrap.log

# View generated secrets
cat /opt/sirius/demo/.env
```

## Related

- [SiriusScan](https://github.com/SiriusScan/Sirius) — main repository
- [DNS Setup Guide](docs/DNS_SETUP_GUIDE.md)
- [AWS Access Keys Setup](docs/AWS_ACCESS_KEYS_SETUP.md)

---

*Last updated: February 2026*
