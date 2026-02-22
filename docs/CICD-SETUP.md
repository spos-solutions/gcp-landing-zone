# CI/CD Configuration

## Current Setup: GitHub Actions ✅

This landing zone is configured to use **GitHub Actions** for CI/CD automation.

## Repository Structure

**All unused CI/CD configurations have been removed.** The repository now contains only GitHub Actions related files:

### Active CI/CD Components:
```
.github/
├── actions/
│   └── opa-validate/          ✅ OPA policy validation action
└── workflows/
    ├── 0-bootstrap.yaml       ✅ Foundation setup
    ├── 1-org.yaml             ✅ Organization policies
    ├── 2-environments.yaml    ✅ Environment folders
    ├── 3-networks.yaml        ✅ VPC networks
    └── 4-projects.yaml        ✅ Project creation

0-bootstrap/
├── builders/
│   └── github/                ✅ GitHub Actions configuration
└── README-GitHub.md           ✅ GitHub setup guide
```

### Removed (Unused):
- ❌ Cloud Build configuration (`builders/cb/`)
- ❌ Jenkins configuration (`builders/jenkins/`)
- ❌ GitLab configuration (`builders/gitlab/`)
- ❌ Azure DevOps configuration (`builders/azuredevops/`)
- ❌ Terraform Cloud configuration (`builders/tf.cloud/`)
- ❌ Local execution helpers (`builders/tf.local/`)
- ❌ All related README files and `.tf.example` files

## Your Active CI/CD Pipeline

**Workflows Location:** `.github/workflows/*.yaml`

Active workflows:
- ✅ `0-bootstrap.yaml` - Foundation setup
- ✅ `1-org.yaml` - Organization policies
- ✅ `2-environments.yaml` - Environment folders
- ✅ `3-networks.yaml` - VPC networks
- ✅ `4-projects.yaml` - Project creation

**Authentication:** Workload Identity Federation (no service account keys!)

**Execution:**
- **On PR:** Runs `terraform plan` + OPA validation
- **On Merge:** Runs `terraform plan` + `terraform apply`

## What You DON'T Need

### No Cloud Build Project
You don't need the `prj-b-cicd` project for Cloud Build. Your CI/CD runs entirely in GitHub Actions runners.

### No Additional CI/CD Infrastructure
All CI/CD logic is defined in `.github/workflows/` YAML files. No compute resources needed.

## What You DO Need

### GitHub Secrets
Required in your repository settings:

```
WIF_PROVIDER_NAME          # Workload Identity Provider
TF_SA_BOOTSTRAP           # Bootstrap service account
TF_SA_ORG                 # Org service account
TF_SA_ENVIRONMENTS        # Environments service account
TF_SA_NETWORKS            # Networks service account
TF_SA_PROJECTS            # Projects service account
```

### Google Cloud Resources
- Terraform state bucket (GCS)
- Service accounts for each stage
- Workload Identity Federation pool
- IAM bindings for GitHub Actions

## Reference Architecture

```
┌─────────────────────────────────────────────────┐
│           GitHub Repository                     │
│  ┌──────────────────────────────────────────┐  │
│  │     .github/workflows/*.yaml             │  │
│  │     - Consolidated plan+apply            │  │
│  │     - OPA policy validation              │  │
│  └──────────────────────────────────────────┘  │
└────────────────┬────────────────────────────────┘
                 │
                 │ Workload Identity Federation
                 ↓
┌─────────────────────────────────────────────────┐
│         Google Cloud Platform                   │
│  ┌──────────────────────────────────────────┐  │
│  │  Service Accounts                        │  │
│  │  - tf-bootstrap@...                      │  │
│  │  - tf-org@...                            │  │
│  │  - tf-environments@...                   │  │
│  │  - tf-networks@...                       │  │
│  │  - tf-projects@...                       │  │
│  └──────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────┐  │
│  │  Terraform State (GCS Bucket)            │  │
│  └──────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

## Questions?

**Q: Do I need the `prj-b-cicd` project?**  
A: No, not for Cloud Build. You might use it for state/secrets, but GitHub Actions runs on its own runners.

**Q: Why did the repo originally have Cloud Build/Jenkins configs?**  
A: This repo is based on terraform-example-foundation which supports multiple CI/CD backends. We've removed the unused ones.

**Q: How do I deploy changes?**  
A: Create PR → Review plan → Merge to production → Auto-deploy ✅

**Q: Where are the CI/CD workflows defined?**  
A: In `.github/workflows/` directory. Each stage has its own consolidated workflow file.

**Q: The `builders/` folder only has GitHub now - can I delete it?**  
A: No, keep `builders/github/` - it contains the GitHub-specific Terraform configuration used during bootstrap.

