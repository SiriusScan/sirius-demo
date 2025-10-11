# Sirius Demo Repository - Investigation Report
**Date**: October 11, 2025  
**Status**: Investigation Complete  
**Current Deployed Instance**: t2.large (i-06e56eabce9018a69)

---

## Executive Summary

This investigation identified **8 critical issues** and **12 refactoring opportunities** in the sirius-demo repository. The primary problem causing inconsistent deployments between manual and CI/CD workflows is **hardcoded instance type overrides** in the GitHub Actions workflow, which ignores the terraform.tfvars configuration.

**Key Finding**: The CI/CD workflow explicitly sets `DEMO_INSTANCE_TYPE: t2.large` at line 49 of `deploy-demo.yml`, overriding the cost-optimized `t3.small` configuration in terraform.tfvars.

---

## Critical Issues (Must Fix)

### Issue #1: Instance Type Override in CI/CD Workflow
**Severity**: 🔴 CRITICAL  
**Impact**: Cost overruns (~$35/month extra), inconsistent deployments

**Details**:
- **Location**: `.github/workflows/deploy-demo.yml` line 49
- **Problem**: Hardcoded `DEMO_INSTANCE_TYPE: t2.large` 
- **Effect**: CI/CD deploys t2.large ($70/month) instead of t3.small ($15/month)
- **Used at**:
  - Line 99: Terraform plan
  - Line 148: Terraform apply
  - Line 242: Deployment summary

**Evidence**:
```bash
# Currently running instance (deployed by CI/CD):
Instance ID: i-06e56eabce9018a69
Instance Type: t2.large
Cost: ~$0.0928/hour ($67/month)

# Expected from terraform.tfvars:
instance_type = "t3.small"
Cost: ~$0.0208/hour ($15/month)
```

**Root Cause**: Developer hardcoded instance type during testing and never updated it to match the cost-optimized configuration.

---

### Issue #2: API Health Endpoint Inconsistency
**Severity**: 🔴 CRITICAL  
**Impact**: Bootstrap script may fail silently, CI/CD checks wrong endpoint

**Details**:
- **Bootstrap script** (`user_data.sh` line 155): checks `/api/v1/health`
- **CI/CD workflows** (`deploy-demo.yml` line 173): checks `/health`
- **Health wait script** (`wait_for_api.sh` line 9): checks `/health`

**Problem**: The bootstrap script running on the instance checks a different endpoint than the CI/CD workflow validates. If the API only responds to `/api/v1/health`, the workflow will fail even though the API is actually healthy.

**Risk**: False negatives in health checks leading to failed deployments.

---

### Issue #3: Branch Name Configuration Mismatch
**Severity**: 🟠 HIGH  
**Impact**: Manual deploys may use wrong branch

**Details**:
- **terraform.tfvars**: `demo_branch = "sirius-demo"`
- **variables.tf default**: `default = "demo"`
- **Actual Sirius repo branch**: `demo` (confirmed in git config)
- **CI/CD workflow**: Uses default (doesn't override), so uses "demo"

**Problem**: 
- Manual deployments try to use non-existent "sirius-demo" branch
- CI/CD uses correct "demo" branch
- This is backwards from expected behavior

**Evidence**:
```bash
# From Sirius repo .git/config:
[branch "demo"]
    remote = origin
    merge = refs/heads/demo
```

---

### Issue #4: AWS Region Inconsistency
**Severity**: 🟠 HIGH  
**Impact**: Resources may be created in wrong region, confusion

**Details**:
- **terraform.tfvars**: `aws_region = "us-west-2"` ✅
- **variables.tf default**: `default = "us-east-1"` ❌
- **Workflows**: Hardcoded `us-west-2` ✅
- **Documentation**: Mixed (some say us-east-1, some us-west-2)
- **Cleanup script**: Hardcoded `us-west-2` ✅

**Problem**: Default region in variables.tf doesn't match actual deployment region. If someone uses defaults, resources will be created in wrong region.

**Affected Files**:
- `infra/demo/main.tf` line 15 (commented backend config uses us-east-1)
- `docs/AWS_SETUP_GUIDE.md` (examples use us-east-1)
- `QUICKSTART.md` (references us-east-1)

---

### Issue #5: Hardcoded VPC/Subnet in Cleanup Script
**Severity**: 🟡 MEDIUM  
**Impact**: Cleanup fails if infrastructure changes

**Details**:
- **Location**: `scripts/cleanup-aws-resources.sh` line 92
- **Problem**: Hardcoded `vpc-416eeb39` in security group cleanup
- **Risk**: If VPC ID changes, cleanup will fail to find security groups

**Code**:
```bash
SG_IDS=$(aws ec2 describe-security-groups --region us-west-2 \
    --filters "Name=group-name,Values=sirius-demo-sg*" "Name=vpc-id,Values=vpc-416eeb39" \
    --query 'SecurityGroups[].GroupId' --output text 2>/dev/null || echo "")
```

---

### Issue #6: Terraform Backend Not Enabled
**Severity**: 🟡 MEDIUM  
**Impact**: No state locking, risk of concurrent modification

**Details**:
- **Location**: `infra/demo/main.tf` lines 11-18
- **Problem**: S3 backend configuration is commented out
- **Risk**: 
  - State file stored locally only
  - No state locking with DynamoDB
  - Can't share state across team/CI
  - Concurrent terraform runs will corrupt state

**Note**: The PRD and documentation mention remote state as a requirement, but it's not implemented.

---

### Issue #7: Missing Elastic IP in Terraform Outputs
**Severity**: 🟡 MEDIUM  
**Impact**: DNS update script can't find elastic IP automatically

**Details**:
- **DNS update step** (line 202): `ELASTIC_IP="${{ steps.deploy.outputs.elastic_ip }}"`
- **Terraform outputs**: `elastic_ip` is defined ✅
- **Problem**: Output variable name doesn't match between Terraform and workflow

**Current Status**: EIP query failed in AWS CLI test (list index out of range error), suggesting EIP might not be properly tagged or created.

---

### Issue #8: Instance Type Naming Inconsistency
**Severity**: 🟡 MEDIUM  
**Impact**: Confusion, harder to maintain

**Details**:
- **terraform.tfvars**: Uses `t3.small` (current generation)
- **README.md**: Documents `t2.large` (previous generation)
- **Workflow**: Uses `t2.large` (previous generation)
- **DEPLOYMENT_STATUS.md**: Shows `t2.large` was tested

**Problem**: Mix of t2 and t3 instance families creates confusion. T3 is newer and more cost-effective.

---

## Documentation Issues

### Issue #9: Outdated README
**Severity**: 🟡 MEDIUM

**Problems**:
- Line 176: Shows `DEMO_INSTANCE_TYPE=t2.large` instead of t3.small
- Line 187: Documents `instance_type = "t2.large"` instead of t3.small
- Line 279: References t3.medium but actual is t3.small
- Cost estimates outdated (based on t3.medium instead of t3.small)

### Issue #10: Misleading DEPLOYMENT_STATUS.md
**Severity**: 🟢 LOW

**Problems**:
- Last updated October 4, 2025 but instance was deployed October 11, 2025
- Documents old instance ID `i-01a10dda69737c405`
- Should be updated to current instance `i-06e56eabce9018a69`

### Issue #11: Example Config Mismatches Reality
**Severity**: 🟢 LOW

**Problems**:
- `terraform.tfvars.example`: Shows placeholder values but actual tfvars has real values
- Could cause confusion when setting up new environments
- Example shows `demo` branch but actual uses `sirius-demo`

---

## Refactoring Opportunities

### Opportunity #1: Centralize Configuration
**Priority**: 🔴 HIGH  
**Effort**: 2 hours

**Problem**: Configuration scattered across multiple files with inconsistencies.

**Solution**: Create a single source of truth configuration file:
```yaml
# config/demo-config.yaml
aws:
  region: us-west-2
  vpc_id: vpc-416eeb39
  subnet_id: subnet-d31ffe8e

instance:
  type: t3.small
  volume_size: 20

repository:
  url: https://github.com/SiriusScan/Sirius.git
  branch: demo

api:
  health_endpoint: /api/v1/health
  port: 9001
```

Use this in:
- Terraform via data source
- Workflows via yaml parsing
- Scripts via yaml parsing

---

### Opportunity #2: Parameterize Workflows
**Priority**: 🔴 HIGH  
**Effort**: 1 hour

**Current Problem**: Workflows have hardcoded values.

**Solution**: Add workflow inputs for all key parameters:
```yaml
workflow_dispatch:
  inputs:
    instance_type:
      description: 'EC2 instance type'
      required: false
      default: 't3.small'
    aws_region:
      description: 'AWS region'
      required: false
      default: 'us-west-2'
    branch:
      description: 'Sirius branch to deploy'
      required: false
      default: 'demo'
```

---

### Opportunity #3: Environment-Specific Configs
**Priority**: 🟠 MEDIUM  
**Effort**: 3 hours

**Problem**: Same config for all environments (dev/staging/prod).

**Solution**: Create environment-specific tfvars:
```
infra/demo/
  ├── environments/
  │   ├── dev.tfvars      (t3.micro for cost savings)
  │   ├── staging.tfvars  (t3.small)
  │   └── prod.tfvars     (t3.medium for performance)
```

---

### Opportunity #4: Unified Health Check Script
**Priority**: 🟠 MEDIUM  
**Effort**: 2 hours

**Problem**: Health check logic duplicated in 3 places with inconsistencies.

**Solution**: Create single `scripts/health-check.sh` that:
- Accepts API URL as parameter
- Checks both `/health` and `/api/v1/health`
- Returns clear exit codes
- Logs detailed information
- Used by: user_data.sh, workflows, monitoring

---

### Opportunity #5: Terraform Modules
**Priority**: 🟡 MEDIUM  
**Effort**: 4 hours

**Problem**: Monolithic main.tf file, hard to reuse.

**Solution**: Break into modules:
```
infra/
  ├── modules/
  │   ├── compute/         (EC2, EIP)
  │   ├── networking/      (SG)
  │   ├── iam/             (roles, policies)
  │   └── monitoring/      (CloudWatch)
  └── demo/
      └── main.tf          (composes modules)
```

---

### Opportunity #6: Pre-commit Hooks
**Priority**: 🟡 MEDIUM  
**Effort**: 2 hours

**Solution**: Add pre-commit hooks to catch issues:
- Terraform format validation
- Terraform validate
- Check for hardcoded values (grep for vpc-416eeb39, etc.)
- Verify tfvars matches example
- Check documentation is up to date

---

### Opportunity #7: Configuration Validation
**Priority**: 🟡 MEDIUM  
**Effort**: 3 hours

**Solution**: Add `scripts/validate-config.sh` that:
- Checks all config files for consistency
- Validates instance types are correct generation
- Ensures endpoints match across all files
- Verifies branch names exist
- Checks AWS resources exist before deployment

---

### Opportunity #8: Automated Documentation Updates
**Priority**: 🟢 LOW  
**Effort**: 4 hours

**Solution**: Script to auto-update docs from terraform outputs:
- Update DEPLOYMENT_STATUS.md after each deploy
- Generate cost estimates from instance types
- Update README with current values

---

### Opportunity #9: Cost Monitoring
**Priority**: 🟢 LOW  
**Effort**: 3 hours

**Solution**: Add CloudWatch billing alerts and dashboard:
- Alert when demo costs exceed $30/month
- Dashboard showing cost trends
- Automatic cleanup of old resources

---

### Opportunity #10: Testing Framework
**Priority**: 🟢 LOW  
**Effort**: 6 hours

**Solution**: Add terratest or similar:
- Test terraform plans before apply
- Validate health checks work
- Test cleanup scripts
- Verify DNS updates work

---

### Opportunity #11: Improve Error Handling
**Priority**: 🟡 MEDIUM  
**Effort**: 2 hours

**Problem**: Scripts continue on errors, unclear failure messages.

**Solution**: 
- Add better error messages to all scripts
- Implement proper logging levels (INFO, WARN, ERROR)
- Add rollback logic for failed deployments
- Send notifications on failures (Slack/email)

---

### Opportunity #12: Secrets Management
**Priority**: 🟠 MEDIUM  
**Effort**: 4 hours

**Problem**: No secrets management, relying on GitHub secrets only.

**Solution**: Use AWS Parameter Store or Secrets Manager:
- Store DB passwords, API keys centrally
- Rotate secrets automatically
- Audit secret access
- Reference in user_data.sh via AWS CLI

---

## Repository Quality Issues

### Issue #12: Inconsistent File Naming
- Some files use underscore: `user_data.sh`, `wait_for_api.sh`
- Some use dash: `cleanup-aws-resources.sh`, `update-dns.sh`
- Should standardize on one convention

### Issue #13: Mixed Documentation Quality
- README.md is comprehensive but outdated
- DEPLOYMENT_STATUS.md has old information
- PRD.txt is detailed but never updated
- PROJECT_PLAN.md is comprehensive but doesn't reflect reality
- Multiple sources of truth create confusion

### Issue #14: No Version Tracking
- No semantic versioning
- No CHANGELOG (exists but not maintained)
- Hard to track what changed when
- Can't rollback to known-good configuration

### Issue #15: Missing Monitoring
- No CloudWatch dashboards
- No automated alerts
- No metrics collection
- No uptime monitoring
- Have to manually check if demo is working

---

## Priority Action Plan

### Phase 1: Critical Fixes (Must Do Now)
**Estimated Time**: 3-4 hours

1. **Fix instance type in workflow** (30 min)
   - Change line 49 in deploy-demo.yml: `DEMO_INSTANCE_TYPE: t3.small`
   - Verify in lines 99, 148, 242

2. **Fix API health endpoint consistency** (1 hour)
   - Determine correct endpoint from Sirius repo
   - Update all files to use same endpoint
   - Test both bootstrap and workflows

3. **Fix branch name configuration** (30 min)
   - Update terraform.tfvars: `demo_branch = "demo"`
   - Update terraform.tfvars.example to match
   - Document actual branch name

4. **Fix region consistency** (30 min)
   - Update variables.tf default to us-west-2
   - Update all documentation to us-west-2
   - Remove us-east-1 references

5. **Deploy new instance with fixes** (1 hour)
   - Test manual deployment
   - Test CI/CD deployment
   - Verify both use t3.small
   - Verify health checks work
   - Document in DEPLOYMENT_STATUS.md

### Phase 2: Important Improvements (Should Do Soon)
**Estimated Time**: 8-10 hours

6. **Remove hardcoded values** (2 hours)
   - Parameterize VPC/subnet in cleanup script
   - Make workflows use tfvars
   - Create config validation script

7. **Enable Terraform remote state** (2 hours)
   - Create S3 bucket for state
   - Create DynamoDB table for locking
   - Update main.tf to use backend
   - Test state locking works

8. **Update all documentation** (2 hours)
   - Update README with correct values
   - Update DEPLOYMENT_STATUS after each deploy
   - Clean up outdated documentation
   - Create single source of truth

9. **Add configuration validation** (2 hours)
   - Create validate-config.sh script
   - Add to pre-commit hooks
   - Run in CI/CD before deploy

10. **Improve error handling** (2 hours)
    - Better error messages in scripts
    - Add rollback logic
    - Implement notifications

### Phase 3: Refactoring (Nice to Have)
**Estimated Time**: 15-20 hours

11. **Centralize configuration** (3 hours)
12. **Environment-specific configs** (3 hours)
13. **Terraform modules** (4 hours)
14. **Testing framework** (6 hours)
15. **Monitoring and alerting** (4 hours)

---

## Cost Impact Analysis

### Current State (CI/CD Deployments)
```
Instance Type: t2.large
vCPU: 2
RAM: 8GB
Cost: $0.0928/hour
Monthly: $67.74/month (24/7)
```

### Expected State (After Fix)
```
Instance Type: t3.small
vCPU: 2
RAM: 2GB
Cost: $0.0208/hour
Monthly: $15.18/month (24/7)
```

### Savings
```
Monthly savings: $52.56 (77% reduction)
Annual savings: $630.72
```

### Additional Considerations
- t3.small sufficient for demo workload (current usage ~800MB RAM)
- T3 instances have better CPU performance than T2
- Burstable performance adequate for demo traffic
- Can scale up if needed

---

## Risk Assessment

### High Risk Issues
1. **Instance type override**: Continuing to deploy expensive instances
2. **Health check mismatch**: May miss real deployment failures
3. **No state locking**: Risk of state corruption

### Medium Risk Issues
4. **Branch name mismatch**: Manual deploys may fail
5. **Region inconsistency**: Resources in wrong region
6. **Hardcoded values**: Brittle infrastructure

### Low Risk Issues
7. **Documentation outdated**: Causes confusion but not failure
8. **Missing monitoring**: Won't catch issues early

---

## Recommendations

### Immediate Actions (This Week)
1. ✅ Complete this investigation (DONE)
2. 🔲 Fix instance type in workflow
3. 🔲 Fix API health endpoint
4. 🔲 Fix branch configuration
5. 🔲 Deploy and verify fixes work

### Short Term (Next 2 Weeks)
6. 🔲 Enable Terraform remote state
7. 🔲 Remove hardcoded values
8. 🔲 Update all documentation
9. 🔲 Add configuration validation

### Medium Term (Next Month)
10. 🔲 Centralize configuration
11. 🔲 Create environment-specific configs
12. 🔲 Improve error handling and monitoring
13. 🔲 Add testing framework

### Long Term (Next Quarter)
14. 🔲 Refactor to Terraform modules
15. 🔲 Implement comprehensive monitoring
16. 🔲 Add automated testing
17. 🔲 Set up proper secrets management

---

## Conclusion

The sirius-demo repository has **functional infrastructure** but suffers from **poor configuration management** and **inconsistent implementation**. The primary issue causing the reported problem (t2.large vs t3.small) is a simple hardcoded value in the GitHub Actions workflow that was never updated.

However, the investigation revealed numerous other issues that, while not immediately breaking, create technical debt and increase the risk of future problems. The repository was clearly built incrementally without proper planning, leading to duplicated logic, inconsistent configurations, and outdated documentation.

**Recommended Approach**: Fix the critical issues immediately (Phase 1), then systematically address the refactoring opportunities over the next month (Phases 2-3). This will transform the repository from a "sloppy prototype" into a production-ready infrastructure-as-code project.

**Estimated Total Effort**: 26-34 hours across all phases
**Return on Investment**: $630/year in cost savings + reduced maintenance burden + improved reliability

---

**Next Steps**: Review this report, prioritize fixes based on business needs, and create a task tracking system to implement the recommended changes systematically.

