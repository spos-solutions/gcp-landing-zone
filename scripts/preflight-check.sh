#!/bin/bash

# PBMM GCP Landing Zone - Pre-Flight Check Script
# This script validates your environment before deploying the landing zone

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Helper functions
print_header() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
}

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

# Check required tools
print_header "Checking Required Tools"

# Check gcloud
if command -v gcloud &> /dev/null; then
    GCLOUD_VERSION=$(gcloud --version | head -n 1 | awk '{print $4}')
    check_pass "gcloud CLI installed (version: $GCLOUD_VERSION)"
else
    check_fail "gcloud CLI not found. Install from: https://cloud.google.com/sdk/install"
fi

# Check terraform
if command -v terraform &> /dev/null; then
    TF_VERSION=$(terraform --version | head -n 1 | awk '{print $2}')
    check_pass "Terraform installed (version: $TF_VERSION)"
    
    # Check version is >= 1.3.0
    TF_VERSION_NUM=$(echo $TF_VERSION | sed 's/v//')
    if [ "$(printf '%s\n' "1.3.0" "$TF_VERSION_NUM" | sort -V | head -n1)" = "1.3.0" ]; then
        check_pass "Terraform version is >= 1.3.0"
    else
        check_fail "Terraform version must be >= 1.3.0 (current: $TF_VERSION)"
    fi
else
    check_fail "Terraform not found. Install from: https://www.terraform.io/downloads.html"
fi

# Check git
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version | awk '{print $3}')
    check_pass "Git installed (version: $GIT_VERSION)"
else
    check_fail "Git not found. Install from: https://git-scm.com/"
fi

# Check GitHub CLI (optional but helpful)
if command -v gh &> /dev/null; then
    GH_VERSION=$(gh --version | head -n 1 | awk '{print $3}')
    check_pass "GitHub CLI installed (version: $GH_VERSION)"
else
    check_warn "GitHub CLI not found (optional). Install from: https://cli.github.com/"
fi

# Check GCP authentication
print_header "Checking GCP Authentication"

if gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n 1)
    if [ -n "$ACTIVE_ACCOUNT" ]; then
        check_pass "Authenticated to GCP as: $ACTIVE_ACCOUNT"
    else
        check_fail "No active GCP account. Run: gcloud auth login"
    fi
else
    check_fail "Could not check GCP authentication"
fi

# Check application default credentials
if [ -f "$HOME/.config/gcloud/application_default_credentials.json" ]; then
    check_pass "Application default credentials configured"
else
    check_warn "Application default credentials not found. Run: gcloud auth application-default login"
fi

# Check GitHub SSH
print_header "Checking GitHub Configuration"

if [ -f "$HOME/.ssh/id_rsa" ] || [ -f "$HOME/.ssh/id_ed25519" ]; then
    check_pass "SSH key found"
    
    # Test GitHub connection
    if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        check_pass "Successfully authenticated to GitHub via SSH"
    else
        check_warn "Could not verify GitHub SSH authentication"
    fi
else
    check_warn "No SSH key found. Generate with: ssh-keygen -t ed25519"
fi

# Check for GitHub token
if [ -n "$TF_VAR_gh_token" ]; then
    check_pass "GitHub token environment variable is set"
    
    # Basic validation (should start with ghp_ or github_pat_)
    if [[ "$TF_VAR_gh_token" =~ ^(ghp_|github_pat_) ]]; then
        check_pass "GitHub token format appears valid"
    else
        check_warn "GitHub token format may be invalid (should start with 'ghp_' or 'github_pat_')"
    fi
else
    check_warn "TF_VAR_gh_token not set. Set with: export TF_VAR_gh_token='your-token'"
fi

# Check GCP Organization access
print_header "Checking GCP Organization Access"

# Prompt for org ID if not set
if [ -z "$ORG_ID" ]; then
    echo -n "Enter your GCP Organization ID (or press Enter to skip): "
    read ORG_ID
fi

if [ -n "$ORG_ID" ]; then
    if gcloud organizations describe "$ORG_ID" &> /dev/null; then
        ORG_NAME=$(gcloud organizations describe "$ORG_ID" --format="value(displayName)")
        check_pass "Can access organization: $ORG_NAME (ID: $ORG_ID)"
        
        # Check for required roles
        USER_EMAIL=$(gcloud config get-value account)
        
        echo "Checking IAM roles for $USER_EMAIL..."
        
        # Note: These checks require appropriate permissions
        if gcloud organizations get-iam-policy "$ORG_ID" \
            --flatten="bindings[].members" \
            --filter="bindings.members:user:$USER_EMAIL" \
            --format="value(bindings.role)" | grep -q "roles/resourcemanager.organizationAdmin"; then
            check_pass "Has organizationAdmin role"
        else
            check_warn "May not have organizationAdmin role"
        fi
        
    else
        check_fail "Cannot access organization: $ORG_ID"
    fi
else
    check_warn "Organization ID not provided, skipping org-level checks"
fi

# Check for billing account
print_header "Checking Billing Account Access"

BILLING_ACCOUNTS=$(gcloud billing accounts list --format="value(name)" 2>/dev/null | wc -l)
if [ "$BILLING_ACCOUNTS" -gt 0 ]; then
    check_pass "Found $BILLING_ACCOUNTS billing account(s)"
    gcloud billing accounts list --format="table(name,displayName,open)"
else
    check_warn "No billing accounts found or no access to billing accounts"
fi

# Check project quota
print_header "Checking Project Quotas"

if [ -n "$ORG_ID" ]; then
    CURRENT_PROJECTS=$(gcloud projects list --format="value(projectId)" 2>/dev/null | wc -l)
    check_pass "Current projects in org: $CURRENT_PROJECTS"
    
    if [ "$CURRENT_PROJECTS" -gt 20 ]; then
        check_warn "You have $CURRENT_PROJECTS projects. The deployment will create ~10-15 more. Monitor quota."
    fi
else
    check_warn "Cannot check project quota without organization ID"
fi

# Check for existing bootstrap resources
print_header "Checking for Existing Resources"

if [ -n "$ORG_ID" ]; then
    # Check for existing seed project
    if gcloud projects list --filter="projectId:*-b-seed-*" --format="value(projectId)" | grep -q .; then
        check_warn "Found existing seed project(s). This may indicate a previous deployment."
        gcloud projects list --filter="projectId:*-b-seed-*" --format="table(projectId,name,createTime)"
    else
        check_pass "No existing seed projects found"
    fi
fi

# Repository structure check
print_header "Checking Repository Structure"

if [ -d ".git" ]; then
    REPO_NAME=$(git remote get-url origin 2>/dev/null | sed 's/.*\///' | sed 's/\.git$//')
    check_pass "In git repository: $REPO_NAME"
    
    # Check if this is the source repo
    if [[ "$REPO_NAME" == *"pbmm-on-gcp-onboarding"* ]]; then
        check_pass "This is the source repository (correct)"
    else
        check_warn "This doesn't appear to be the source pbmm-on-gcp-onboarding repository"
    fi
else
    check_fail "Not in a git repository"
fi

# Check for required directories
REQUIRED_DIRS=("0-bootstrap" "1-org" "2-environments" "3-networks-dual-svpc" "4-projects")
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        check_pass "Found directory: $dir"
    else
        check_fail "Missing directory: $dir"
    fi
done

# Check for fortigate (should not be deployed)
print_header "Checking Deployment Configuration"

if [ -d "7-fortigate" ]; then
    check_warn "Found 7-fortigate directory. Remember: DO NOT DEPLOY this (no on-prem connectivity)"
fi

if [ -d "7-ngfw" ]; then
    check_warn "Found 7-ngfw directory. Only deploy if explicitly needed."
fi

# Summary
print_header "Pre-Flight Check Summary"

echo ""
echo -e "Passed:   ${GREEN}$PASSED${NC}"
echo -e "Failed:   ${RED}$FAILED${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ Pre-flight checks passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Create 5 private GitHub repositories"
    echo "2. Generate a GitHub fine-grained PAT"
    echo "3. Follow SETUP_GUIDE.md or QUICK_START.md"
    echo "4. Deploy: 0-bootstrap → 1-org → 2-environments → 3-networks → 4-projects"
    echo "5. SKIP: 7-fortigate (no on-prem connectivity)"
    exit 0
else
    echo -e "${RED}✗ Pre-flight checks failed!${NC}"
    echo ""
    echo "Please resolve the failed checks before proceeding."
    exit 1
fi
