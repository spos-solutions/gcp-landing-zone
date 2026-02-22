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
# GitHub Repository Security Setup Script
#
# This script automates the creation of branch protection rules for
# the GitHub repository used in the GCP Landing Zone deployment (monorepo).
#
# Usage: ./setup-github-security.sh <github-owner> <repo-name>
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

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "$1 is not installed. Please install it first."
        exit 1
    fi
}

# Function to check GitHub CLI authentication
check_gh_auth() {
    if ! gh auth status &> /dev/null; then
        print_error "GitHub CLI is not authenticated. Run 'gh auth login' first."
        exit 1
    fi
    print_success "GitHub CLI is authenticated"
}

# Function to check if repository exists
check_repo_exists() {
    local repo=$1
    if ! gh repo view "${repo}" &> /dev/null; then
        print_warning "Repository ${repo} does not exist"
        return 1
    fi
    return 0
}

# Function to verify main branch exists
verify_main_branch() {
    local repo=$1
    
    print_info "Checking main branch for ${repo}..."
    
    # Check if main branch exists
    if gh api "repos/${repo}/branches/main" &> /dev/null; then
        print_success "Main branch exists"
        return 0
    fi
    
    print_warning "Main branch not found."
    print_info "Initialize the repository first with: git commit --allow-empty -m 'init' && git push"
    return 1
}

# Function to enable branch protection
enable_branch_protection() {
    local repo=$1
    local branch=${2:-main}
    
    print_info "Enabling branch protection for ${repo}:${branch}..."
    
    # Check if branch exists first
    if ! gh api "repos/${repo}/branches/${branch}" &> /dev/null; then
        print_warning "Branch ${branch} does not exist. Skipping protection setup."
        return 1
    fi
    
    # Create branch protection rule
    gh api "repos/${repo}/branches/${branch}/protection" -X PUT \
        -f required_status_checks[strict]=true \
        -f required_status_checks[contexts][]=terraform-plan \
        -f required_status_checks[contexts][]=opa-validate \
        -f enforce_admins=true \
        -f required_pull_request_reviews[dismiss_stale_reviews]=true \
        -f required_pull_request_reviews[require_code_owner_reviews]=false \
        -f required_pull_request_reviews[required_approving_review_count]=1 \
        -f required_conversation_resolution=true \
        -f required_linear_history=false \
        -f allow_force_pushes=false \
        -f allow_deletions=false \
        -f block_creations=false &> /dev/null
    
    print_success "Branch protection enabled for ${branch}"
    return 0
}

# Function to enable security features
enable_security_features() {
    local repo=$1
    
    print_info "Enabling security features for ${repo}..."
    
    # Enable vulnerability alerts
    gh api "repos/${repo}/vulnerability-alerts" -X PUT &> /dev/null || print_warning "Could not enable vulnerability alerts"
    
    # Enable automated security fixes
    gh api "repos/${repo}/automated-security-fixes" -X PUT &> /dev/null || print_warning "Could not enable automated security fixes"
    
    # Enable secret scanning (requires GitHub Advanced Security or public repo)
    gh api "repos/${repo}/secret-scanning/alerts" &> /dev/null && \
        print_success "Secret scanning is available" || \
        print_warning "Secret scanning requires GitHub Advanced Security (Enterprise feature)"
    
    print_success "Security features configured"
}

# Function to setup repository security
setup_repo_security() {
    local owner=$1
    local repo_name=$2
    local repo="${owner}/${repo_name}"
    
    echo ""
    print_info "=========================================="
    print_info "Configuring ${repo_name}"
    print_info "=========================================="
    
    # Check if repository exists
    if ! check_repo_exists "${repo}"; then
        print_error "Repository ${repo} not found"
        print_info "Create it first at: https://github.com/new"
        return 1
    fi
    
    # Verify main branch exists
    verify_main_branch "${repo}"
    
    # Enable branch protection for main (production)
    enable_branch_protection "${repo}" "main"
    
    # Enable security features
    enable_security_features "${repo}"
    
    print_success "Completed configuration for ${repo_name}"
    return 0
}

# Main function
main() {
    echo ""
    print_info "=========================================="
    print_info "GitHub Repository Security Setup"
    print_info "=========================================="
    echo ""
    
    # Check required commands
    check_command gh
    check_command jq
    
    # Check GitHub authentication
    check_gh_auth
    
    # Get GitHub owner and repo name from arguments or prompt
    local github_owner=""
    local repo_name="${DEFAULT_REPO_NAME}"
    
    if [[ $# -eq 0 ]]; then
        print_info "Enter your GitHub username or organization name:"
        read -r github_owner
        print_info "Enter repository name (default: ${DEFAULT_REPO_NAME}):"
        read -r input_repo_name
        repo_name="${input_repo_name:-${DEFAULT_REPO_NAME}}"
    elif [[ $# -eq 1 ]]; then
        github_owner=$1
        print_info "Using default repository name: ${repo_name}"
    else
        github_owner=$1
        repo_name=$2
    fi
    
    if [[ -z "${github_owner}" ]]; then
        print_error "GitHub owner is required"
        exit 1
    fi
    
    print_info "Configuring repository: ${github_owner}/${repo_name}"
    echo ""
    
    # Confirm before proceeding
    print_warning "This will configure branch protection and security settings."
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Aborted by user"
        exit 0
    fi
    
    # Setup security for the repository
    if setup_repo_security "${github_owner}" "${repo_name}"; then
        echo ""
        print_info "=========================================="
        print_info "Summary"
        print_info "=========================================="
        print_success "Repository configured successfully"
        echo ""
        
        # Additional recommendations
        print_info "Additional recommended steps:"
        echo "  1. Review and adjust branch protection rules in GitHub UI"
        echo "  2. Configure repository environments for deployment approvals"
        echo "  3. Add CODEOWNERS file to repository"
        echo "  4. Enable signed commits if required by your organization"
        echo "  5. Configure team access and permissions"
        echo ""
        print_info "For more details, see: docs/GITHUB-SECURITY.md"
        echo ""
    else
        print_error "Failed to configure repository"
        exit 1
    fi
}

# Run main function
main "$@"
