# SiriusScan Demo - Deployment Status

**Last Updated**: 2025-10-01  
**Status**: 🚧 Infrastructure Tested, Ready for Deployment

---

## ✅ Completed

### Infrastructure Code
- [x] Terraform configuration (EC2, Security Groups, IAM)
- [x] Bootstrap script (user_data.sh)
- [x] Health check script (wait_for_api.sh)
- [x] Data seeding script (seed_demo.sh)
- [x] Deployment monitoring script (monitor_demo.sh)
- [x] Terraform validated with `terraform plan`
- [x] AWS credentials configured
- [x] VPC and subnet identified

### Repository Setup
- [x] GitHub repository created: `git@github.com:SiriusScan/sirius-demo.git`
- [x] Initial project structure committed
- [x] Documentation completed (README, PRD, Project Plan)
- [x] Task breakdown (662 lines, 52 tasks)

### Testing
- [x] Terraform plan succeeded
- [x] Instance creation tested
- [x] Resource cleanup verified (terraform destroy)

---

## 🔍 Key Configuration Details

### AWS Resources
```
VPC ID:     vpc-c49ae3be
Subnet ID:  subnet-d10d7def
Region:     us-east-1
AZ:         us-east-1e (t3 instances not supported here)
```

### Instance Configuration
```
Type:        t2.small (1 vCPU, 2GB RAM)
Storage:     30GB GP3 (encrypted)
Cost:        ~$17/month (~$0.02/hour)
OS:          Ubuntu 22.04 LTS
```

### Network Access
```
Ports Allowed (0.0.0.0/0):
  - 3000 (UI)
  - 9001 (API)
  - 80 (HTTP)
  - 443 (HTTPS)
```

### Repository Configuration
```
SiriusScan Repo:  https://github.com/SiriusScan/Sirius.git
Branch:           main (temporarily, will use 'demo' branch later)
Demo Mode:        Not yet implemented (Phase 5)
```

---

## ⚠️ Known Issues & Decisions

### 1. Availability Zone Limitation
**Issue**: Subnet `subnet-d10d7def` is in `us-east-1e`, which doesn't support t3 instances  
**Decision**: Use `t2.small` instead of `t3.medium`  
**Impact**: Slightly lower performance, lower cost ($17/mo vs $30/mo)  
**Future**: Can upgrade to t3.medium by changing to different subnet in us-east-1a/b/c/d/f

### 2. Demo Branch Not Created Yet
**Issue**: Main Sirius repository doesn't have a `demo` branch  
**Current**: Using `main` branch for testing  
**Needed**: Create `demo` branch with DEMO_MODE environment variable support  
**Phase**: Addressed in Phase 5 (Demo Mode UI Enhancements)

### 3. Bootstrap Time
**Observation**: Full stack bootstrap takes 10-15 minutes  
**Breakdown**:
  - System updates: ~2 min
  - Docker installation: ~2 min
  - Repository clone: ~1 min
  - Docker image build: ~5-8 min
  - Services startup: ~2-3 min  
**Note**: This is normal for fresh deployment; rebuild cycles will be similar

---

## 📝 Pre-Deployment Checklist

Before running `terraform apply`:

- [ ] Verify AWS credentials are active
- [ ] Confirm VPC/subnet IDs in `terraform.tfvars`
- [ ] Review instance type (t2.small for us-east-1e)
- [ ] Ensure `demo` branch exists in Sirius repo (or use `main`)
- [ ] Allocate ~15 minutes for full deployment
- [ ] Plan for monitoring bootstrap progress

---

## 🚀 Quick Deployment Guide

### Deploy the Demo

```bash
cd infra/demo

# Verify configuration
terraform plan

# Deploy (creates all resources)
terraform apply -auto-approve

# Get outputs (URLs and connection info)
terraform output

# Monitor deployment progress
cd ../..
./scripts/monitor_demo.sh <public_ip>
```

**Expected Timeline**:
- Terraform apply: ~2 minutes
- Bootstrap completion: ~10-15 minutes
- Total: ~15-17 minutes until demo is accessible

### Check Deployment Status

```bash
# API health check
curl http://<public-ip>:9001/health

# UI access
open http://<public-ip>:3000
```

### Access Instance (Troubleshooting)

```bash
# Via AWS Systems Manager (no SSH key needed)
aws ssm start-session --target <instance-id> --region us-east-1

# Check bootstrap logs
sudo tail -f /var/log/sirius-bootstrap.log

# Check Docker status
sudo docker compose -f /opt/sirius/repo/docker-compose.yaml ps
sudo docker compose -f /opt/sirius/repo/docker-compose.yaml logs
```

### Destroy Demo

```bash
cd infra/demo
terraform destroy -auto-approve
```

---

## 🔮 Next Steps (Prioritized)

### Immediate (Before Next Deployment)
1. **Create Demo Branch** in main Sirius repository
2. **Test full deployment** with ~15min monitoring
3. **Verify all services** start correctly

### Phase 5: Demo Mode Features
1. Add `DEMO_MODE` environment variable support
2. Hide scan functionality in demo mode
3. Add login tutorial panel component
4. Add demo banner with GitHub link
5. Update docker-compose for demo configuration

### Phase 4: GitHub Actions CI/CD
1. Create `.github/workflows/rebuild-demo.yml`
2. Add GitHub secrets (AWS credentials)
3. Configure nightly schedule (23:59 UTC)
4. Add push trigger for `demo` branch
5. Test automated deployment

### Phase 3: Demo Data
1. Create IT environment fixtures (8-10 hosts)
2. Create OT environment fixtures (4-5 hosts)
3. Update fixtures/index.json
4. Test data seeding locally
5. Validate with deployed API

---

## 💰 Cost Tracking

### Current Configuration
- **EC2 t2.small**: $0.023/hour × 730 hours = $16.79/month
- **EBS 30GB GP3**: $0.08/GB × 30GB = $2.40/month  
- **Data Transfer**: ~$1-5/month (estimate)
- **Total Monthly**: ~$20-25/month

### Cost Optimization
- **Option 1**: Use t2.micro (free tier eligible) for testing
  - Pros: Free for 750 hours/month in first year
  - Cons: May be too small for full stack (1GB RAM)
  
- **Option 2**: Destroy when not in use
  - Run: `terraform destroy` after demo sessions
  - Rebuild: `terraform apply` when needed
  - Cost: Pay only for uptime

- **Option 3**: Scheduled startup/shutdown
  - Use AWS Lambda to stop instance overnight
  - Save ~50% of compute costs
  - Implement in future enhancement

---

## 📊 Success Metrics (Once Deployed)

### Performance Targets
- [ ] Provision + bootstrap ≤ 15 minutes (p95)
- [ ] API health responds within 2 minutes of docker-compose up
- [ ] UI loads within 5 seconds
- [ ] Demo data visible immediately after seeding

### Reliability Targets
- [ ] Terraform apply success rate: 100%
- [ ] Bootstrap success rate: >95%
- [ ] Service uptime: >99% (once stable)

### User Experience
- [ ] Demo accessible from public internet
- [ ] Login credentials visible on login page
- [ ] All demo features functional
- [ ] No scanning functionality in demo mode

---

## 🐛 Troubleshooting Guide

### Issue: Terraform Apply Fails
**Symptoms**: Errors during resource creation  
**Check**:
1. AWS credentials valid: `aws sts get-caller-identity`
2. VPC/subnet exist: `aws ec2 describe-vpcs --vpc-ids vpc-c49ae3be`
3. Instance type available: Try t2.micro instead  
**Solution**: Review error message, check AWS permissions

### Issue: Instance Boots But Services Don't Start
**Symptoms**: Instance running, but ports not responding  
**Check**:
1. Connect via SSM: `aws ssm start-session --target <instance-id>`
2. Check bootstrap log: `sudo tail -100 /var/log/sirius-bootstrap.log`
3. Check Docker: `sudo docker ps -a`  
**Common Causes**:
- Git clone failed (branch doesn't exist)
- Docker daemon not started
- Out of memory (t2.small may be tight)
- Missing environment variables in docker-compose

### Issue: Health Check Times Out
**Symptoms**: Monitoring script shows "API not ready" for >10 minutes  
**Check**:
1. Instance has public IP: Check Terraform outputs
2. Security group allows port 9001: Check AWS console
3. API container running: `sudo docker compose ps`
4. API logs: `sudo docker compose logs sirius-api`  
**Solutions**:
- Wait longer (first boot can take 15+ minutes)
- Check application logs for errors
- Verify database migrations completed

### Issue: Demo Data Seeding Fails
**Symptoms**: Seeding script returns errors  
**Check**:
1. API health returns 200: `curl http://<ip>:9001/health`
2. Fixture JSON valid: `jq empty fixtures/**/*.json`
3. API accepts host POST: Test with curl manually  
**Solutions**:
- Verify API schema matches fixtures
- Check database is accessible
- Review seeding script logs

---

## 📚 Related Documentation

- [README.md](README.md) - Project overview and quickstart
- [PROJECT_PLAN.md](PROJECT_PLAN.md) - Detailed project plan and timeline
- [PRD.txt](PRD.txt) - Product requirements document
- [docs/AWS_SETUP_GUIDE.md](docs/AWS_SETUP_GUIDE.md) - AWS configuration guide
- [tasks/tasks.json](tasks/tasks.json) - Complete task breakdown

---

## 🔄 Version History

### v0.1.0 - 2025-10-01 (Current)
- Initial infrastructure setup
- Terraform configuration validated
- Scripts created and tested
- Repository structure established
- Documentation completed
- **Status**: Ready for first deployment test

### Future Versions
- v0.2.0: First successful full deployment
- v0.3.0: Demo branch with DEMO_MODE features
- v0.4.0: GitHub Actions CI/CD
- v1.0.0: Production-ready automated demo

---

**Next Action**: Create `demo` branch in Sirius repository, then run first full deployment test

