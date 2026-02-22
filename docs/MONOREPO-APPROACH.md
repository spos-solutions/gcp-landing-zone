# Monorepo vs Multi-Repo Approach

This document explains the monorepo approach used in this landing zone.

## Overview

**Monorepo** (Single Repository):
- All stages (0-bootstrap, 1-org, 2-environments, 3-networks, 4-projects) in one repository
- All workflows in `.github/workflows/`
- Single set of GitHub secrets
- Unified change tracking

**Multi-Repo** (5 Separate Repositories):
- Each stage in its own repository
- Workflows distributed across repos
- Separate secrets per repo
- Individual change tracking per stage

## Why Monorepo? ✅

We use the monorepo approach for several reasons:

### 1. Simplified Management
- **One repository** to secure, backup, and manage
- Single branch protection configuration
- One fine-grained PAT for all operations
- Unified access control

### 2. Better Collaboration
- All team members clone one repo
- Cross-stage changes in single PR
- Easier code reviews across stages
- Shared documentation and scripts

### 3. Unified Change History
- All infrastructure changes tracked together
- Easy to see relationships between stages
- Git blame works across stages
- Simpler rollback procedures

### 4. Easier CI/CD
- All workflows in one place (`.github/workflows/`)
- Shared GitHub Actions configuration
- Single workflow trigger patterns
- Easier to maintain consistency

### 5. Reduced Complexity
- Fewer API calls to GitHub
- Single set of secrets to maintain
- Less administrative overhead
- Simpler onboarding process

### 6. Cost Effective
- GitHub Actions minutes shared across stages
- Single set of branch protection rules
- Reduced API rate limit usage
- Less CI/CD configuration duplication

## Repository Structure

```
gcp-landing-zone/                    # ← Single repository
├── 0-bootstrap/                     # Bootstrap stage
│   ├── main.tf
│   ├── variables.tf
│   ├── github.tf                    # WIF configuration
│   └── terraform.tfvars
│
├── 1-org/                           # Organization stage
│   └── envs/
│       ├── shared/
│       └── ...
│
├── 2-environments/                  # Environments stage
│   └── envs/
│       ├── development/
│       ├── nonproduction/
│       └── production/
│
├── 3-networks/                      # Networks stage
│   └── envs/
│       ├── development/
│       ├── nonproduction/
│       └── production/
│
├── 4-projects/                      # Projects stage
│   ├── business_unit_1/
│   ├── business_unit_2/
│   └── modules/
│
├── .github/
│   ├── actions/
│   │   └── opa-validate/           # Shared OPA validation
│   └── workflows/                   # All workflows here
│       ├── 0-bootstrap.yaml
│       ├── 1-org.yaml
│       ├── 2-environments.yaml
│       ├── 3-networks.yaml
│       └── 4-projects.yaml
│
├── policy-library/                  # Shared policies
│   ├── lib/
│   └── policies/
│
├── scripts/                         # Shared scripts
│   ├── setup-github-security.sh
│   ├── configure-bootstrap-wif.sh
│   └── validate-policies-local.sh
│
├── docs/                            # Shared documentation
│   ├── QUICKSTART-WIF.md
│   ├── GITHUB-SECURITY.md
│   └── BOOTSTRAP-WIF-SETUP.md
│
└── README.md                        # Main documentation
```

## How WIF Works with Monorepo

Workload Identity Federation maps the single repository to multiple service accounts:

```terraform
# In 0-bootstrap/github.tf

locals {
  gh_config = {
    "bootstrap" = var.gh_repos.bootstrap,    # = "gcp-landing-zone"
    "org"       = var.gh_repos.organization, # = "gcp-landing-zone"
    "env"       = var.gh_repos.environments, # = "gcp-landing-zone"
    "net"       = var.gh_repos.networks,     # = "gcp-landing-zone"
    "proj"      = var.gh_repos.projects,     # = "gcp-landing-zone"
  }

  sa_mapping = {
    for k, v in local.gh_config : k => {
      sa_name   = google_service_account.terraform-env-sa[k].name
      attribute = "attribute.repository/${var.gh_repos.owner}/${v}"
    }
  }
}
```

**Result:**
- All 5 service accounts map to: `attribute.repository/owner/gcp-landing-zone`
- Each workflow authenticates with its specific service account
- WIF validates the repository and grants appropriate credentials

## Workflow Pattern

Each workflow specifies which service account to use:

```yaml
# .github/workflows/0-bootstrap.yaml
jobs:
  terraform-plan:
    permissions:
      contents: read
      id-token: write
      pull-requests: write
    steps:
      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER_NAME }}
          service_account: ${{ secrets.SERVICE_ACCOUNT_EMAIL }}  # bootstrap SA
```

```yaml
# .github/workflows/1-org.yaml
jobs:
  terraform-plan:
    permissions:
      contents: read
      id-token: write
      pull-requests: write
    steps:
      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER_NAME }}
          service_account: ${{ secrets.SERVICE_ACCOUNT_EMAIL }}  # org SA
```

Each workflow uses the appropriate service account from GitHub Secrets.

## GitHub Secrets Configuration

With monorepo, you configure secrets **once** in the repository:

```bash
# These are configured automatically by bootstrap terraform apply
PROJECT_ID              # CI/CD project ID
WIF_PROVIDER_NAME       # Workload Identity provider
TF_BACKEND              # GCS bucket for state
TF_VAR_gh_token         # GitHub token
SERVICE_ACCOUNT_EMAIL   # Service account for the stage
```

Each workflow accesses the same `WIF_PROVIDER_NAME` but uses different service accounts.

## Branch Strategy

```
main (production branch - protected)
  ↓
  └─→ plan/dev/feature branches (development, PR only)
```

Workflow:
1. Create feature branch from `main`
2. Make changes to any stage (or multiple stages)
3. Push feature branch
4. Create PR to `main`
5. GitHub Actions runs plan for **all changed stages**
6. Review plans
7. Merge PR to `main`
8. GitHub Actions applies changes to production

## Multi-Stage Changes

One PR can include changes to multiple stages:

```bash
# Example: Change organization policy and update network
git checkout -b feature/add-security-controls

# Update org policies
vim 1-org/envs/shared/org_policies.tf

# Update firewall rules
vim 3-networks/envs/production/firewall.tf

# Commit and push
git add .
git commit -m "Add security controls across org and network"
git push origin feature/add-security-controls

# Create PR - workflows run for both stages
gh pr create --base main --head feature/add-security-controls
```

Both `1-org` and `3-networks` workflows will run, each using their appropriate service account.

## Comparison Table

| Aspect | Monorepo | Multi-Repo (5 repos) |
|--------|----------|----------------------|
| **Repositories** | 1 | 5 |
| **Setup Complexity** | Low | High |
| **Branch Protection** | Configure once | Configure 5 times |
| **GitHub Secrets** | 1 set | 5 sets |
| **Workflows** | All in `.github/workflows/` | Distributed across repos |
| **Cross-stage changes** | Single PR | Multiple PRs |
| **Change tracking** | Unified history | Fragmented across repos |
| **Team onboarding** | Clone 1 repo | Clone 5 repos |
| **CI/CD minutes** | Shared pool | Separate pools |
| **Maintenance** | Update once | Update 5 times |
| **Security Config** | 1 PAT, 1 WIF | 1 PAT, 1 WIF (still single) |

## When to Use Multi-Repo?

Consider multi-repo if:

❌ **Not recommended for most cases**, but consider if:
- Different teams own different stages with **strict separation**
- Regulatory requirements mandate **physical repository separation**
- Different release cadences per stage (rare for infrastructure)
- Very large organization with independent infrastructure teams

✅ **Monorepo is recommended** for:
- Most organizations (small to large)
- Teams that collaborate on infrastructure
- Standard landing zone deployments
- Unified change management
- Simplified operations

## Migration from Multi-Repo

If you started with multi-repo and want to migrate:

1. Create new monorepo repository
2. Copy each stage as subdirectory:
   ```bash
   git clone new-monorepo
   cd new-monorepo
   
   git remote add bootstrap <bootstrap-repo-url>
   git fetch bootstrap
   git checkout bootstrap/main -- . 
   mv * 0-bootstrap/
   
   # Repeat for other stages to 1-org/, 2-environments/, etc.
   ```
3. Update `github.tf` with new repo name (all same)
4. Run terraform apply to update WIF mappings
5. Migrate workflows to `.github/workflows/`
6. Update branch protection
7. Archive old repositories

## Best Practices

### 1. Clear Directory Structure
Maintain clear separation between stages even in monorepo:
```
/<stage-number>-<stage-name>/
```

### 2. Use CODEOWNERS
Define ownership per directory:
```
# .github/CODEOWNERS
/0-bootstrap/        @platform-team
/1-org/             @platform-team
/2-environments/    @platform-team
/3-networks/        @network-team
/4-projects/        @app-teams
```

### 3. Workflow Organization
Name workflows clearly:
```
.github/workflows/
├── 0-bootstrap.yaml      # Not just "bootstrap.yaml"
├── 1-org.yaml
├── 2-environments.yaml
├── 3-networks.yaml
└── 4-projects.yaml
```

### 4. Documentation Structure
Keep docs organized by topic, not by stage:
```
docs/
├── QUICKSTART-WIF.md      # Overall quick start
├── GITHUB-SECURITY.md     # Security for whole repo
├── ARCHITECTURE.md        # Overall architecture
└── addressing-plan/       # Shared IP planning
```

### 5. Shared Resources
Maximize reuse:
```
scripts/                   # Shared scripts
policy-library/           # Shared policies
.github/actions/          # Reusable actions
```

## Troubleshooting

### Issue: Workflows trigger for unrelated changes

**Solution:** Use path filters in workflows:
```yaml
on:
  pull_request:
    paths:
      - '0-bootstrap/**'
      - '.github/workflows/0-bootstrap.yaml'
```

### Issue: Large repository size

**Solution:**
- Use `.gitignore` for terraform state, `.terraform/`, etc.
- Don't commit large binary files
- Use Git LFS if needed for large files

### Issue: Too many workflow runs

**Solution:** Use concurrency groups:
```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

## Summary

The monorepo approach is **simpler, more maintainable, and recommended** for most GCP landing zone deployments. It provides:

✅ Single repository to manage  
✅ Unified change history  
✅ Easier collaboration  
✅ Simpler CI/CD  
✅ Reduced overhead  
✅ Better developer experience  

The WIF configuration supports monorepo by mapping a single repository to multiple service accounts, maintaining security boundaries while simplifying operations.

## References

- [Google Cloud Terraform Example Foundation](https://github.com/terraform-google-modules/terraform-example-foundation)
- [Monorepo Tools](https://monorepo.tools/)
- [GitHub's Monorepo Approach](https://github.blog/2024-01-17-monorepos-are-not-the-solution-to-everyone/)
- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
