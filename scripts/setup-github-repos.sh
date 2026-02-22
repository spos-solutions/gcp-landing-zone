#!/bin/bash

# GitHub Repositories Setup Script
# Creates the directory structure for all GitHub repositories

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "GitHub Repositories Setup Script"
echo -e "==========================================${NC}"
echo ""

# Check if we're in the pbmm-on-gcp-onboarding directory
if [ ! -d "0-bootstrap" ] || [ ! -d "1-org" ]; then
    echo -e "${YELLOW}⚠ Warning: This doesn't appear to be the pbmm-on-gcp-onboarding directory${NC}"
    echo "Please run this script from the root of the pbmm-on-gcp-onboarding repository"
    exit 1
fi

# Get GitHub organization/user
echo -n "Enter your GitHub organization or username: "
read GITHUB_ORG

if [ -z "$GITHUB_ORG" ]; then
    echo "GitHub organization/username is required"
    exit 1
fi

# Get parent directory (where repos will be cloned)
PARENT_DIR=$(pwd)/..
echo ""
echo "Repositories will be created in: $PARENT_DIR"
echo ""

# Repository names
REPOS=("gcp-bootstrap" "gcp-org" "gcp-environments" "gcp-networks" "gcp-projects")

echo "This script will help you set up the following repositories:"
for repo in "${REPOS[@]}"; do
    echo "  - $repo"
done
echo ""

# Ask if repositories already exist on GitHub
echo -n "Have you already created these repositories on GitHub? (y/n): "
read REPOS_EXIST

if [ "$REPOS_EXIST" != "y" ]; then
    echo ""
    echo -e "${YELLOW}Please create these private repositories on GitHub first:${NC}"
    echo ""
    if command -v gh &> /dev/null; then
        echo "Using GitHub CLI (quick method):"
        echo ""
        for repo in "${REPOS[@]}"; do
            echo "  gh repo create ${GITHUB_ORG}/${repo} --private --clone"
        done
    else
        echo "Via GitHub web interface:"
        echo "  https://github.com/new"
    fi
    echo ""
    echo "Then run this script again."
    exit 0
fi

# Clone and setup each repository
for repo in "${REPOS[@]}"; do
    echo -e "${BLUE}------------------------------------------${NC}"
    echo -e "${GREEN}Setting up: $repo${NC}"
    echo -e "${BLUE}------------------------------------------${NC}"
    
    REPO_PATH="$PARENT_DIR/$repo"
    
    # Check if directory already exists
    if [ -d "$REPO_PATH" ]; then
        echo -e "${YELLOW}⚠ Directory already exists: $REPO_PATH${NC}"
        echo -n "Do you want to remove it and re-clone? (y/n): "
        read REMOVE
        
        if [ "$REMOVE" = "y" ]; then
            rm -rf "$REPO_PATH"
        else
            echo "Skipping $repo"
            continue
        fi
    fi
    
    # Clone repository
    echo "Cloning $repo..."
    if ! git clone "git@github.com:${GITHUB_ORG}/${repo}.git" "$REPO_PATH" 2>/dev/null; then
        echo -e "${YELLOW}⚠ Failed to clone $repo. It may not exist or you may not have access.${NC}"
        echo "Create it at: https://github.com/${GITHUB_ORG}/${repo}"
        continue
    fi
    
    cd "$REPO_PATH"
    
    # Check if repo is empty (no commits)
    if ! git log -1 &> /dev/null; then
        echo "Initializing repository..."
        
        # Create initial commit
        echo "# ${repo}" > README.md
        git add README.md
        git commit -m "Initial commit"
        git push origin main
        
        # Create production branch
        git checkout -b production
        git push origin production
        
        # Create plan branch
        git checkout -b plan
        
        echo -e "${GREEN}✓ Initialized $repo${NC}"
    else
        echo -e "${GREEN}✓ Repository already initialized${NC}"
        
        # Ensure we're on plan branch
        if git show-ref --verify --quiet refs/heads/plan; then
            git checkout plan
        else
            git checkout -b plan
        fi
    fi
    
    cd - > /dev/null
    echo ""
done

# Summary
echo -e "${BLUE}=========================================="
echo "Setup Complete!"
echo -e "==========================================${NC}"
echo ""
echo "Repositories created in: $PARENT_DIR"
echo ""
echo "Directory structure:"
cd "$PARENT_DIR"
for repo in "${REPOS[@]}"; do
    if [ -d "$repo" ]; then
        echo -e "  ${GREEN}✓${NC} $repo/"
    else
        echo -e "  ${YELLOW}✗${NC} $repo/ (not cloned)"
    fi
done
echo ""
echo "Next steps:"
echo "1. Run the preflight check:"
echo "   cd $(pwd)/pbmm-on-gcp-onboarding"
echo "   ./scripts/preflight-check.sh"
echo ""
echo "2. Follow the setup guide:"
echo "   - Quick start: QUICK_START.md"
echo "   - Detailed guide: SETUP_GUIDE.md"
echo ""
echo "3. Start with 0-bootstrap:"
echo "   cd $PARENT_DIR/gcp-bootstrap"
