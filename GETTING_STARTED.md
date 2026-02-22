# 🚀 Deploy PBMM Landing Zone - Complete Guide

**One guide to get your PBMM-compliant GCP landing zone running in 60 minutes.**

## TL;DR

1. Create ONE private GitHub repo
2. Copy files, configure terraform
3. Deploy bootstrap manually
4. Deploy remaining stages via GitHub Actions
5. Total cost: **$0-10/month** (serverless) or **$80-90/month** (with VMs)

---

## Prerequisites (5 min)

```bash
# Install tools
brew install google-cloud-sdk terraform

# Set variables
export ORG_ID="123456789012"
export BILLING_ACCOUNT="ABCDEF-123456"
export GITHUB_ORG="your-github-org"
export DOMAIN="yourstartup.com"

# Authenticate
gcloud auth login
gcloud auth application-default login

# Create GitHub token at: https://github.com/settings/tokens?type=beta
# Permissions: Actions, Metadata, Secrets, Variables, Workflows (all Read/Write)
export TF_VAR_gh_token="github_pat_xxxxxxxxxxxx"
```

**Validate environment**:
```bash
./scripts/preflight-check.sh
```

---

## Step 1: Create GitHub Repository (2 min)

Create ONE private repository on GitHub:
- Name: `gcp-landing-zone`
- Visibility: Private
- Initialize with README

---

## Step 2: Setup Monorepo with Upstream Sync (5 min)

**Option A: Fork Approach (Recommended)** ✅

```bash
# 1. Fork on GitHub first:
#    Go to: https://github.com/GoogleCloudPlatform/pbmm-on-gcp-onboarding
#    Click "Fork" → Create as: ${GITHUB_ORG}/gcp-landing-zone

# 2. Clone your fork
cd ~/git
git clone git@github.com:${GITHUB_ORG}/gcp-landing-zone.git
cd gcp-landing-zone

# 3. Setup branches
git checkout -b production && git push origin production
git checkout -b plan

# 4. Add upstream for updates
git remote add upstream https://github.com/GoogleCloudPlatform/pbmm-on-gcp-onboarding.git

# 5. Rename networks folder
git mv 3-networks-dual-svpc 3-networks
git commit -m "Rename networks folder for monorepo"

# 6. Copy workflows
mkdir -p .github/workflows
curl -o .github/workflows/0-bootstrap-plan.yaml https://raw.githubusercontent.com/GoogleCloudPlatform/pbmm-on-gcp-onboarding/main/.github/workflows/0-bootstrap-plan.yaml
curl -o .github/workflows/0-bootstrap-apply.yaml https://raw.githubusercontent.com/GoogleCloudPlatform/pbmm-on-gcp-onboarding/main/.github/workflows/0-bootstrap-apply.yaml
# (repeat for all 10 workflows)

# Update workflow paths
sed -i '' 's/3-networks-dual-svpc/3-networks/g' .github/workflows/3-networks-*.yaml

git add .github/
git commit -m "Add GitHub Actions workflows"
```

**Option B: Clone and Add Upstream**

```bash
cd ~/git

# Clone source
git clone https://github.com/GoogleCloudPlatform/pbmm-on-gcp-onboarding.git gcp-landing-zone
cd gcp-landing-zone

# Change remote to your repo
git remote rename origin upstream
git remote add origin git@github.com:${GITHUB_ORG}/gcp-landing-zone.git

# Create branches
git checkout -b production && git push origin production
git checkout -b plan

# Continue with setup as above
```

---

## Step 3: Configure Bootstrap (5 min)

```bash
cd 0-bootstrap/envs/shared

# Setup for GitHub Actions
mv cb.tf cb.tf.example                    # Don't need Cloud Build
mv github.tf.example github.tf            # Use GitHub Actions
mv terraform.example.tfvars terraform.tfvars

# Edit terraform.tfvars
cat > terraform.tfvars << EOF
org_id          = "${ORG_ID}"
billing_account = "${BILLING_ACCOUNT}"
default_region  = "northamerica-northeast1"

# Minimal groups (or use existing)
groups = {
  create_required_groups = false
  create_optional_groups = false
  billing_project        = ""
  required_groups = {
    group_org_admins           = "admins@${DOMAIN}"
    group_billing_admins       = "admins@${DOMAIN}"
    billing_data_users         = "admins@${DOMAIN}"
    audit_data_users           = "security@${DOMAIN}"
    monitoring_workspace_users = "devops@${DOMAIN}"
  }
  optional_groups = {}
}

# All stages point to same repo (monorepo)
gh_repos = {
  owner        = "${GITHUB_ORG}"
  bootstrap    = "gcp-landing-zone"
  organization = "gcp-landing-zone"
  environments = "gcp-landing-zone"
  networks     = "gcp-landing-zone"
  projects     = "gcp-landing-zone"
}
EOF
```

---

## Step 4: Deploy Bootstrap (15 min)

```bash
# Still in 0-bootstrap/envs/shared
terraform init
terraform plan
terraform apply  # Review and approve

# Setup remote state
export backend_bucket=$(terraform output -raw gcs_bucket_tfstate)
cp backend.tf.example backend.tf
sed -i '' "s/UPDATE_ME/${backend_bucket}/" backend.tf
terraform init  # Migrate state to GCS

# Update all backend.tf files
cd ~/git/gcp-landing-zone
for i in $(find . -name 'backend.tf'); do 
  sed -i '' "s/UPDATE_ME/${backend_bucket}/" $i
done
```

---

## Step 5: Configure Environments (5 min)

**For Startups - Start with just Dev + Prod:**

```bash
cd ~/git/gcp-landing-zone/2-environments

# Development
cd envs/development
mv terraform.example.tfvars terraform.tfvars
# Edit with your values (follow prompts in file)

# Production
cd ../production
mv terraform.example.tfvars terraform.tfvars
# Edit with your values

# Skip nonproduction for now
cd ../..
echo "envs/nonproduction/" >> .gitignore
```

---

## Step 6: Configure Networks (5 min)

**Choose your network setup:**

### Option A: No NAT (Serverless Only - $0/month) ✅ Recommended for Startups

```bash
cd ~/git/gcp-landing-zone/3-networks

# Edit common.auto.tfvars
# Set: enable_hub_and_spoke = false
# Comment out or set: enable_nat = false

# Only configure dev and prod
cd envs/development
# Edit terraform.tfvars - set enable_nat = false

cd ../production
# Edit terraform.tfvars - set enable_nat = false

# Skip nonproduction and shared
cd ../..
echo "envs/nonproduction/" >> .gitignore
echo "envs/shared/" >> .gitignore
```

### Option B: With NAT (For VMs - ~$65/month)

Keep NAT enabled in network configs if you'll use Compute Engine VMs or GKE.

---

## Step 7: Configure Projects (5 min)

```bash
cd ~/git/gcp-landing-zone/4-projects/business_unit_1

# Configure dev and prod
cd development
# Edit terraform.tfvars

cd ../production
# Edit terraform.tfvars

# Skip nonproduction and shared
cd ..
echo "nonproduction/" >> .gitignore
echo "shared/" >> .gitignore
```

---

## Step 8: Push and Deploy (20 min)

```bash
cd ~/git/gcp-landing-zone

# Commit everything
git add .
git commit -m "Initial landing zone configuration"
git push origin plan

# Create PR: plan → production
# Go to: https://github.com/${GITHUB_ORG}/gcp-landing-zone/compare/production...plan
# Review GitHub Actions output (terraform plans)
# Merge PR
```

**GitHub Actions will automatically deploy:**
1. 1-org (organization structure)
2. 2-environments (dev + prod folders)
3. 3-networks (VPCs, subnets, optionally NAT)
4. 4-projects (application projects)

---

## What You Deployed

```
GCP Organization
├── Bootstrap Folder
│   ├── Seed Project (Terraform state)
│   └── CI/CD Project (GitHub Actions WIF)
├── Common Folder
│   ├── Logging Project
│   ├── KMS Project
│   └── Security Project
├── Network Folder
│   ├── Dev Shared VPC
│   └── Prod Shared VPC
├── Development Folder
│   └── App Projects (when you create them)
└── Production Folder
    └── App Projects (when you create them)
```

---

## Cost Breakdown

### VPCs, Subnets, Firewall Rules: FREE ✅

### Actual Costs:

**Serverless Setup (No NAT):**
- VPCs: $0
- GitHub Actions: $0 (free tier)
- Logging (50GB free): $0
- State storage: <$1/month
- **Total: ~$0-5/month** 🎉

**With VMs (Need NAT):**
- Everything above: ~$5/month
- Cloud NAT (2 gateways): ~$65/month
- **Total: ~$70-90/month**

---

## Architecture Decisions

### ✅ What We Chose (And Why)

**Monorepo**: One repo with all stages
- Simpler to manage
- Path-filtered workflows
- Atomic changes

**Dual-SVPC**: Each environment has its own VPC
- Simpler than hub-and-spoke
- Perfect for cloud-only
- Still PBMM compliant

**GitHub Actions**: CI/CD automation
- Free for private repos
- Workload Identity Federation (no keys)
- Automatic plan/apply

**No On-Prem**: Skip Fortigate, VPN, Interconnect
- You don't have on-prem connectivity
- Saves complexity and cost

**Start Minimal**: Dev + Prod only
- Add nonproduction later
- Add NAT when needed
- Scale as you grow

### ❌ What We Skipped

- Cloud Build (using GitHub Actions)
- Jenkins (using GitHub Actions)
- 7-fortigate (no on-prem)
- Hub-and-spoke (too complex for startups)
- Non-production environment (add later)
- Cloud NAT (if going serverless)

---

## Making Changes

```bash
cd ~/git/gcp-landing-zone
git checkout plan

# Edit any stage
vim 1-org/envs/shared/terraform.tfvars

# Commit and push
git add 1-org/
git commit -m "Update org policies"
git push origin plan

# Create PR → Review → Merge
# Only 1-org workflows run (path-filtered!)
```

---

## Common Use Cases

### Deploy a Serverless App

```bash
# Your app can use:
# - Cloud Run (backend)
# - Cloud Functions (jobs)
# - Cloud SQL (database)
# - Cloud Storage (files)

# No NAT needed!
# Apps have built-in internet access

# Cost: Pay per request/usage
```

### Add VMs Later

```bash
cd 3-networks/envs/production

# Edit terraform.tfvars
# Set: enable_nat = true

git add . && git commit -m "Enable NAT for VMs"
git push origin plan
# Create PR, merge

# Now you can deploy VMs without external IPs
# Cost: +$32/month per NAT gateway
```

### Add Non-Production Environment

```bash
cd 2-environments/envs/nonproduction
mv terraform.example.tfvars terraform.tfvars
# Configure

cd ../../../3-networks/envs/nonproduction
# Configure

# Commit, push, PR, merge
# Cost: +$32/month if using NAT
```

---

## Troubleshooting

### Bootstrap fails
```bash
# Check permissions
gcloud organizations get-iam-policy ${ORG_ID}

# Verify billing
gcloud billing accounts list
```

### Workflow not running
- Check `.github/workflows/*.yaml` exist
- Verify path filters match changed files
- Look at Actions tab in GitHub

### Authentication errors
- Bootstrap must complete successfully first
- Check GitHub secrets are populated
- Verify WIF provider was created

### Cost too high
- Remove NAT if using serverless only
- Reduce logging retention
- Use development environment for testing

---

## Next Steps

1. ✅ **Deploy an app** to development
   - Use Cloud Run or Cloud Functions
   - Connect to Cloud SQL
   - Test thoroughly

2. ✅ **Promote to production**
   - Same code, different environment
   - Use GitHub Actions for deployment

3. ✅ **Add monitoring**
   - Cloud Monitoring (free basic)
   - Set up alerts

4. ✅ **Scale as needed**
   - Add NAT when you need VMs
   - Add nonproduction environment
   - Expand to multiple regions

---

## Quick Reference

### Deployment Stages
```
0-bootstrap  → Manual (terraform apply)
1-org        → GitHub Actions (PR merge)
2-environments → GitHub Actions
3-networks   → GitHub Actions
4-projects   → GitHub Actions
```

### Key Commands
```bash
# Check terraform plan locally
cd <stage>/envs/<env>
terraform init && terraform plan

# Update all backends
for i in $(find . -name 'backend.tf'); do 
  sed -i '' "s/OLD/${NEW}/" $i
done

# Check deployed resources
gcloud projects list --organization=${ORG_ID}

# View costs
gcloud billing accounts describe ${BILLING_ACCOUNT}
```

### Important Files
```
0-bootstrap/envs/shared/terraform.tfvars  → Bootstrap config
1-org/envs/shared/terraform.tfvars        → Org config
2-environments/envs/*/terraform.tfvars    → Per-environment
3-networks/envs/*/terraform.tfvars        → Network config
4-projects/.../terraform.tfvars           → Project config
```

---

## Architecture Summary

**Network**: Dual-SVPC (separate VPC per environment)
**CI/CD**: GitHub Actions with Workload Identity
**Environments**: Dev + Prod (add more later)
**NAT**: Optional (serverless = no NAT needed)
**Cost**: $0-10/month (serverless) or $80-90/month (VMs)
**Deployment Time**: ~60-90 minutes
**Complexity**: Simplified for startups

---

## Success Checklist

After completion, you should have:

- [x] Bootstrap projects deployed
- [x] GitHub Actions workflows running
- [x] Organization structure created
- [x] Environment folders configured
- [x] VPCs and networks deployed
- [x] Projects ready for workloads
- [x] Remote state in GCS
- [x] No manual deployments needed
- [x] PBMM compliant
- [x] Cost optimized

**You're ready to deploy your applications!** 🎉

---

## Keeping Your Code Updated from Upstream

### Sync with Upstream PBMM Updates

**When to sync**: Monthly or when important security/compliance updates are released

```bash
cd ~/git/gcp-landing-zone

# 1. Fetch upstream changes
git fetch upstream

# 2. Create sync branch from plan
git checkout plan
git checkout -b sync-upstream

# 3. Merge upstream changes
git merge upstream/main --no-commit

# Review conflicts (usually in your terraform.tfvars)
git status

# 4. Resolve conflicts - Keep your configs
# Your files (keep as-is):
#   */terraform.tfvars
#   common.auto.tfvars
#   *.auto.tfvars
#   backend.tf (with your bucket)

# Upstream files (accept updates):
#   *.tf (infrastructure code)
#   *.tf.example
#   modules/**
#   scripts/**
#   policy-library/**

# 5. Complete merge
git add .
git commit -m "Sync with upstream pbmm-on-gcp-onboarding"

# 6. Test locally
cd 0-bootstrap/envs/shared
terraform plan  # Should show no changes

# 7. Create PR for review
git push origin sync-upstream
# Create PR: sync-upstream → plan
# Review changes carefully
# Run all plan workflows
# Merge when ready
```

### Protect Your Customizations

**Add .gitignore for your configs:**

```bash
# In project root
cat >> .gitignore << 'EOF'

# Your custom configurations (don't overwrite on sync)
**/terraform.tfvars
!**/terraform.example.tfvars
*.auto.tfvars
!*.auto.example.tfvars
!*.auto.mod.tfvars

# Local state and temp files
**/.terraform/
**/.terraform.lock.hcl
**/terraform.tfstate*
**/*.tfplan

# Your environment-specific overrides
local-overrides/
EOF
```

### Sync Strategy

**Best Practice**:
1. **Keep infrastructure code clean** - Don't modify .tf files unless necessary
2. **All customization in .tfvars** - Your configs stay in terraform.tfvars
3. **Sync monthly** - Or when upstream releases security updates
4. **Test in dev first** - Apply upstream changes to dev environment first
5. **Review breaking changes** - Check upstream CHANGELOG.md before syncing

### Handling Conflicts

**Common conflict scenarios:**

```bash
# Conflict in a .tf file you modified
# Option 1: Keep upstream version, move your changes to a new module
git checkout --theirs path/to/file.tf

# Option 2: Keep your version (if you need custom logic)
git checkout --ours path/to/file.tf

# Conflict in terraform.tfvars (your config)
# Always keep your version
git checkout --ours **/terraform.tfvars

# Conflict in .example files
# Keep upstream version  
git checkout --theirs **/*.example

# After resolving each conflict
git add <resolved-file>
```

### Checking for Upstream Updates

```bash
# See what changed upstream
git fetch upstream
git log HEAD..upstream/main --oneline

# See specific changes to files you care about
git diff HEAD..upstream/main -- 0-bootstrap/
git diff HEAD..upstream/main -- 1-org/modules/

# Check release notes
curl https://api.github.com/repos/GoogleCloudPlatform/pbmm-on-gcp-onboarding/releases/latest
```

### Automated Update Notifications

**Create a GitHub Action to notify on upstream updates:**

```yaml
# .github/workflows/check-upstream.yaml
name: Check Upstream Updates
on:
  schedule:
    - cron: '0 0 * * 1'  # Weekly on Monday
  workflow_dispatch:

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Check upstream
        run: |
          git remote add upstream https://github.com/GoogleCloudPlatform/pbmm-on-gcp-onboarding.git
          git fetch upstream
          
          BEHIND=$(git rev-list HEAD..upstream/main --count)
          if [ "$BEHIND" -gt 0 ]; then
            echo "::notice::Upstream is $BEHIND commits ahead. Consider syncing."
            git log HEAD..upstream/main --oneline >> $GITHUB_STEP_SUMMARY
          fi
```

---

## Support Resources

- **Bootstrap Issues**: See `0-bootstrap/README-GitHub.md`
- **Network Config**: See `3-networks/README.md`
- **General Troubleshooting**: Check GitHub Actions logs
- **Cost Questions**: Review GCP billing console
- **PBMM Compliance**: See `docs/technical-design-document.md`

---

**Questions or issues?** Open an issue in your repository or review the GitHub Actions logs for specific errors.
