# Deployment Guide

## Prerequisites (5 min)

### Required Tools
```bash
# Install
brew install google-cloud-sdk terraform

# Verify versions
gcloud --version  # 400.0.0+
terraform version # 1.3.0+
```

### Required Access
- GCP Organization Admin or Owner
- Billing Account Admin
- Ability to create projects and folders

### GitHub Requirements
- Private repository created
- Fine-grained personal access token with:
  - Actions (read/write)
  - Metadata (read)
  - Secrets (read/write)
  - Variables (read/write)
  - Workflows (read/write)

## Setup Environment Variables

```bash
export ORG_ID="123456789012"                    # Your GCP org ID
export BILLING_ACCOUNT="ABCDEF-123456"          # Your billing account
export GITHUB_ORG="spos-solutions"              # Your GitHub org
export DOMAIN="yourdomain.com"                  # Your org domain
export TF_VAR_gh_token="github_pat_xxxxx"      # Your GitHub token
```

## Step 1: Authenticate

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_SEED_PROJECT_ID  # If you have one
```

## Step 2: Configure Bootstrap

```bash
cd 0-bootstrap/envs/shared

# Setup backend
cp backend.tf.example backend.tf

# Setup GitHub Actions
cp github.tf.example github.tf

# Configure variables
cp terraform.example.tfvars terraform.tfvars

# Edit terraform.tfvars with your values:
# - org_id
# - billing_account
# - default_region
# - groups (or set create_required_groups = false)
# - gh_repos (all set to "gcp-landing-zone" for monorepo)
```

## Step 3: Deploy Bootstrap (Manual)

```bash
cd 0-bootstrap/envs/shared

terraform init
terraform plan
terraform apply  # Takes 10-15 minutes

# Migrate to remote state
export BACKEND_BUCKET=$(terraform output -raw gcs_bucket_tfstate)
sed -i '' "s/UPDATE_ME/${BACKEND_BUCKET}/" backend.tf
terraform init -migrate-state
```

## Step 4: Update All Backend Configs

```bash
cd ~/git/gcp-landing-zone

# Update all backend.tf files with bucket name
for file in $(find . -name 'backend.tf'); do
  sed -i '' "s/UPDATE_ME/${BACKEND_BUCKET}/" $file
done
```

## Step 5: Configure Environments

### Development
```bash
cd 2-environments/envs/development
cp terraform.example.tfvars terraform.tfvars
# Edit with your values
```

### Production
```bash
cd ../production
cp terraform.example.tfvars terraform.tfvars
# Edit with your values
```

### Skip NonProduction (Optional)
```bash
cd ~/git/gcp-landing-zone/2-environments
echo "envs/nonproduction/" >> .gitignore
```

## Step 6: Configure Networks

```bash
cd 3-networks

# Edit common.auto.tfvars
# Set: enable_hub_and_spoke = false

# For each environment (dev, prod):
cd envs/development
cp terraform.example.tfvars terraform.tfvars
# Edit: Set enable_nat = true/false based on need

cd ../production
cp terraform.example.tfvars terraform.tfvars
# Edit: Set enable_nat = true/false based on need
```

**Tip**: Set `enable_nat = false` if using only serverless (Cloud Run, Functions)

## Step 7: Configure Projects

```bash
cd 4-projects/business_unit_1

# Development
cd development
cp terraform.example.tfvars terraform.tfvars
# Edit with your project details

# Production
cd ../production
cp terraform.example.tfvars terraform.tfvars
# Edit with your project details
```

## Step 8: Push to GitHub

```bash
cd ~/git/gcp-landing-zone

# Add remote (if not already added)
git remote add origin git@github.com:spos-solutions/gcp-landing-zone.git

# Create and push branches
git checkout main
git add .
git commit -m "Configure landing zone"
git push -u origin main

git checkout -b production
git push -u origin production

git checkout -b plan
git push -u origin plan
```

## Step 9: Deploy Via GitHub Actions

```bash
# Create PR: plan → production
# Go to: https://github.com/spos-solutions/gcp-landing-zone/compare/production...plan

# 1. Review terraform plans in PR comments
# 2. Verify all stages show expected changes
# 3. Merge PR
# 4. GitHub Actions automatically deploys all stages in order
```

## Deployment Timeline

| Stage | Time | Notes |
|-------|------|-------|
| 0-bootstrap | 10-15 min | Manual deployment |
| 1-org | 5-10 min | GitHub Actions |
| 2-environments | 2-5 min | GitHub Actions |
| 3-networks | 5-10 min | GitHub Actions |
| 4-projects | 5-10 min | GitHub Actions |
| **Total** | **~30-50 min** | After bootstrap |

## Verification

```bash
# List deployed resources
gcloud projects list --organization=${ORG_ID}

# Check folders
gcloud resource-manager folders list --organization=${ORG_ID}

# View VPCs
gcloud compute networks list

# Check IAM policies
gcloud organizations get-iam-policy ${ORG_ID}
```

## Making Changes

```bash
cd ~/git/gcp-landing-zone
git checkout plan

# Make your changes
vim 1-org/envs/shared/terraform.tfvars

# Commit and push
git add 1-org/
git commit -m "Update org policies"
git push origin plan

# Create PR: plan → production
# Review → Merge → Auto-deploy
```

## Rollback

```bash
# Revert the merge commit on production branch
git revert <commit-sha>
git push origin production

# GitHub Actions will automatically apply the reverted state
```

## Troubleshooting

See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for common issues and solutions.
