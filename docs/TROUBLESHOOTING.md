# Troubleshooting Guide

## Bootstrap Issues

### Error: "403: Forbidden"

**Symptom**: `terraform apply` fails with permission denied

**Cause**: Insufficient org-level permissions

**Solution**:
```bash
# Check your current permissions
gcloud organizations get-iam-policy ${ORG_ID} \
  --filter="bindings.members:user:YOUR_EMAIL"

# You need these roles:
# - roles/resourcemanager.organizationAdmin
# - roles/billing.admin
# - roles/resourcemanager.folderCreator
```

Contact your GCP org admin to grant permissions.

---

### Error: "Billing account not found"

**Symptom**: Projects fail to create

**Cause**: Billing account ID incorrect or no access

**Solution**:
```bash
# List billing accounts you have access to
gcloud billing accounts list

# Verify you're Billing Admin
gcloud billing accounts get-iam-policy ${BILLING_ACCOUNT}

# Update terraform.tfvars with correct ID
billing_account = "ABCDEF-123456"  # Use the ID from list command
```

---

### Error: "Backend initialization required"

**Symptom**: `terraform plan` fails with backend error

**Cause**: Backend not configured or state bucket doesn't exist

**Solution**:
```bash
cd 0-bootstrap/envs/shared

# Check if backend bucket exists
export BACKEND_BUCKET=$(terraform output -raw gcs_bucket_tfstate)
gsutil ls gs://${BACKEND_BUCKET}

# Reconfigure backend
terraform init -reconfigure
```

---

## GitHub Actions Issues

### Workflow doesn't run

**Symptom**: PR created but no workflows triggered

**Cause 1**: Path filter doesn't match changed files

**Solution**:
```bash
# Check which files changed
git diff origin/production...plan --name-only

# Verify workflow path includes those files
cat .github/workflows/1-org-plan.yaml | grep "paths:"
```

**Cause 2**: Workflow file has syntax errors

**Solution**:
```bash
# Validate YAML syntax
cat .github/workflows/1-org-plan.yaml | python -c 'import yaml, sys; yaml.safe_load(sys.stdin)'
```

---

### Error: "Authentication failed"

**Symptom**: Workflow fails at auth step

**Cause**: Workload Identity Federation not configured

**Solution**:
```bash
# Verify secrets exist
gh secret list

# Required secrets:
# - WIF_PROVIDER_NAME
# - WIF_SERVICE_ACCOUNT
# - GH_TOKEN

# Check bootstrap outputs
cd 0-bootstrap/envs/shared
terraform output
```

If missing, re-run bootstrap terraform apply.

---

### Error: "Error locking state"

**Symptom**: Terraform apply fails with state lock error

**Cause**: Previous run didn't complete cleanly

**Solution**:
```bash
# List locks
gsutil ls gs://${BACKEND_BUCKET}/**/*.tflock

# Force unlock (use ID from error message)
terraform force-unlock <LOCK_ID>

# Or manually delete lock file
gsutil rm gs://${BACKEND_BUCKET}/terraform/state/default.tflock
```

---

## Network Issues

### Error: "Quota exceeded"

**Symptom**: VPC creation fails with quota error

**Cause**: GCP project quota limits

**Solution**:
```bash
# Check current quotas
gcloud compute project-info describe --project=PROJECT_ID

# Request quota increase:
# https://console.cloud.google.com/iam-admin/quotas

# Common quotas to increase:
# - Networks: 15 (default is 5)
# - Firewall rules: 200 (default is 100)
```

---

### Cloud NAT not working

**Symptom**: VMs can't reach internet despite NAT configured

**Cause 1**: NAT not enabled in terraform.tfvars

**Solution**:
```bash
cd 3-networks/envs/production
grep enable_nat terraform.tfvars

# Should be:
enable_nat = true
```

**Cause 2**: VM using wrong subnet

**Solution**: Verify VM is in correct subnet that has NAT gateway

---

## Project Issues

### Error: "Project already exists"

**Symptom**: Terraform fails with "project already exists"

**Cause**: Project ID used previously

**Solution**:
```bash
# Check if project exists
gcloud projects list --filter="projectId:YOUR_PROJECT_ID"

# Option 1: Import existing project
terraform import google_project.project YOUR_PROJECT_ID

# Option 2: Change project ID in terraform.tfvars
# Project IDs must be globally unique
```

---

### Error: "API not enabled"

**Symptom**: Resources fail to create

**Cause**: Required APIs not enabled

**Solution**:
```bash
# Enable required APIs
gcloud services enable compute.googleapis.com \
  cloudresourcemanager.googleapis.com \
  cloudbilling.googleapis.com \
  iam.googleapis.com \
  serviceusage.googleapis.com
```

---

## State Management Issues

### Error: "State file not found"

**Symptom**: Terraform can't find existing state

**Cause**: Backend configuration incorrect

**Solution**:
```bash
# Verify backend configuration
cat backend.tf

# Check bucket exists and is accessible
gsutil ls gs://${BACKEND_BUCKET}/terraform/state/

# Re-initialize
terraform init -reconfigure
```

---

### State drift detected

**Symptom**: Terraform shows unexpected changes

**Cause**: Manual changes made in GCP Console

**Solution**:
```bash
# See what drifted
terraform plan

# Option 1: Import manual changes to state
terraform import <resource_type>.<name> <resource_id>

# Option 2: Let terraform revert manual changes
terraform apply
```

---

## Permission Issues

### Error: "Permission denied on service account"

**Symptom**: Can't create service accounts

**Cause**: Missing Service Account Admin role

**Solution**:
```bash
# Grant yourself the role
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:YOUR_EMAIL" \
  --role="roles/iam.serviceAccountAdmin"
```

---

### Error: "Folder creation denied"

**Symptom**: Can't create folders under organization

**Cause**: Missing Folder Creator role

**Solution**:
```bash
# Grant role at org level
gcloud organizations add-iam-policy-binding ${ORG_ID} \
  --member="user:YOUR_EMAIL" \
  --role="roles/resourcemanager.folderCreator"
```

---

## General Debugging

### Enable Terraform Debug Logging

```bash
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform-debug.log
terraform plan
```

### Check Which Resources Failed

```bash
# Review terraform output
terraform apply 2>&1 | tee apply.log

# Search for errors
grep -i error apply.log
```

### Validate Terraform Syntax

```bash
terraform validate
terraform fmt -check -recursive
```

### Check Provider Versions

```bash
terraform version
cat versions.tf

# Upgrade providers if needed
terraform init -upgrade
```

---

## Recovery Procedures

### Completely Reset a Stage

```bash
cd <stage>/envs/<env>

# Destroy all resources (⚠️ DANGEROUS)
terraform destroy

# Remove state
rm terraform.tfstate*
gsutil rm -r gs://${BACKEND_BUCKET}/terraform/state/<stage>/<env>/

# Start fresh
terraform init
terraform plan
```

### Restore from State Backup

```bash
# List state backups
gsutil ls gs://${BACKEND_BUCKET}/terraform/state/default.tfstate.*

# Copy backup to current state
gsutil cp gs://${BACKEND_BUCKET}/terraform/state/default.tfstate.TIMESTAMP \
  gs://${BACKEND_BUCKET}/terraform/state/default.tfstate
```

---

## Getting Help

### Check Logs

**Bootstrap stage**:
```bash
cd 0-bootstrap/envs/shared
less terraform.log
```

**GitHub Actions**:
- Go to Actions tab
- Click on failed workflow
- View job logs

**GCP Console**:
- Cloud Logging: https://console.cloud.google.com/logs
- Filter by project/resource

### Gather Debug Info

```bash
# Terraform version
terraform version

# GCP SDK version
gcloud version

# Current authentication
gcloud auth list
gcloud config list

# Environment variables
env | grep -E '(TF_|GOOGLE_|GCP_)'
```

### Common Commands

```bash
# Validate configuration
terraform validate

# Format code
terraform fmt -recursive

# Show current state
terraform show

# List resources in state
terraform state list

# Get resource details
terraform state show <resource>

# Refresh state from actual infrastructure
terraform refresh

# Plan without applying
terraform plan -out=tfplan

# Apply a specific plan file
terraform apply tfplan
```

---

## Still Stuck?

1. Check terraform output carefully - error is usually clear
2. Search error message on Stack Overflow
3. Review [Terraform GCP Provider docs](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
4. Check [GCP documentation](https://cloud.google.com/docs)
5. Review [PBMM repo issues](https://github.com/GoogleCloudPlatform/pbmm-on-gcp-onboarding/issues)
