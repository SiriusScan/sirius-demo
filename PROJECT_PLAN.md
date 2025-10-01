# SiriusScan Demo Infrastructure - Project Plan

## Executive Summary

**Project Name**: SiriusScan Continuous Demo Rebuild  
**Timeline**: ~3-4 weeks (MVP)  
**Team Size**: 1-2 developers + stakeholder (Matt)  
**Budget**: ~$60-80/month AWS costs (t3.medium)

### Project Goal

Create a fully automated, continuously rebuilt demo environment for SiriusScan on AWS EC2 that:

- Rebuilds nightly at 23:59 UTC and on every push to `demo` branch
- Uses Infrastructure as Code (Terraform) for complete reproducibility
- Seeds realistic corporate demo data ("Ellingson Mineral Company")
- Provides publicly accessible demo with special UI features
- Validates deployment integrity through CI/CD pipeline

---

## Architecture Overview

### Repository Strategy

- **sirius-demo** (new repo): Infrastructure code, seeding scripts, demo fixtures, CI/CD workflows
- **SiriusScan** (existing repo): Application code with `demo` branch for demo-specific configurations

### Technology Stack

- **Infrastructure**: AWS EC2 (t3.medium), Terraform, GitHub Actions OIDC
- **Application**: Docker Compose stack (UI, API, Engine, PostgreSQL, RabbitMQ, Valkey)
- **CI/CD**: GitHub Actions with scheduled and event-driven triggers
- **Monitoring**: CloudWatch Logs, GitHub Actions artifacts, SSM Session Manager

### Demo Environment Specifications

- **Instance**: t3.medium (2 vCPU, 4GB RAM, 30GB disk)
- **Region**: us-east-1 (configurable)
- **Network**: Public subnet with Internet Gateway
- **Access**: OIDC-based (no static AWS keys), SSM Session Manager (no SSH)
- **Data**: 10-20 static hosts across IT and OT environments

---

## Project Phases

### Phase 0: Foundation Setup (Week 1, Days 1-2)

**Objective**: Establish project structure and repositories

**Key Deliverables**:

- GitHub repository `sirius-demo` created and configured
- Directory structure established (infra/, scripts/, fixtures/, docs/)
- `demo` branch created in SiriusScan repository
- Architecture documentation completed

**Dependencies**: GitHub access, repository creation permissions

**Risks**: None (straightforward setup)

---

### Phase 1: AWS Infrastructure Setup (Week 1, Days 2-3)

**Objective**: Configure AWS foundation and security

**Key Deliverables**:

- OIDC provider configured for GitHub Actions
- IAM roles with least-privilege permissions
- Terraform backend (S3 bucket + DynamoDB table)
- SSM Parameter Store secrets configured
- VPC and subnet identified/created

**Dependencies**: AWS account access, root credentials (temporarily)

**Risks**:

- OIDC configuration complexity (mitigated by following AWS documentation)
- IAM permission scope (test thoroughly with restricted permissions)

---

### Phase 2: Terraform Infrastructure as Code (Week 1-2, Days 4-7)

**Objective**: Develop complete infrastructure definition

**Key Deliverables**:

- Terraform configuration for EC2, security groups, IAM
- Variables and outputs properly defined
- User data bootstrap script for instance configuration
- Validated Terraform code (plan/apply/destroy tested)

**Dependencies**: Phase 1 completion, Terraform CLI installed

**Risks**:

- Bootstrap script failures (mitigated by incremental testing)
- Terraform state lock issues (use DynamoDB locking)
- Resource quotas (verify EC2 limits in region)

**Critical Path**: This phase blocks CI/CD pipeline development

---

### Phase 3: Demo Data & Seeding Scripts (Week 2, Days 5-8)

**Objective**: Create realistic corporate demo environment

**Key Deliverables**:

- Network topology designed (IT/OT segments, 10-20 hosts)
- JSON fixtures for all hosts (Windows, Linux, mixed vulnerabilities)
- Health check wait script (`wait_for_api.sh`)
- Data seeding script (`seed_demo.sh`)
- End-to-end seeding validated

**Dependencies**: API endpoint schema knowledge, CVE database access

**Risks**:

- Unrealistic demo data (mitigated by stakeholder review)
- API schema changes (version fixtures with API version)
- Seeding failures (implement robust retry logic)

**Parallel Work**: Can be developed concurrently with Phase 2

---

### Phase 4: GitHub Actions CI/CD Pipeline (Week 2-3, Days 8-12)

**Objective**: Automate complete rebuild workflow

**Key Deliverables**:

- GitHub Actions workflow with triggers (schedule + push)
- OIDC authentication working
- Terraform destroy → apply → validate cycle
- Health check integration
- Data seeding automation
- Artifact collection and job summaries

**Dependencies**: Phases 2 and 3 complete, OIDC role ARN from Phase 1

**Risks**:

- Workflow timeout issues (set appropriate limits, optimize steps)
- Health check flakiness (implement robust retry with backoff)
- Secrets exposure (review workflow for secret handling)

**Critical Path**: Core project deliverable

---

### Phase 5: Demo Mode UI Enhancements (Week 3, Days 10-14)

**Objective**: Implement demo-specific UI features

**Key Deliverables**:

- `DEMO_MODE` environment variable integration
- Scan functionality hidden in demo mode
- Login tutorial panel with credentials and links
- Demo banner with GitHub link
- Docker Compose configuration for demo mode

**Dependencies**: SiriusScan codebase access, React/TypeScript knowledge

**Risks**:

- UI/UX approval needed (get stakeholder feedback early)
- Breaking existing functionality (test non-demo mode thoroughly)

**Parallel Work**: Can be developed concurrently with Phases 2-4

---

### Phase 6: Documentation & Runbooks (Week 3-4, Days 14-16)

**Objective**: Create comprehensive operational documentation

**Key Deliverables**:

- README with quickstart guide
- Infrastructure runbook for common operations
- Troubleshooting guide for known issues
- Demo data documentation
- Monitoring and cost management guides

**Dependencies**: All technical phases complete for accurate documentation

**Risks**:

- Documentation drift (establish review schedule)

---

### Phase 7: Testing, Validation & Go-Live (Week 4, Days 17-20)

**Objective**: Validate all requirements and deploy to production

**Key Deliverables**:

- All PRD acceptance criteria validated
- Performance testing completed
- Security review and hardening
- User acceptance testing with stakeholders
- Production deployment
- Handoff documentation and training

**Dependencies**: All previous phases complete

**Risks**:

- UAT delays (schedule early, have fallback dates)
- Production deployment issues (deploy during business hours with team available)
- First nightly rebuild in production (monitor closely)

**Critical Path**: Project completion milestone

---

### Phase 8: Future Enhancements (Post-MVP)

**Objective**: Roadmap for ongoing improvements

**Planned Features**:

- Automated notifications (Slack/email)
- Blue/green deployments for zero downtime
- TLS/HTTPS with domain and certificates
- PR preview environments
- Usage analytics
- Security hardening (rate limiting, WAF)
- Multi-region deployments
- Automated demo data updates

**Priority**: Deferred until after MVP success

---

## Project Timeline

```
Week 1: Foundation & Infrastructure
├── Days 1-2:  Phase 0 (Foundation Setup)
├── Days 2-3:  Phase 1 (AWS Setup)
└── Days 4-7:  Phase 2 (Terraform IaC)

Week 2: Data & Automation
├── Days 5-8:  Phase 3 (Demo Data - parallel with Phase 2)
└── Days 8-12: Phase 4 (CI/CD Pipeline)

Week 3: UI & Documentation
├── Days 10-14: Phase 5 (UI Enhancements - parallel with Phase 4)
└── Days 14-16: Phase 6 (Documentation)

Week 4: Testing & Launch
└── Days 17-20: Phase 7 (Testing & Go-Live)

Post-MVP: Phase 8 (Future Enhancements - ongoing)
```

---

## Resource Requirements

### Team

- **Lead Developer** (full-time): Terraform, AWS, GitHub Actions, React/TypeScript
- **Stakeholder/PM** (part-time): UAT, requirements clarification, go-live approval
- **Optional: DevOps Support** (consultative): AWS best practices, OIDC setup review

### Tools & Access

- AWS account with admin access (for initial OIDC/IAM setup)
- GitHub organization with repository creation permissions
- Terraform CLI (latest stable version)
- AWS CLI configured
- Local Docker environment for testing
- (Optional) AWS SSM Session Manager plugin for instance access

### AWS Resources (Monthly Costs)

- **EC2 t3.medium**: ~$30-35/month (730 hours)
- **EBS storage (30GB GP3)**: ~$2.40/month
- **Data transfer**: ~$1-5/month (estimate)
- **S3 (Terraform state)**: <$1/month
- **DynamoDB (state lock)**: <$1/month
- **CloudWatch Logs**: ~$5-10/month (estimate)
- **Total Estimated**: $40-55/month for demo infrastructure

---

## Success Criteria (from PRD)

### Primary Objectives (MVP)

- ✅ **O1**: Rebuild demo nightly at 23:59 UTC and on push to `demo` branch
- ✅ **O2**: Use Terraform to destroy and recreate environment (no drift)
- ✅ **O3**: Automate host bootstrap (dependencies, repo clone, Docker Compose)
- ✅ **O4**: Gate seeding on API health, populate with demo data
- ✅ **O5**: CI outputs clear pass/fail with artifacts and logs

### Secondary Objectives

- ✅ **S1**: Zero long-lived AWS keys (OIDC federation)
- ✅ **S2**: No SSH keys (SSM Session Manager only)
- ✅ **S3**: Secrets in SSM Parameter Store
- ✅ **S4**: Basic observability (CloudWatch Logs, health checks)
- ⚠️ **S5**: Cost controls (tags, single instance, destroy on failure)

### Key Performance Indicators

- **K1**: Provision + bootstrap + seed ≤ 15 minutes (p95)
- **K2**: Nightly job success rate ≥ 95% (rolling 30 days)
- **K3**: Mean time to detect failed rebuild < 5 minutes
- **K4**: Demo shows seeded data within 2 minutes of API health
- **K5**: Zero leaked AWS credentials in repo or logs

### Acceptance Criteria

- **A1**: Push to `demo` branch triggers rebuild finishing in ≤15 min (p95)
- **A2**: Nightly job runs at 23:59 UTC and results in fresh environment
- **A3**: API confirmed healthy before seeding, demo data visible via API
- **A4**: CI artifacts include seed logs with actionable errors
- **A5**: No static AWS keys committed, OIDC assumption verified
- **A6**: All resources tagged, no orphaned resources after destroy

---

## Risk Management

### High Priority Risks

**Risk**: OIDC authentication failures prevent CI/CD execution  
**Impact**: High - blocks deployment pipeline  
**Mitigation**:

- Thoroughly test OIDC setup in isolated environment first
- Document exact trust policy and permissions
- Have fallback AWS credentials (temporary) for emergency use
- Test assumption from GitHub Actions early

**Risk**: Bootstrap script failures leave instance in broken state  
**Impact**: High - demo doesn't start, wastes rebuild time  
**Mitigation**:

- Develop bootstrap script incrementally, test each section
- Add comprehensive logging to cloud-init-output.log
- Test on separate EC2 instance before integrating
- Implement health checks to detect bootstrap failures early

**Risk**: API health check timeout (services don't start)  
**Impact**: Medium - blocks seeding, workflow fails  
**Mitigation**:

- Set generous timeout (15 minutes)
- Implement exponential backoff in health check script
- Add diagnostic steps (check Docker status via SSM if timeout)
- Test bootstrap timing on clean instance

### Medium Priority Risks

**Risk**: Demo data doesn't match API schema changes  
**Impact**: Medium - seeding fails, empty demo  
**Mitigation**:

- Version demo fixtures with API version
- Add fixture validation script
- Test seeding against local API before deployment
- Monitor API schema changes, update fixtures promptly

**Risk**: Terraform state corruption or lock issues  
**Impact**: Medium - prevents infrastructure changes  
**Mitigation**:

- Use DynamoDB for state locking
- Enable S3 versioning for state recovery
- Document state recovery procedures in runbook
- Test destroy/apply cycle thoroughly

**Risk**: Cost overruns from failed cleanup  
**Impact**: Low-Medium - unexpected AWS bills  
**Mitigation**:

- Implement resource tagging for tracking
- Set up AWS budget alerts
- Add cleanup verification step in workflow
- Document orphaned resource cleanup procedures

### Low Priority Risks

**Risk**: Stakeholder dissatisfaction with demo data or UI  
**Impact**: Low - requires rework but not critical  
**Mitigation**:

- Get early feedback on fixtures and UI mockups
- Iterate based on UAT feedback
- Keep fixtures easily modifiable

**Risk**: Performance issues on t3.medium instance  
**Impact**: Low - slow demo experience  
**Mitigation**:

- Performance test before go-live
- Have Terraform variable to scale instance size
- Monitor CloudWatch metrics post-launch
- Document instance upgrade procedure

---

## Decision Log

### Key Architectural Decisions

**Decision**: Use hybrid repository strategy (sirius-demo for infra, SiriusScan/demo for app)  
**Rationale**: Separates infrastructure concerns from application code, keeps repos focused, allows independent versioning  
**Alternatives Considered**: Single repo, forked repo  
**Trade-offs**: Slightly more complex coordination between repos

**Decision**: Use DEMO_MODE environment variable instead of separate docker-compose file  
**Rationale**: Minimizes file proliferation, keeps demo changes simple and maintainable  
**Alternatives Considered**: docker-compose.demo.yaml, build-time configuration  
**Trade-offs**: Small amount of demo-specific code in production codebase

**Decision**: t3.medium instance (not t3.large)  
**Rationale**: Sufficient for demo purposes, cost-effective (~50% cheaper), can scale if needed  
**Alternatives Considered**: t3.large, t3.small  
**Trade-offs**: May need to scale for production-grade performance

**Decision**: Static demo data (not dynamic/randomized)  
**Rationale**: Consistent demos, easier troubleshooting, simpler implementation for MVP  
**Alternatives Considered**: Random data generation, dated CVE injection  
**Trade-offs**: Less "fresh" feel, manual updates needed for relevance

**Decision**: No monitoring/notifications for MVP  
**Rationale**: Keeps scope focused, can add post-launch based on actual needs  
**Alternatives Considered**: Slack integration, email alerts  
**Trade-offs**: Manual checking of workflow status initially

**Decision**: Acceptable downtime during rebuild (no blue/green)  
**Rationale**: Simplifies architecture significantly, acceptable for demo use case  
**Alternatives Considered**: Blue/green deployments, rolling updates  
**Trade-offs**: 5-10 minutes downtime during rebuilds

---

## Communication Plan

### Stakeholder Updates

- **Daily standups**: Quick sync on progress during active development (optional)
- **Weekly status reports**: Email summary of completed tasks, blockers, next week plans
- **Phase completion demos**: Live walkthrough of each completed phase
- **UAT session**: Scheduled formal demo and feedback collection before go-live

### Escalation Path

- **Technical blockers**: Escalate to senior DevOps/AWS expert if stuck >4 hours
- **AWS access issues**: Contact AWS account administrator
- **Scope changes**: Discuss with stakeholder before implementing
- **Go/no-go decision**: Stakeholder approval required before production deployment

### Documentation Updates

- Maintain CHANGELOG.md with significant changes
- Update README as features are added
- Keep troubleshooting guide current with encountered issues
- Document all decision rationale in this plan

---

## Post-MVP Roadmap

### Q1 Enhancements (After MVP Launch)

1. **Monitoring & Notifications**: Slack integration for failures
2. **TLS/HTTPS**: Proper domain and certificates
3. **Cost Optimization**: Review and optimize resource usage

### Q2 Enhancements

1. **Blue/Green Deployments**: Zero-downtime rebuilds
2. **Security Hardening**: Rate limiting, WAF rules
3. **Demo Analytics**: Usage tracking and insights

### Q3+ Future Vision

1. **Multi-Region**: Global demo availability
2. **PR Previews**: Ephemeral environments for testing
3. **Automated Data Updates**: Keep CVEs current

---

## Appendix

### Useful Links

- **PRD**: [sirius-demo/PRD.txt](./PRD.txt)
- **Task List**: [sirius-demo/tasks/tasks.json](./tasks/tasks.json)
- **SiriusScan Repository**: (to be added after setup)
- **AWS Console**: (region-specific URL to be added)

### Glossary

- **OIDC**: OpenID Connect - federated authentication protocol
- **IaC**: Infrastructure as Code - managing infrastructure through code
- **SSM**: AWS Systems Manager - instance management and access
- **OT**: Operational Technology - industrial control systems
- **IT**: Information Technology - corporate systems
- **UAT**: User Acceptance Testing - stakeholder validation

### Contact Information

- **Project Lead**: (Developer name and contact)
- **Stakeholder**: Matt (Open Security Inc.)
- **AWS Support**: (Support plan details if applicable)
- **Emergency Escalation**: (On-call contact for production issues)

---

**Document Version**: 1.0  
**Last Updated**: 2025-10-01  
**Next Review**: After Phase 7 completion  
**Status**: Active - In Development
