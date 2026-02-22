# Architecture Overview

## Landing Zone Structure

```
GCP Organization
├── Bootstrap (0-bootstrap)
│   ├── Seed Project (Terraform state)
│   └── CI/CD Project (GitHub WIF)
├── Common (1-org)
│   ├── Logging Project
│   ├── Security Project
│   └── KMS Project
├── Network (3-networks)
│   ├── Dev Shared VPC
│   └── Prod Shared VPC
├── Development (2-environments)
│   └── App Projects (4-projects)
└── Production (2-environments)
    └── App Projects (4-projects)
```

## Deployment Stages

| Stage | Purpose | Deployment |
|-------|---------|------------|
| **0-bootstrap** | Foundation setup, state bucket, CI/CD | Manual (terraform apply) |
| **1-org** | Organization policies, folders, projects | GitHub Actions |
| **2-environments** | Dev/Prod folder structure | GitHub Actions |
| **3-networks** | Dual-SVPC networks | GitHub Actions |
| **4-projects** | Application projects | GitHub Actions |

## Network Design: Dual-SVPC

**Why Dual-SVPC?**
- ✅ Simpler than hub-and-spoke for cloud-only deployments
- ✅ No on-prem connectivity needed
- ✅ Complete isolation between environments
- ✅ PBMM compliant

**Each environment has:**
- 1 Shared VPC
- Subnets per region (primary: northamerica-northeast1)
- Cloud NAT (optional, for VMs)
- Private Google Access enabled

## CI/CD Flow

```
Developer → Commit to branch
         ↓
Create PR to 'plan' branch
         ↓
GitHub Actions runs 'terraform plan'
         ↓
Review → Merge to 'plan'
         ↓
Create PR to 'production' branch
         ↓
GitHub Actions runs 'terraform apply'
         ↓
Infrastructure deployed
```

## Authentication

**Workload Identity Federation** (no service account keys)
- GitHub → Google Cloud WIF Provider
- Short-lived tokens
- Automatic credential rotation

## Cost Model

| Component | Dev | Prod | Cost/month |
|-----------|-----|------|------------|
| VPCs, Subnets, Firewall | ✅ | ✅ | $0 (FREE) |
| Cloud NAT (optional) | ❌ | ✅ | $32/gateway |
| Logging (after 50GB) | - | ✅ | $0.50/GB |
| State Storage | ✅ | - | <$1 |

**Total:** $0-10/month (serverless) or $70-90/month (with NAT)

## Security

- **Org policies** enforced via policy-library
- **Least privilege** IAM roles
- **Audit logging** to centralized project
- **Private Google Access** enabled
- **No external IPs** (with Cloud NAT)
- **Encrypted at rest** via Cloud KMS

## Compliance

**PBMM (Protected B, Medium Integrity, Medium Availability)**
- Based on Canada's GC PBMM requirements
- Policies enforced via Policy Library
- Audit logging and monitoring
- Network isolation
- Encryption standards
