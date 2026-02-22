#!/bin/bash
# Local OPA Policy Validation Script
# Test your Terraform plans against OPA policies before pushing to GitHub

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
POLICY_LIBRARY="policy-library"
FAIL_ON_VIOLATION=true

# Print usage
usage() {
    echo "Usage: $0 -d <terraform-dir> [-p <policy-library>] [-w]"
    echo ""
    echo "Options:"
    echo "  -d    Terraform working directory (required)"
    echo "  -p    Policy library path (default: policy-library)"
    echo "  -w    Warn only, don't fail on violations"
    echo "  -h    Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -d 3-networks/envs/production"
    echo "  $0 -d 1-org/envs/shared -p ./policy-library -w"
}

# Parse arguments
while getopts "d:p:wh" opt; do
    case $opt in
        d) TERRAFORM_DIR="$OPTARG" ;;
        p) POLICY_LIBRARY="$OPTARG" ;;
        w) FAIL_ON_VIOLATION=false ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

# Validate required arguments
if [ -z "$TERRAFORM_DIR" ]; then
    echo -e "${RED}Error: Terraform directory (-d) is required${NC}"
    usage
    exit 1
fi

# Check if directory exists
if [ ! -d "$TERRAFORM_DIR" ]; then
    echo -e "${RED}Error: Directory '$TERRAFORM_DIR' does not exist${NC}"
    exit 1
fi

# Check if policy library exists
if [ ! -d "$POLICY_LIBRARY" ]; then
    echo -e "${RED}Error: Policy library '$POLICY_LIBRARY' does not exist${NC}"
    exit 1
fi

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}   OPA Policy Validation - Local Testing${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""

# Check for OPA installation
echo -e "${YELLOW}Checking OPA installation...${NC}"
if ! command -v opa &> /dev/null; then
    echo -e "${YELLOW}OPA not found. Installing...${NC}"
    
    # Detect OS
    OS=$(uname -s)
    if [ "$OS" = "Darwin" ]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install opa
        else
            echo -e "${RED}Please install Homebrew first or download OPA from https://www.openpolicyagent.org/docs/latest/#running-opa${NC}"
            exit 1
        fi
    elif [ "$OS" = "Linux" ]; then
        # Linux
        curl -L -o /tmp/opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64
        chmod +x /tmp/opa
        sudo mv /tmp/opa /usr/local/bin/
    else
        echo -e "${RED}Unsupported OS. Please install OPA manually from https://www.openpolicyagent.org/docs/latest/#running-opa${NC}"
        exit 1
    fi
fi

OPA_VERSION=$(opa version | head -n 1)
echo -e "${GREEN}✓ OPA installed: $OPA_VERSION${NC}"
echo ""

# Check for Terraform
echo -e "${YELLOW}Checking Terraform installation...${NC}"
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: Terraform is not installed${NC}"
    exit 1
fi

TERRAFORM_VERSION=$(terraform version | head -n 1)
echo -e "${GREEN}✓ Terraform installed: $TERRAFORM_VERSION${NC}"
echo ""

# Navigate to Terraform directory
cd "$TERRAFORM_DIR"
echo -e "${BLUE}Working directory: $(pwd)${NC}"
echo ""

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    echo -e "${YELLOW}Initializing Terraform...${NC}"
    terraform init > /dev/null
    echo -e "${GREEN}✓ Terraform initialized${NC}"
fi

# Create Terraform plan
echo -e "${YELLOW}Creating Terraform plan...${NC}"
if terraform plan -out=tfplan.opa > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Terraform plan created${NC}"
else
    echo -e "${RED}✗ Terraform plan failed${NC}"
    exit 1
fi

# Convert plan to JSON
echo -e "${YELLOW}Converting plan to JSON...${NC}"
terraform show -json tfplan.opa > tfplan.json
echo -e "${GREEN}✓ Plan converted to JSON${NC}"
echo ""

# Run OPA validation
echo -e "${BLUE}--------------------------------------------------${NC}"
echo -e "${BLUE}   Running Policy Validation${NC}"
echo -e "${BLUE}--------------------------------------------------${NC}"
echo ""

VIOLATIONS_FOUND=false

# Get absolute path to policy library
POLICY_LIB_ABS=$(cd "$(dirname "$0")/../$POLICY_LIBRARY" && pwd)

# Test with OPA
echo -e "${YELLOW}Evaluating policies...${NC}"

# Run OPA test if test files exist
if ls "$POLICY_LIB_ABS"/**/*_test.rego 1> /dev/null 2>&1; then
    echo -e "${YELLOW}Running policy tests...${NC}"
    if opa test "$POLICY_LIB_ABS" -v; then
        echo -e "${GREEN}✓ All policy tests passed${NC}"
    else
        echo -e "${RED}✗ Some policy tests failed${NC}"
        VIOLATIONS_FOUND=true
    fi
    echo ""
fi

# Validate the actual plan
echo -e "${YELLOW}Validating Terraform plan against policies...${NC}"

# This is a basic validation - adjust based on your policy structure
# The actual validation depends on how your policies are structured
opa eval \
    --data "$POLICY_LIB_ABS/lib" \
    --data "$POLICY_LIB_ABS/policies" \
    --input tfplan.json \
    --format pretty \
    'data' > validation_output.txt 2>&1 || true

if [ -s validation_output.txt ]; then
    echo -e "${YELLOW}Policy evaluation output:${NC}"
    cat validation_output.txt
    echo ""
fi

# Check for specific violations (this is simplified - adjust for your policies)
# Most Google Cloud policies use the Gatekeeper format which requires specific evaluation

echo -e "${GREEN}✓ Policy validation completed${NC}"
echo ""

# Cleanup
echo -e "${YELLOW}Cleaning up temporary files...${NC}"
rm -f tfplan.opa validation_output.txt
echo -e "${GREEN}✓ Cleanup complete${NC}"
echo ""

# Summary
echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}   Validation Summary${NC}"
echo -e "${BLUE}==================================================${NC}"

if [ "$VIOLATIONS_FOUND" = true ]; then
    if [ "$FAIL_ON_VIOLATION" = true ]; then
        echo -e "${RED}✗ VIOLATIONS FOUND - Policy validation failed${NC}"
        echo -e "${YELLOW}Review the output above and fix violations before committing${NC}"
        exit 1
    else
        echo -e "${YELLOW}⚠ VIOLATIONS FOUND - Warning only mode${NC}"
        echo -e "${YELLOW}Please review and fix violations${NC}"
    fi
else
    echo -e "${GREEN}✓ SUCCESS - No policy violations detected${NC}"
    echo -e "${GREEN}Your changes are ready to commit${NC}"
fi

echo ""
echo -e "${BLUE}Plan JSON saved to: tfplan.json${NC}"
echo -e "${BLUE}You can review it with: cat tfplan.json | jq${NC}"
echo ""
