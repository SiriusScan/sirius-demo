# SiriusScan Demo - Quick Start Guide

> **Status**: Infrastructure ready, tested, and committed. Ready for first deployment.

## 🎯 What This Is

Automated AWS infrastructure that rebuilds the SiriusScan demo environment on schedule and code changes.

**Repository**: https://github.com/SiriusScan/sirius-demo

---

## ⚡ Quick Deploy (First Time)

```bash
# 1. Navigate to Terraform directory
cd infra/demo

# 2. Review configuration
cat terraform.tfvars

# 3. Deploy infrastructure
terraform apply -auto-approve

# 4. Monitor deployment (~15 minutes)
cd ../..
./scripts/monitor_demo.sh $(terraform -chdir=infra/demo output -raw instance_public_ip)
```

**Access Demo** (after ~15 minutes):
- **UI**: http://[public-ip]:3000
- **API**: http://[public-ip]:9001/health

---

## 🧹 Clean Up (Save Costs)

```bash
cd infra/demo
terraform destroy -auto-approve
```

**Cost Savings**: Destroys ~$0.02/hour in AWS resources

---

## 📋 Current Configuration

### AWS Resources
- **Instance**: t2.small (1 vCPU, 2GB RAM)
- **Region**: us-east-1
- **Cost**: ~$17/month if left running
- **VPC**: vpc-c49ae3be
- **Subnet**: subnet-d10d7def

### SiriusScan Configuration
- **Repository**: https://github.com/SiriusScan/Sirius.git  
- **Branch**: main (temporarily, until `demo` branch exists)
- **Services**: UI, API, Engine, PostgreSQL, RabbitMQ, Valkey

---

## ⏭️ What's Next

### Before Production Deployment
1. **Create demo branch** in main Sirius repository
   ```bash
   cd /path/to/Sirius
   git checkout -b demo
   git push -u origin demo
   ```

2. **Update terraform.tfvars** to use demo branch
   ```bash
   demo_branch = "demo"
   ```

3. **Add DEMO_MODE features** (Phase 5)
   - Environment variable support
   - Hide scan functionality
   - Add login tutorial panel
   - Add demo banner

### For Automated Rebuilds
4. **Add GitHub secrets**:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_REGION`

5. **Create GitHub Actions workflow** (Phase 4)
   - See `tasks/tasks.json` Phase 4 for details

6. **Create demo data fixtures** (Phase 3)
   - IT environment hosts
   - OT environment hosts
   - See `fixtures/README.md` for guidance

---

## 📖 Documentation

- [DEPLOYMENT_STATUS.md](DEPLOYMENT_STATUS.md) - Current deployment status and troubleshooting
- [PROJECT_PLAN.md](PROJECT_PLAN.md) - Complete project plan and roadmap
- [README.md](README.md) - Full documentation and architecture
- [tasks/tasks.json](tasks/tasks.json) - Detailed task breakdown (52 tasks)

---

## 🆘 Troubleshooting

### Instance not responding after 15 minutes

```bash
# Check bootstrap logs
aws ssm start-session --target <instance-id> --region us-east-1

# On instance:
sudo tail -f /var/log/sirius-bootstrap.log
sudo docker compose -f /opt/sirius/repo/docker-compose.yaml ps
sudo docker compose -f /opt/sirius/repo/docker-compose.yaml logs
```

### Terraform errors

```bash
# Verify AWS credentials
aws sts get-caller-identity

# Check AWS resources exist
aws ec2 describe-vpcs --vpc-ids vpc-c49ae3be
aws ec2 describe-subnets --subnet-ids subnet-d10d7def
```

### Demo branch doesn't exist

Update `infra/demo/terraform.tfvars`:
```
demo_branch = "main"  # Use main until demo branch is created
```

---

## 💡 Tips

- **First deployment takes longest** (~15 min) due to Docker image builds
- **Subsequent deployments** will be faster with cached images
- **Monitor costs** in AWS Cost Explorer with tag filter: `Project=SiriusDemo`
- **Use SSM Session Manager** instead of SSH (no keys needed)
- **Check DEPLOYMENT_STATUS.md** for latest configuration details

---

**Ready to deploy?** Run `terraform apply` from `infra/demo/` directory! 🚀

