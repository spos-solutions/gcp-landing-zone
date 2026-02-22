# GitHub Actions Workflows

## Overview

10 workflows automate terraform operations: **plan** (on PR) and **apply** (on merge).

## Workflow Files

```
.github/workflows/
├── 0-bootstrap-plan.yaml     # Plan bootstrap changes
├── 0-bootstrap-apply.yaml    # Apply bootstrap (rarely used)
├── 1-org-plan.yaml           # Plan org changes
├── 1-org-apply.yaml          # Apply org changes
├── 2-environments-plan.yaml  # Plan environment changes
├── 2-environments-apply.yaml # Apply environment changes
├── 3-networks-plan.yaml      # Plan network changes
├── 3-networks-apply.yaml     # Apply network changes
├── 4-projects-plan.yaml      # Plan project changes
└── 4-projects-apply.yaml     # Apply project changes
```

## How It Works

### Plan Workflows (on Pull Request)

**Trigger:** PR to `plan` branch
**Action:** `terraform plan`
**Output:** Plan results posted as PR comment

```yaml
on:
  pull_request:
    branches: [plan]
    paths: ['1-org/**']  # Only runs if 1-org files changed
```

**Jobs run in parallel** for all changed stages.

### Apply Workflows (on Merge)

**Trigger:** Push to `production` branch
**Action:** `terraform apply -auto-approve`
**Output:** Applied changes visible in GitHub Actions logs

```yaml
on:
  push:
    branches: [production]
    paths: ['1-org/**']
```

**Jobs run sequentially** for environments (dev → nonprod → prod).

## Authentication

**Workload Identity Federation:**

```yaml
- uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
    service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}
```

No service account keys stored in GitHub!

## Typical Workflow

### Making a Change

```bash
# 1. Create feature branch
git checkout -b add-new-project

# 2. Make changes
vim 4-projects/business_unit_1/production/terraform.tfvars

# 3. Commit and push
git add 4-projects/
git commit -m "Add new project for production"
git push origin add-new-project

# 4. Create PR to 'plan' branch
# GitHub Actions runs terraform plan
# Review plan output in PR comments

# 5. Merge PR to 'plan'

# 6. Create PR: plan → production
# Review one more time

# 7. Merge to production
# GitHub Actions automatically applies changes
```

## Path Filters

**Only changed stages trigger workflows:**

| Changed Files | Workflows Triggered |
|---------------|-------------------|
| `1-org/**` | 1-org-plan.yaml, 1-org-apply.yaml |
| `3-networks/**` | 3-networks-plan.yaml, 3-networks-apply.yaml |
| `4-projects/**` | 4-projects-plan.yaml, 4-projects-apply.yaml |

**Benefits:**
- Faster CI/CD (only run what changed)
- Safer (no accidental changes to other stages)
- Clearer logs (focused on one stage)

## Secrets Required

Set these in GitHub repo settings (`Settings` → `Secrets and variables` → `Actions`):

```
WIF_PROVIDER              # Created by bootstrap
WIF_SERVICE_ACCOUNT       # Created by bootstrap
TF_BACKEND_BUCKET         # Created by bootstrap (optional)
```

**These are automatically populated by bootstrap stage.**

## Troubleshooting

### Workflow not running
- Check path filters match your changed files
- Verify you're creating PR to correct branch (`plan`)
- Check Actions tab for any failed runs

### Authentication errors
- Verify bootstrap completed successfully
- Check WIF provider exists: `gcloud iam workload-identity-pools list`
- Verify secrets in GitHub repo settings

### Plan shows unexpected changes
- Check if someone manually modified resources in GCP Console
- Verify terraform.tfvars has correct values
- Run `terraform plan` locally to reproduce

### Apply fails
- Review error in Actions logs
- Common issues: quota limits, IAM permissions, naming conflicts
- Fix issue and re-run workflow (push to production again)

## Manual Override

**When needed:** Bootstrap stage, emergency fixes

```bash
# SSH into your machine or Cloud Shell
cd <stage>/envs/<environment>

# Authenticate if needed
gcloud auth application-default login

# Run terraform manually
terraform init
terraform plan
terraform apply
```

**After manual changes:**
```bash
# Sync code with actual state
terraform state pull > current.tfstate
# Update your .tfvars to match
# Commit and push to keep repo in sync
```

## Best Practices

1. ✅ **Always use PRs** - Never push directly to production
2. ✅ **Review plans carefully** - Check for unexpected deletes/changes
3. ✅ **Test in dev first** - Apply changes to dev before prod
4. ✅ **Small changes** - Easier to review and rollback
5. ✅ **Descriptive commits** - Clear what changed and why
6. ✅ **Check Actions logs** - Verify successful deployment
7. ❌ **Don't edit manually** - Use terraform for all changes
