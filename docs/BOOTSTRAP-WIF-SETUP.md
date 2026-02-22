# Bootstrap Setup with Workload Identity Federation (WIF)

This guide walks through setting up the 0-bootstrap stage with Workload Identity Federation for GitHub Actions authentication to GCP.

## Prerequisites

✅ Before starting, ensure you have:

- [x] GitHub repositories created and secured (see [GITHUB-SECURITY.md](./GITHUB-SECURITY.md))
- [x] Google Cloud SDK installed (version 393.0.0+)
- [x] Terraform installed (version 1.3.0+)
- [x] Git installed (version 2.28.0+)
- [x] jq installed
- [x] Fine-grained GitHub Personal Access Token created
- [x] GCP Organization ID
- [x] GCP Billing Account ID
- [x] Required GCP IAM roles:
  - `roles/resourcemanager.organizationAdmin`
  - `roles/orgpolicy.policyAdmin`
  - `roles/resourcemanager.projectCreator`
  - `roles/billing.admin`
  - `roles/resourcemanager.folderCreator`

## What is Workload Identity Federation?

Workload Identity Federation (WIF) allows GitHub Actions to authenticate to GCP **without service account keys**. This is more secure because:

- ✅ No long-lived credentials stored in GitHub
- ✅ Automatic token rotation
- ✅ Scoped permissions per repository
- ✅ Audit trail through Cloud IAM
- ✅ Compliance with security best practices

### How It Works:

1. GitHub Actions generates an OIDC token for the workflow run
2. Token includes repository, workflow, and branch information
3. GCP Workload Identity Pool verifies the token
4. Temporary GCP credentials are issued to the workflow
5. Workflow uses credentials to run Terraform

## Architecture

The bootstrap stage creates:

```
GCP Organization
└── fldr-bootstrap/
    ├── prj-b-seed               (Terraform state & service accounts)
    │   ├── GCS bucket           (terraform state)
    │   └── Service Accounts     (per-stage: bootstrap, org, env, net, proj)
    │
    └── prj-b-cicd-wif-gh       (WIF authentication)
        ├── Workload Identity Pool
        ├── Workload Identity Provider (GitHub OIDC)
        └── IAM Bindings          (maps monorepo to service accounts)
```

## Step-by-Step Setup

### 1. Set Environment Variables

Export required values to avoid entering them multiple times:

```bash
export TF_VAR_org_id="YOUR_ORG_ID"
export TF_VAR_billing_account="YOUR_BILLING_ACCOUNT"
export TF_VAR_gh_token="YOUR_FINE_GRAINED_PAT"

# GitHub repository configuration
export GITHUB_OWNER="your-github-username-or-org"
export REPO_NAME="gcp-landing-zone"
```

Verify:
```bash
echo "Org ID: ${TF_VAR_org_id}"
echo "Billing: ${TF_VAR_billing_account}"
echo "GitHub: ${GITHUB_OWNER}/${REPO_NAME}"
```

### 2. Clone and Prepare Repository

```bash
# Clone your landing zone repository
git clone git@github.com:${GITHUB_OWNER}/${REPO_NAME}.git
cd ${REPO_NAME}

# Create initial commit if repo is empty
git commit --allow-empty -m 'Initial commit'
git push origin main

# Create plan branch for development
git checkout -b plan
```

### 3. Copy Foundation Code

If you're starting from the terraform-example-foundation template:

```bash
# This step is only needed if you're copying from a separate template
# Skip if you already have the code in your repo

# Copy bootstrap terraform code
cp -R ../terraform-example-foundation/0-bootstrap ./0-bootstrap

# Copy other stages
cp -R ../terraform-example-foundation/1-org ./1-org
cp -R ../terraform-example-foundation/2-environments ./2-environments
cp -R ../terraform-example-foundation/3-networks ./3-networks
cp -R ../terraform-example-foundation/4-projects ./4-projects

# Copy policy library
cp -R ../terraform-example-foundation/policy-library ./policy-library

# Copy scripts
cp -R ../terraform-example-foundation/scripts ./scripts
chmod +x scripts/*.sh
```

**Note:** If you already have this structure (you're in the gcp-landing-zone repo), skip this step.

### 4. Configure Terraform for GitHub Actions

Navigate to the bootstrap directory:

```bash
cd 0-bootstrap
```

#### 4.1. Enable GitHub Provider

Edit [versions.tf](../0-bootstrap/versions.tf) and uncomment the GitHub provider:

```terraform
terraform {
  required_version = ">= 1.3.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.50, < 6"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 4.50, < 6"
    }
    # Un-comment github required_providers when using GitHub Actions
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}
```

#### 4.2. Enable GitHub Variables

Edit [variables.tf](../0-bootstrap/variables.tf) and uncomment GitHub variables:

```terraform
/* ----------------------------------------
    Specific to github_bootstrap
   ---------------------------------------- */

variable "gh_repos" {
  description = <<EOT
  Configuration for the GitHub Repositories to be used to deploy the Terraform Example Foundation stages.
  owner: The owner of the repositories. An user or an organization.
  bootstrap: The repository to host the code of the bootstrap stage.
  organization: The repository to host the code of the organization stage.
  environments: The repository to host the code of the environments stage.
  networks: The repository to host the code of the networks stage.
  projects: The repository to host the code of the projects stage.
  EOT
  type = object({
    owner        = string,
    bootstrap    = string,
    organization = string,
    environments = string,
    networks     = string,
    projects     = string,
  })
}

variable "gh_token" {
  description = "A fine-grained personal access token for the user or organization."
  type        = string
  sensitive   = true
}
```

#### 4.3. Enable GitHub Resources

Rename the GitHub configuration file:

```bash
mv github.tf.example github.tf
```

#### 4.4. Disable Cloud Build (if present)

```bash
# Rename Cloud Build config if it exists
[ -f cb.tf ] && mv cb.tf cb.tf.example
```

#### 4.5. Update Outputs

Edit [outputs.tf](../0-bootstrap/outputs.tf.local):

Comment out Cloud Build outputs (if any) and ensure GitHub outputs are uncommented:

```terraform
# GitHub Actions WIF Outputs
output "cicd_project_id" {
  description = "Project ID of the CI/CD project for WIF"
  value       = module.gh_cicd.project_id
}

output "wif_provider_name" {
  description = "Workload Identity Federation provider name"
  value       = module.gh_oidc.provider_name
}

output "gh_service_accounts" {
  description = "Service account emails for each stage"
  value = {
    for k, sa in google_service_account.terraform-env-sa : k => sa.email
  }
  sensitive = true
}
```

### 5. Configure Terraform Variables

Create `terraform.tfvars` file:

```bash
cat > terraform.tfvars <<EOF
# GCP Organization Configuration
org_id = "${TF_VAR_org_id}"
billing_account = "${TF_VAR_billing_account}"

# Default region for resources
default_region = "northamerica-northeast1"

# Project naming prefix (max 3 characters)
project_prefix = "prj"
folder_prefix = "fldr"
bucket_prefix = "bkt"

# Required groups for IAM
groups = {
  create_required_groups = false
  required_groups = {
    group_org_admins           = "gcp-organization-admins@yourdomain.com"
    group_billing_admins       = "gcp-billing-admins@yourdomain.com"
    billing_data_users         = "gcp-billing-data@yourdomain.com"
    audit_data_users           = "gcp-audit-data@yourdomain.com"
    monitoring_workspace_users = "gcp-monitoring-workspace@yourdomain.com"
  }
}

# GitHub Actions Configuration
gh_repos = {
  owner        = "${GITHUB_OWNER}"
  bootstrap    = "${REPO_NAME}"
  organization = "${REPO_NAME}"
  environments = "${REPO_NAME}"
  networks     = "${REPO_NAME}"
  projects     = "${REPO_NAME}"
}

# Note: gh_token is provided via TF_VAR_gh_token environment variable
# to avoid storing it in plain text

EOF
```

**Important:** Update the email addresses in the `groups` section with your actual domain.

### 6. Validate Configuration

Run the validation script:

```bash
../../gcp-landing-zone/scripts/validate-requirements.sh \
  -o ${TF_VAR_org_id} \
  -b ${TF_VAR_billing_account} \
  -u $(gcloud config get-value account) \
  -e
```

This checks:
- ✅ Required GCP APIs are accessible
- ✅ IAM permissions are correct
- ✅ Billing account is valid
- ✅ gcloud CLI is properly configured

### 7. Initialize and Plan Terraform

```bash
# Initialize Terraform
terraform init

# Create execution plan
terraform plan -input=false -out=bootstrap.tfplan
```

Review the plan output. You should see resources being created for:
- Bootstrap folder
- Seed project (prj-b-seed)
- CI/CD WIF project (prj-b-cicd-wif-gh)
- Service accounts (bootstrap, org, env, net, proj)
- GCS bucket for Terraform state
- Workload Identity Pool and Provider
- IAM bindings
- GitHub secrets

### 8. Validate Policies

```bash
# Convert plan to JSON
terraform show -json bootstrap.tfplan > bootstrap.json

# Validate against OPA policies
gcloud beta terraform vet bootstrap.json \
  --policy-library="./policy-library" \
  --project=${TF_VAR_org_id}
```

Or use the local validation script:

```bash
../scripts/validate-policies-local.sh
```

### 9. Apply Bootstrap Configuration

If validation passes:

```bash
terraform apply bootstrap.tfplan
```

This will take 5-10 minutes. The apply will:
- ✅ Create GCP projects
- ✅ Set up Workload Identity Federation
- ✅ Create service accounts with appropriate permissions
- ✅ Configure GitHub repository secrets automatically
- ✅ Create GCS bucket for Terraform state

### 10. Capture Outputs

After successful apply:

```bash
# CI/CD Project ID
export CICD_PROJECT_ID=$(terraform output -raw cicd_project_id)
echo "CI/CD Project: ${CICD_PROJECT_ID}"

# WIF Provider Name
export WIF_PROVIDER=$(terraform output -raw wif_provider_name)
echo "WIF Provider: ${WIF_PROVIDER}"

# State bucket
export TF_STATE_BUCKET=$(terraform output -raw gcs_bucket_tfstate)
echo "State Bucket: ${TF_STATE_BUCKET}"

# Service accounts
terraform output -json gh_service_accounts > /tmp/service_accounts.json
echo "Service account emails saved to /tmp/service_accounts.json"
```

### 11. Configure Remote State

Update backend configuration to use GCS:

```bash
# Create backend.tf
cat > backend.tf <<EOF
terraform {
  backend "gcs" {
    bucket = "${TF_STATE_BUCKET}"
    prefix = "terraform/bootstrap/state"
  }
}
EOF

# Reinitialize to migrate state to GCS
terraform init -migrate-state

# Verify state migration
terraform plan
```

You should see "No changes" indicating state was successfully migrated.

### 12. Commit and Push to GitHub

```bash
# Add all files
git add .

# Commit configuration
git commit -m "Configure bootstrap with WIF for GitHub Actions"

# Push to plan branch
git push --set-upstream origin plan
```

### 13. Create Pull Request

```bash
# Using GitHub CLI
gh pr create \
  --base production \
  --head plan \
  --title "Initial bootstrap configuration" \
  --body "Configure bootstrap infrastructure with Workload Identity Federation for GitHub Actions"
```

Or manually at: `https://github.com/${GITHUB_OWNER}/${BOOTSTRAP_REPO}/pull/new/plan`

### 14. Review Workflow Run

1. Navigate to Actions tab in your repository
2. Wait for `0-bootstrap` workflow to complete
3. Review the terraform plan output in the workflow logs
4. Verify OPA policy validation passed
5. Check for any violations or warnings

### 15. Merge to Main (Production)

If the plan looks good and all checks pass:

```bash
# Merge the PR
gh pr merge --squash

# Or approve and merge via GitHub UI
```

The merge will trigger the apply workflow which will:
- ✅ Run terraform plan again
- ✅ Run OPA validation
- ✅ Apply the infrastructure changes

## Verification

After deployment, verify everything is working:

### Check GCP Projects

```bash
gcloud projects list --filter="name:prj-b-*"
```

You should see:
- `prj-b-seed-xxxx` - Terraform state project
- `prj-b-cicd-wif-gh-xxxx` - WIF project

### Check Service Accounts

```bash
gcloud iam service-accounts list \
  --project=${CICD_PROJECT_ID} \
  --format="table(email,description)"
```

### Check Workload Identity Pool

```bash
gcloud iam workload-identity-pools list \
  --location=global \
  --project=${CICD_PROJECT_ID}
```

### Check GitHub Secrets

Each repository should now have these secrets:
- `PROJECT_ID` - CI/CD project ID
- `WIF_PROVIDER_NAME` - Workload Identity provider
- `TF_BACKEND` - GCS bucket for state
- `TF_VAR_gh_token` - GitHub token
- `SERVICE_ACCOUNT_EMAIL` - Stage-specific service account

Verify:
```bash
gh secret list --repo ${GITHUB_OWNER}/${BOOTSTRAP_REPO}
```

### Test GitHub Actions Authentication

Create a test workflow run:

```bash
# Create a small change
echo "# Bootstrap Complete" >> README.md
git add README.md
git commit -m "test: verify GitHub Actions"
git push origin plan

# Check the workflow run
gh run list --workflow=0-bootstrap.yaml
```

## Troubleshooting

### Issue: Terraform apply fails with permission denied

**Solution:** Verify your user has the required IAM roles:
```bash
gcloud organizations get-iam-policy ${TF_VAR_org_id} \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:$(gcloud config get-value account)"
```

### Issue: GitHub provider authentication fails

**Solution:** Verify your PAT is valid and has correct permissions:
```bash
curl -H "Authorization: token ${TF_VAR_gh_token}" \
  https://api.github.com/user
```

### Issue: Workload Identity Federation errors in GitHub Actions

**Solution:** Check the WIF configuration:
```bash
gcloud iam workload-identity-pools providers describe foundation-gh-provider \
  --workload-identity-pool=foundation-pool \
  --location=global \
  --project=${CICD_PROJECT_ID}
```

### Issue: State bucket not found

**Solution:** Verify the bucket was created:
```bash
gsutil ls -p ${CICD_PROJECT_ID} | grep ${TF_STATE_BUCKET}
```

### Issue: GitHub Actions workflow fails with "Service account not found"

**Solution:** Verify service account exists and has correct IAM bindings:
```bash
gcloud iam service-accounts get-iam-policy \
  $(terraform output -raw gh_service_accounts | jq -r '.bootstrap') \
  --project=${CICD_PROJECT_ID}
```

## Security Considerations

### Secrets Management
- ✅ Never commit `terraform.tfvars` with real values
- ✅ Use `.gitignore` to exclude sensitive files
- ✅ Rotate GitHub PAT every 90 days
- ✅ Use environment variables for credentials

### Access Control
- ✅ Limit who can merge to production branch
- ✅ Require PR reviews for all changes
- ✅ Enable branch protection rules
- ✅ Use least privilege for service accounts

### Audit Logging
- ✅ Enable Cloud Audit Logs in seed project
- ✅ Monitor Workload Identity Federation usage
- ✅ Review GitHub Actions workflow runs regularly
- ✅ Set up alerts for failed deployments

## Next Steps

Now that bootstrap is configured, proceed to:

1. [Deploy 1-org (Organization)](../1-org/README.md) - Organization policies and structure
2. [Deploy 2-environments](../2-environments/README.md) - Environment setup
3. [Deploy 3-networks](../3-networks/README.md) - Dual-SVPC network architecture
4. [Deploy 4-projects](../4-projects/README.md) - Application projects

Each stage follows the same pattern:
1. Clone respective repository
2. Copy foundation code
3. Configure variables
4. Push to plan branch
5. Create PR to production
6. Review and merge

## Additional Resources

- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [GitHub OIDC with GCP](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-google-cloud-platform)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GitHub Actions Security](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)

## Support

For issues or questions:
- Check [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)
- Review workflow logs in GitHub Actions
- Check GCP Cloud Logging in the seed project
- Review Terraform error messages carefully
