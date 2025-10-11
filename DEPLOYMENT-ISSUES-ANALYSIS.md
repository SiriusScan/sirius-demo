# Deployment Issues - Complete Analysis

**Date**: October 11, 2025  
**Instance**: `i-06c5e1e449c2e0219` (t3.small)  
**Status**: Running but services non-functional

---

## 🎯 Executive Summary

The demo instance deployed successfully but **services failed to start** due to a Docker build failure in the main Sirius repository. Additionally, SSH access was not properly configured, and DNS is pointing to an old IP address.

---

## 🔍 Investigation Findings

### ✅ What's Working

1. **Instance Deployment**

   - Instance `i-06c5e1e449c2e0219` is running
   - Type: `t3.small` (correct - cost-optimized)
   - Region: `us-west-2` (correct)
   - Security group allows ports: 80, 443, 3000, 9001

2. **Elastic IP Configuration**

   - EIP `44.254.118.59` is properly allocated
   - EIP is correctly associated with the instance
   - **Elastic IP WAS working** - this was NOT the issue

3. **Terraform State Management**
   - Remote state (S3) is functioning
   - State file: `sirius-demo-tfstate-463192224457/demo/terraform.tfstate`
   - DynamoDB locking table: `sirius-demo-tflock`

### ❌ Critical Issues

#### **Issue #1: Docker Build Failure (PRIMARY)**

**Severity**: 🔴 **CRITICAL - Services Cannot Start**

**Error from Console Logs**:

```
go: github.com/SiriusScan/go-api@v0.0.9 (replaced by ../go-api):
reading ../go-api/go.mod: open /repos/go-api/go.mod: no such file or directory

target sirius-engine: failed to solve: exit code: 1
Cloud-init v. 25.2 failed at Sat, 11 Oct 2025 22:50:39 +0000
```

**Root Cause**: The `demo` branch in the main Sirius repository has a Docker build configuration that expects `../go-api` to exist as a local directory during the build process. This appears to be a **repository structure issue** where:

1. The Dockerfile has a local path replacement for `go-api`
2. The path doesn't exist in the cloned repository structure
3. The go module download fails
4. The entire Docker Compose stack never starts

**Impact**:

- ❌ No API service on port 9001
- ❌ No UI service on port 3000
- ❌ Health checks fail after 20 minutes
- ❌ CI/CD deployment marks as failed

**Location of Problem**:

- **Repository**: `https://github.com/SiriusScan/Sirius.git`
- **Branch**: `demo`
- **File**: Likely `Dockerfile` or `docker-compose.yaml` in the demo branch
- **Issue**: Incorrect module path or missing repository in build context

---

#### **Issue #2: SSH Access Not Configured**

**Severity**: 🟡 **HIGH - Troubleshooting Impossible**

**Current State**:

- ✅ SSH public key IS defined in `terraform.tfvars`
- ❌ SSH key pair NOT created in AWS (`sirius-demo-key` does not exist)
- ❌ Port 22 NOT open in security group
- ❌ Instance has no SSH key associated

**Root Cause**: Even though `public_key` is set in `terraform.tfvars`, the Terraform configuration uses a conditional resource:

```hcl
resource "aws_key_pair" "demo" {
  count      = var.public_key != "" ? 1 : 0
  ...
}
```

**Possible Causes**:

1. The variable wasn't properly passed during the CI/CD deployment
2. The destroy/apply cycle didn't pick up the variable
3. Workflow doesn't pass the public_key variable to Terraform

**Impact**:

- ❌ Cannot SSH into instance for troubleshooting
- ❌ Cannot inspect Docker logs directly
- ❌ Cannot manually restart services
- ⚠️ Must rely on AWS Systems Manager (Session Manager) for access

**Workaround**: AWS Systems Manager Session Manager is available (IAM role attached), but less convenient than SSH.

---

#### **Issue #3: DNS Pointing to Wrong IP**

**Severity**: 🟡 **MEDIUM - Public Access Broken**

**Current State**:

- Domain: `sirius.opensecurity.com`
- DNS resolves to: `44.224.189.56` (old/unknown IP)
- Should resolve to: `44.254.118.59` (current EIP)

**Root Cause**: The CI/CD workflow's "Update DNS" step never ran because the health checks failed.

**Impact**:

- ❌ Public domain doesn't point to current instance
- ❌ Users cannot access demo at expected URL
- ❌ Old IP address may not exist or be accessible

**Fix Required**: Update DNS A record to point to `44.254.118.59`

---

#### **Issue #4: 35.95.205.55 Mystery IP**

**Status**: This IP is **NOT** in the us-west-2 AWS account. Possible explanations:

1. Old Elastic IP that was released
2. IP from a different AWS region
3. IP from a different AWS account
4. Misremembered or outdated documentation

**Action**: Ignore this IP - it's not relevant to current deployment.

---

## 🛠️ Required Fixes

### **Priority 1: Fix Docker Build (Blocks Everything)**

**Option A: Fix the Demo Branch** (Recommended)

1. Investigate the `demo` branch in Sirius repository
2. Fix the go-api module path issue
3. Ensure `../go-api` is available or update the module replacement
4. Test Docker build locally before pushing

**Option B: Use Main Branch** (Temporary Workaround)

1. Change `demo_branch` from `demo` to `main` in terraform.tfvars
2. Redeploy
3. Risk: main branch may have unstable features

**Option C: Fix Build Context**

1. Clone go-api repository alongside Sirius in user_data.sh
2. Update Docker build context to include both repositories
3. More complex but maintains separation

**Investigation Needed**:

```bash
# Check the demo branch Dockerfile
git clone https://github.com/SiriusScan/Sirius.git
cd Sirius
git checkout demo
cat Dockerfile  # Look for go-api references
cat docker-compose.yaml  # Check build contexts
```

---

### **Priority 2: Enable SSH Access**

**Fix Options**:

**Option A: Add to Workflow** (Recommended for CI/CD)
Add to `.github/workflows/deploy-demo.yml`:

```yaml
- name: Deploy new infrastructure
  run: |
    terraform -chdir=infra/demo apply \
      -var="public_key=${{ secrets.DEMO_SSH_PUBLIC_KEY }}" \
      -var="vpc_id=vpc-416eeb39" \
      ...
```

Then add `DEMO_SSH_PUBLIC_KEY` as a GitHub secret.

**Option B: Use Terraform Variables File**
The `terraform.tfvars` already has the key, but ensure it's being used:

```bash
# Manual deployment should work
terraform apply  # Uses terraform.tfvars automatically
```

**Option C: Use SSM Session Manager** (Current Workaround)

```bash
# Access instance without SSH
aws ssm start-session --target i-06c5e1e449c2e0219 --region us-west-2
```

---

### **Priority 3: Fix DNS**

**Manual Fix**:

1. Log into DNS provider (likely Route53 or domain registrar)
2. Update A record for `sirius.opensecurity.com`
3. Change from `44.224.189.56` to `44.254.118.59`
4. Wait for DNS propagation (5-30 minutes)

**Automated Fix**: The workflow has a "Update DNS" step that should handle this, but it only runs after successful health checks.

---

## 🔧 Immediate Troubleshooting Steps

### **Step 1: Access Instance via SSM**

```bash
aws ssm start-session --target i-06c5e1e449c2e0219 --region us-west-2
```

### **Step 2: Check Docker Status**

```bash
# Once in SSM session
sudo su - ubuntu
cd /home/ubuntu/Sirius  # Or wherever repo was cloned
docker compose ps
docker compose logs sirius-engine | tail -100
docker compose logs sirius-api | tail -100
```

### **Step 3: Inspect Cloud-Init Logs**

```bash
sudo cat /var/log/cloud-init-output.log | tail -200
sudo journalctl -u cloud-final.service
```

### **Step 4: Check Repository**

```bash
cd /home/ubuntu
ls -la  # See what was cloned
cd Sirius
git branch  # Confirm we're on demo branch
cat docker-compose.yaml  # Check configuration
```

---

## 📋 Recommended Action Plan

### **Phase 1: Immediate Diagnosis** (Use current running instance)

1. **Access via SSM**: Use Session Manager to access the instance
2. **Inspect Docker logs**: Confirm the exact build failure
3. **Check repository state**: Verify what branch and files are present
4. **Document findings**: Understand the exact go-api path issue

### **Phase 2: Fix Repository Issues** (Work in Sirius repository)

1. **Clone and checkout demo branch**
2. **Identify the go-api dependency issue**
3. **Fix the Dockerfile/docker-compose.yaml**
4. **Test build locally**: `docker compose build`
5. **Push fix to demo branch**

### **Phase 3: Enable SSH for Future Troubleshooting**

1. **Add SSH key to workflow secrets**
2. **Update deploy-demo.yml to pass public_key variable**
3. **Test SSH access after next deployment**

### **Phase 4: Redeploy with Fixes**

1. **Trigger new deployment**: `gh workflow run deploy-demo.yml`
2. **Monitor health checks**: Should pass this time
3. **Verify DNS update**: Workflow should update DNS automatically
4. **Test public access**: http://sirius.opensecurity.com:3000

### **Phase 5: Update DNS (If still needed)**

1. **Manual DNS update if automated step didn't run**
2. **Test access via domain name**

---

## 💡 Lessons Learned & Future Improvements

### **Repository Structure**

- The `demo` branch has diverged too much from `main`
- Consider using Docker build args instead of path replacements
- Document the expected repository structure for builds

### **SSH Access**

- SSH should be enabled by default for demo environments
- Add clear documentation about SSH key configuration
- Consider using AWS Systems Manager as primary access method

### **Health Checks**

- 20 minutes may not be long enough for t3.small builds
- Consider increasing timeout or optimizing Docker build
- Add intermediate health checks (Docker started? Logs accessible?)

### **DNS Management**

- Automate DNS updates more reliably
- Consider using Route53 with Terraform for full automation
- Add DNS validation step after updates

### **State Management**

- Remote state is now working correctly
- Document the state lock troubleshooting (force-unlock)
- Add state backup strategy

---

## 🎯 Success Criteria

Deployment will be successful when:

- ✅ Docker Compose builds without errors
- ✅ All services start and pass health checks
- ✅ API responds at http://44.254.118.59:9001/health
- ✅ UI responds at http://44.254.118.59:3000
- ✅ DNS points to correct IP (44.254.118.59)
- ✅ Public access works at http://sirius.opensecurity.com:3000
- ✅ SSH access enabled for troubleshooting
- ✅ Workflow completes without errors

---

## 📞 Next Steps

**Immediate**: Use SSM to access the instance and diagnose the exact Docker build issue

**Short-term**: Fix the go-api path issue in the demo branch and enable SSH

**Long-term**: Improve the demo branch stability and CI/CD robustness
