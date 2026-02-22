# Quick Start: GitHub Actions with Workload Identity Federation

This is a condensed guide for setting up the GCP Landing Zone with GitHub Actions and Workload Identity Federation (WIF).

## Prerequisites Checklist

- [ ] GCP Organization ID
- [ ] GCP Billing Account ID
- [ ] Required IAM roles on your GCP account
- [ ] 1 private GitHub repository created (`gcp-landing-zone` or your preferred name)
- [ ] GitHub fine-grained Personal Access Token
- [ ] GitHub CLI installed and authenticated
- [ ] Tools: gcloud, terraform, git, jq

## Quick Setup (30 minutes)

### Phase 1: Secure GitHub Repository (5 min)

```bash
# Authenticate to GitHub
gh auth login

# Run automated security setup
./scripts/setup-github-security.sh your-github-username gcp-landing-zone
```

This configures:
- Branch protection on `main` branch (used as production)
- Required status checks
- Security scanning
- Secret scanning with push protection

**Manual verification:** Check repository Settings → Branches → Branch protection rules

### Phase 2: Configure Bootstrap (10 min)

```bash
# Navigate to bootstrap directory
cd 0-bootstrap

# Run interactive configuration
../scripts/configure-bootstrap-wif.sh gcp-landing-zone
```

The script will:
1. ✅ Validate prerequisites
2. ✅ Collect configuration
3. ✅ Enable GitHub provider in Terraform
4. ✅ Generate terraform.tfvars
5. ✅ Initialize Terraform
6. ✅ Create execution plan
7. ✅ Validate with OPA policies

### Phase 3: Deploy Bootstrap (15 min)

```bash
# Set GitHub token
export TF_VAR_gh_token="your-fine-grained-pat"

# Review the plan
terraform show bootstrap.tfplan

# Apply the configuration
terraform apply bootstrap.tfplan
```

**What gets created:**
- `prj-b-seed-xxxx` - Terraform state bucket, service accounts
- `prj-b-cicd-wif-gh-xxxx` - Workload Identity Federation
- GitHub repository secrets automatically configured (single repo)

### Phase 4: Configure Remote State (5 min)

```bash
# Get state bucket name
export TF_STATE_BUCKET=$(terraform output -raw gcs_bucket_tfstate)

# Create backend configuration
cat > backend.tf <<EOF
terraform {
  backend "gcs" {
    bucket = "${TF_STATE_BUCKET}"
    prefix = "terraform/bootstrap/state"
  }
}
EOF

# Migrate state to GCS
terraform init -migrate-state

# Verify (should show no changes)
terraform plan
```

### Phase 5: Push to GitHub (5 min)

```bash
# Add all files
git add .

# Commit
git commit -m "Configure bootstrap with WIF for GitHub Actions"

# Push to plan branch
git push --set-upstream origin plan

# Create pull request to main
gh pr create \
  --base main \
  --head plan \
  --title "Initial bootstrap configuration" \
  --body "Configure bootstrap infrastructure with Workload Identity Federation"
```

### Phase 6: Validate & Merge

1. Go to repository Actions tab
2. Wait for workflow to complete
3. Review terraform plan in workflow logs
4. Check OPA validation passed
5. Merge PR to main

```bash
# Merge via CLI
gh pr merge --squash

# Or merge via GitHub UI
```

The merge will trigger the apply workflow on main branch.

## Architecture Created

```
GCP Organization
└── fldr-bootstrap/
    ├── prj-b-seed (State & SA)
    │   ├── GCS Bucket (terraform state)
    │   └── Service Accounts
    │       ├── bootstrap-sa
    │       ├── org-sa
    │       ├── env-sa
    │       ├── net-sa
    │       └── proj-sa
    └── prj-b-cicd-wif-gh (Authentication)
        ├── Workload Identity Pool
        ├── WIF Provider (GitHub OIDC)
        └── IAM Bindings (monorepo → SA mapping)

GitHub Repository (Monorepo)
└── gcp-landing-zone
    ├── 0-bootstrap/ (secrets configured)
    ├── 1-org/
    ├── 2-environments/
    ├── 3-networks/
    ├── 4-projects/
    ├── .github/workflows/ (all 5 workflows)
    ├── policy-library/
    └── scripts/
```

## Verification Commands

```bash
# Check projects
gcloud projects list --filter="name:prj-b-*"

# Check service accounts
export CICD_PROJECT=$(terraform output -raw cicd_project_id)
gcloud iam service-accounts list --project=${CICD_PROJECT}

# Check WIF pool
gcloud iam workload-identity-pools list \
  --location=global \
  --project=${CICD_PROJECT}

# Check GitHub secrets (single repo with all secrets)
gh secret list --repo your-github-username/gcp-landing-zone
```

## Common Issues & Solutions

### Issue: "Permission denied" during terraform apply

**Solution:**
```bash
# Verify you have required roles
gcloud organizations get-iam-policy ${TF_VAR_org_id} \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:$(gcloud config get-value account)"
```

### Issue: GitHub provider authentication fails

**Solution:**
```bash
# Test your PAT
curl -H "Authorization: token ${TF_VAR_gh_token}" \
  https://api.github.com/user

# Verify PAT has correct permissions:
# - Actions: Read and Write
# - Secrets: Read and Write
# - Variables: Read and Write
```

### Issue: Workflow fails with "Service account not found"

**Solution:** Wait 60 seconds for IAM bindings to propagate, then re-run workflow.

### Issue: OPA validation fails

**Solution:**
```bash
# Review violations
terraform show -json bootstrap.tfplan | \
  gcloud beta terraform vet - \
  --policy-library=./policy-library \
  --project=${TF_VAR_org_id}

# Fix violations and re-plan
```

## Next Steps

After bootstrap is deployed:

1. **Deploy 1-org (Organization)**
   ```bash
   cd ../1-org
   # Follow same pattern: configure → plan → PR → merge
   ```

2. **Deploy 2-environments**
   ```bash
   cd ../2-environments
   # Same workflow pattern
   ```

3. **Deploy 3-networks (Dual-SVPC)**
   ```bash
   cd ../3-networks
   # Creates Shared VPCs per environment
   ```

4. **Deploy 4-projects**
   ```bash
   cd ../4-projects
   # Creates application projects
   ```

## Workflow Pattern

All stages follow this pattern:

```
Developer Flow:
1. Clone repository
2. Create feature/plan branch
3. Make changes
4. Push to plan branch
5. Create PR to main
6. GitHub Actions runs: plan + OPA validate
7. Review plan in PR comments
8. Merge PR to main
9. GitHub Actions runs: plan + OPA validate + apply

Production Flow (main branch):
Merge → Plan → Validate → Apply → Update State
```

## Security Best Practices

✅ **DO:**
- Use fine-grained PATs with minimal permissions
- Rotate PATs every 90 days
- Enable branch protection on main
- Require PR reviews for all changes
- Enable secret scanning with push protection
- Use least privilege for service accounts
- Monitor GitHub Actions workflow runs

❌ **DON'T:**
- Commit secrets to repositories
- Use classic PATs (use fine-grained)
- Bypass branch protection rules
- Share PATs between team members
- Store credentials in terraform.tfvars
- Force push to protected branches

## Resources

- **Detailed Guides:**
  - [GitHub Security Setup](./GITHUB-SECURITY.md)
  - [Bootstrap WIF Setup](./BOOTSTRAP-WIF-SETUP.md)
  - [CI/CD Configuration](./CICD-SETUP.md)
  - [Workflow Consolidation](./WORKFLOWS-CONSOLIDATED.md)

- **Scripts:**
  - `scripts/setup-github-security.sh` - Automated security config
  - `scripts/configure-bootstrap-wif.sh` - Interactive bootstrap setup
  - `scripts/validate-policies-local.sh` - Local OPA validation

- **Architecture:**
  - [Architecture Overview](./ARCHITECTURE.md)
  - [Network Architecture](../3-networks/README.md)
  - [Addressing Plan](./addressing-plan/README.md)

## Support

- Review [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for common issues
- Check GitHub Actions logs for workflow failures
- Review GCP Cloud Logging in seed project
- Validate with `gcloud beta terraform vet`

## Quick Commands Reference

```bash
# Validate requirements
./scripts/validate-requirements.sh -o ORG_ID -b BILLING_ACCOUNT -u USER_EMAIL -e

# Setup GitHub security
./scripts/setup-github-security.sh github-username

# Configure bootstrap
cd 0-bootstrap && ../scripts/configure-bootstrap-wif.sh

# Validate policies locally
./scripts/validate-policies-local.sh

# Deploy
terraform init && terraform plan -out=plan.tfplan && terraform apply plan.tfplan

# Check projects
gcloud projects list --filter="name:prj-*"

# Check service accounts
gcloud iam service-accounts list --project=PROJECT_ID

# Check GitHub secrets
gh secret list --repo owner/repo

# View workflow runs
gh run list --workflow=0-bootstrap.yaml

# View workflow logs
gh run view RUN_ID --log
```

---

**Estimated Total Time:** 30-45 minutes for initial bootstrap setup

**Next Milestone:** Deploy 1-org (Organization policies) - ~20 minutes
