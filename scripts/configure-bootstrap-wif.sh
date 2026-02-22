#!/bin/bash
# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

###############################################################################
# Bootstrap Configuration Script for GitHub Actions with WIF
#
# This script automates the configuration of the 0-bootstrap stage
# for GitHub Actions with Workload Identity Federation (monorepo approach).
#
# Usage: ./configure-bootstrap-wif.sh [repo-name]
#        Default repo name: gcp-landing-zone
###############################################################################

set -e
set -u
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration file
CONFIG_FILE="bootstrap-config.env"

# Default repository name
DEFAULT_REPO_NAME="gcp-landing-zone"

# Function to print colored output
print_message() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

print_success() {
    print_message "${GREEN}" "✅ $*"
}

print_error() {
    print_message "${RED}" "❌ $*"
}

print_warning() {
    print_message "${YELLOW}" "⚠️  $*"
}

print_info() {
    print_message "${BLUE}" "ℹ️  $*"
}

print_step() {
    echo ""
    print_message "${BLUE}" "============================================================"
    print_message "${BLUE}" "$*"
    print_message "${BLUE}" "============================================================"
    echo ""
}

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "$1 is not installed"
        return 1
    fi
    print_success "$1 is installed"
    return 0
}

# Function to validate prerequisites
validate_prerequisites() {
    print_step "Step 1: Validating Prerequisites"
    
    local missing=0
    
    check_command gcloud || ((missing++))
    check_command terraform || ((missing++))
    check_command git || ((missing++))
    check_command jq || ((missing++))
    check_command gh || ((missing++))
    
    if [[ ${missing} -gt 0 ]]; then
        print_error "${missing} required tool(s) missing"
        echo ""
        print_info "Install missing tools:"
        echo "  macOS: brew install google-cloud-sdk terraform git jq gh"
        echo "  Linux: Follow official installation guides"
        exit 1
    fi
    
    print_success "All prerequisites installed"
}

# Function to collect configuration
collect_configuration() {
    print_step "Step 2: Collecting Configuration"
    
    # Check if config file exists
    if [[ -f "${CONFIG_FILE}" ]]; then
        print_info "Found existing configuration file: ${CONFIG_FILE}"
        read -p "Load existing configuration? (Y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
            source "${CONFIG_FILE}"
            print_success "Loaded existing configuration"
            return 0
        fi
    fi
    
    # Collect GCP configuration
    print_info "GCP Configuration"
    echo ""
    
    read -p "Enter your GCP Organization ID: " ORG_ID
    read -p "Enter your GCP Billing Account ID: " BILLING_ACCOUNT
    read -p "Enter default region (default: northamerica-northeast1): " DEFAULT_REGION
    DEFAULT_REGION=${DEFAULT_REGION:-northamerica-northeast1}
    
    echo ""
    print_info "GitHub Configuration"
    
    # Check if repo name was provided as argument
    if [[ $# -ge 1 ]]; then
        REPO_NAME=$1
        print_info "Using repository name from argument: ${REPO_NAME}"
    else
        read -p "Enter repository name (default: ${DEFAULT_REPO_NAME}): " REPO_NAME
        REPO_NAME=${REPO_NAME:-${DEFAULT_REPO_NAME}}
    fime (default: gcp-networks): " NET_REPO
    NET_REPO=${NET_REPO:-gcp-networks}
    read -p "Enter projects repository name (default: gcp-projects): " PROJ_REPO
     PROJ_REPO=${PROJ_REPO:-gcp-projects}
    
    echo ""
    print_info "IAM Groups Configuration"
    echo ""
    
    read -p "Enter your organization domain (e.g., example.com): " DOMAIN
    
    # Save configuration
    cat > "${CONFIG_FILE}" <<EOF
# GCP Configuration
export ORG_ID="${ORG_ID}"
export BILLING_ACCOUNT="${BILLING_ACCOUNT}"
export DEFAULT_REGION="${DEFAULT_REGION}"

# GitHub Configuration
export GITHUB_OWNER="$ (Monorepo)
export GITHUB_OWNER="${GITHUB_OWNER}"
export REPO_NAME="${REPO_NAME
# Domain
export DOMAIN="${DOMAIN}"

# Terraform variables
export TF_VAR_org_id="${ORG_ID}"
export TF_VAR_billing_account="${BILLING_ACCOUNT}"
EOF
    
    print_success "Configuration saved to ${CONFIG_FILE}"
    print_info "You can source this file later: source ${CONFIG_FILE}"
}

# Function to validate GCP access
validate_gcp_access() {
    print_step "Step 3: Validating GCP Access"
    
    # Check gcloud auth
    local current_account
    current_account=$(gcloud config get-value account 2>/dev/null || echo "")
    
    if [[ -z "${current_account}" ]]; then
        print_error "Not authenticated to GCP"
        print_info "Run: gcloud auth login"
        exit 1
    fi
    
    print_success "Authenticated as: ${current_account}"
    
    # Validate organization access
    print_info "Validating organization access..."
    if ! gcloud organizations describe "${ORG_ID}" &>/dev/null; then
        print_error "Cannot access organization ${ORG_ID}"
        print_info "Verify the Organization ID and your permissions"
        exit 1
    fi
    print_success "Organization ${ORG_ID} is accessible"
    
    # Validate billing account
    print_info "Validating billing account..."
    if ! gcloud beta billing accounts describe "${BILLING_ACCOUNT}" &>/dev/null; then
        print_error "Cannot access billing account ${BILLING_ACCOUNT}"
        exit 1
    fi
    print_success "Billing account ${BILLING_ACCOUNT} is accessible"
}

# Function to configure Terraform files
configure_terraform_files() {
    print_step "Step 4: Configuring Terraform Files"
    
    # Check if we're in 0-bootstrap directory
    if [[ ! -f "versions.tf" ]] || [[ ! -f "variables.tf" ]]; then
        print_error "Must be run from the 0-bootstrap directory"
        exit 1
    fi
    
    # Backup original files
    print_info "Creating backups of original files..."
    cp versions.tf versions.tf.backup
    cp variables.tf variables.tf.backup
    [[ -f outputs.tf ]] && cp outputs.tf outputs.tf.backup
    print_success "Backups created"
    
    # Uncomment GitHub provider in versions.tf
    print_info "Enabling GitHub provider in versions.tf..."
    sed -i.bak '/# Un-comment github required_providers/,/# }/s/# //' versions.tf
    rm -f versions.tf.bak
    print_success "GitHub provider enabled"
    
    # Uncomment GitHub variables in variables.tf
    print_info "Enabling GitHub variables in variables.tf..."
    sed -i.bak '/# Un-comment github_bootstrap/,/# }/s/# //' variables.tf
    rm -f variables.tf.bak
    print_success "GitHub variables enabled"
    
    # Rename files
    print_info "Configuring Terraform files..."
    [[ -f github.tf.example ]] && mv github.tf.example github.tf && print_success "Enabled github.tf"
    [[ -f cb.tf ]] && mv cb.tf cb.tf.example && print_success "Disabled cb.tf"
    [[ -f outputs.tf.example ]] && mv outputs.tf.example outputs.tf && print_success "Enabled outputs.tf"
    
    print_success "Terraform files configured"
}

# Function to generate terraform.tfvars
generate_tfvars() {
    print_step "Step 5: Generating terraform.tfvars"
    
    if [[ -f "terraform.tfvars" ]]; then
        print_warning "terraform.tfvars already exists"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Keeping existing terraform.tfvars"
            return 0
        fi
        mv terraform.tfvars terraform.tfvars.backup
        print_info "Backed up to terraform.tfvars.backup"
    fi
    
    cat > terraform.tfvars <<EOF
# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.

/**
 * Bootstrap Configuration for GitHub Actions with WIF
 * Generated by: configure-bootstrap-wif.sh
 * Date: $(date)
 */

# GCP Organization Configuration
org_id          = "${ORG_ID}"
billing_account = "${BILLING_ACCOUNT}"
default_region  = "${DEFAULT_REGION}"

# Naming prefixes
project_prefix = "prj"
folder_prefix  = "fldr"
bucket_prefix  = "bkt"

# IAM Groups Configuration
groups = {
  create_required_groups = false
  required_groups = {
    group_org_admins           = "gcp-organization-admins@${DOMAIN}"
    group_billing_admins       = "gcp-billing-admins@${DOMAIN}"
    billing_data_users         = "gcp-billing-data@${DOMAIN}"
    audit_data_users           = "gcp-audit-data@${DOMAIN}"
    monitoring_workspace_users = "gcp-monitoring-workspace@${DOMAIN}"
  }
}

# GitHub Actions Configuration
gh_repos = {
  owner        = "${GITHUB_OWNER}"
  bootstrap    = "${BOOTSTRAP_REPO}"
  organization = "${ORG_REPO}"
  environments = "${ENV_REPO}"
  networks     = "${NET_REPO}"
  projects     = "${PROJ_REPO}"
}REPO_NAME}"
  organization = "${REPO_NAME}"
  environments = "${REPO_NAME}"
  networks     = "${REPO_NAME}"
  projects     = "${REPO_NAME
    
    print_success "terraform.tfvars generated"
    print_warning "Remember to set: export TF_VAR_gh_token=\"your-github-pat\""
}

# Function to initialize Terraform
initialize_terraform() {
    print_step "Step 6: Initializing Terraform"
    
    print_info "Running terraform init..."
    if terraform init; then
        print_success "Terraform initialized"
    else
        print_error "Terraform init failed"
        exit 1
    fi
}

# Function to create plan
create_plan() {
    print_step "Step 7: Creating Terraform Plan"
    
    # Check if gh_token is set
    if [[ -z "${TF_VAR_gh_token:-}" ]]; then
        print_warning "TF_VAR_gh_token not set"
        print_info "Please enter your GitHub fine-grained personal access token:"
        read -rs TF_VAR_gh_token
        export TF_VAR_gh_token
        echo ""
    fi
    
    print_info "Running terraform plan..."
    if terraform plan -input=false -out=bootstrap.tfplan; then
        print_success "Terraform plan created"
        print_info "Plan saved to: bootstrap.tfplan"
    else
        print_error "Terraform plan failed"
        exit 1
    fi
}

# Function to validate with OPA
validate_with_opa() {
    print_step "Step 8: Validating with OPA Policies"
    
    print_info "Converting plan to JSON..."
    terraform show -json bootstrap.tfplan > bootstrap.json
    
    if [[ -d "policy-library" ]]; then
        print_info "Running OPA validation..."
        if ../scripts/validate-policies-local.sh; then
            print_success "OPA validation passed"
        else
            print_warning "OPA validation had warnings/errors"
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    else
        print_warning "Policy library not found, skipping OPA validation"
    fi
}

# Function to display next steps
display_next_steps() {
    print_step "Configuration Complete!"
    
    echo ""
    print_success "Bootstrap is ready for deployment"
    echo ""
    print_info "Next steps:"
    echo ""
    echo "  1. Review the terraform plan:"
    echo "     terraform show bootstrap.tfplan"
    echo ""
    echo "  2. Apply the configuration:"
    echo "     terraform apply bootstrap.tfplan"
    echo ""
    echo "  3. Configure remote state:"
    echo "     export TF_STATE_BUCKET=\$(terraform output -raw gcs_bucket_tfstate)"
    echo "     cat > backend.tf <<EOF"
    echo "terraform {"
    echo "  backend \"gcs\" {"
    echo "    bucket = \"\${TF_STATE_BUCKET}\""
    echo "    prefix = \"terraform/bootstrap/state\""
    echo "  }"
    echo "}"
    echo "EOF"
    echo "     terraform init -migrate-state"
    echo ""
    echo "  4. Commit and push to GitHub:"
    echo "     git add ."
    echo "     git commit -m 'Configure bootstrap with WIF'"
    echo "     git push origin plan"
    echo ""
    echo "  5. Create pull request:"
    echo "     gh pr create --base main --head plan \\"
    echo "       --title 'Initial bootstrap configuration' \\"
    echo "       --body 'Configure bootstrap with WIF for GitHub Actions'"
    echo ""
    print_info "For detailed instructions, see:"
    echo "  - docs/BOOTSTRAP-WIF-SETUP.md"
    echo "  - docs/GITHUB-SECURITY.md"
    echo ""
    print_info "Note: Using monorepo approach - all stages in ${REPO_NAME}"
    echo ""
}

# Main function
main() {
    echo ""
    print_message "${GREEN}" "╔════════════════════════════════════════════════════════════════════╗"
    print_message "${GREEN}" "║                                                                    ║"
    print_message "${GREEN}" "║  Bootstrap Configuration for GitHub Actions with WIF               ║"
    print_message "${GREEN}" "║  GCP Landing Zone - Automated Setup                                ║"
    print_message "${GREEN}" "║                                                                    ║"
    print_message "${GREEN}" "╚════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Run setup steps
    validate_prerequisites
    collect_configuration
    validate_gcp_access
    configure_terraform_files
    generate_tfvars
    initialize_terraform
    
    # Ask before planning
    echo ""
    print_warning "Ready to create Terraform plan"
    read -p "Continue? (Y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_info "Stopped before planning. Run 'terraform plan' manually when ready."
        exit 0
    fi
    
    create_plan
    validate_with_opa
    display_next_steps
    
    print_success "Setup completed successfully!"
}

# Handle errors
trap 'print_error "Script failed at line $LINENO"' ERR

# Run main function
main "$@"
