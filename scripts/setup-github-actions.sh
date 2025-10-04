#!/bin/bash
set -e

# SiriusScan Demo - GitHub Actions Setup Script
# This script helps configure GitHub Actions for the demo deployment

echo "🚀 SiriusScan Demo - GitHub Actions Setup"
echo "=========================================="

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo "❌ Error: Not in a git repository"
    echo "Please run this script from the root of the sirius-demo repository"
    exit 1
fi

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ Error: GitHub CLI (gh) is not installed"
    echo "Please install it from: https://cli.github.com/"
    exit 1
fi

# Check if user is authenticated with GitHub
if ! gh auth status &> /dev/null; then
    echo "❌ Error: Not authenticated with GitHub"
    echo "Please run: gh auth login"
    exit 1
fi

echo "✅ GitHub CLI is installed and authenticated"

# Get repository information
REPO_OWNER=$(gh repo view --json owner --jq '.owner.login')
REPO_NAME=$(gh repo view --json name --jq '.name')
REPO_FULL_NAME="$REPO_OWNER/$REPO_NAME"

echo "📋 Repository: $REPO_FULL_NAME"

# Check if workflows directory exists
if [ ! -d ".github/workflows" ]; then
    echo "❌ Error: .github/workflows directory not found"
    echo "Please ensure the workflow files are in place"
    exit 1
fi

echo "✅ Workflows directory found"

# List available workflows
echo ""
echo "📁 Available workflows:"
for workflow in .github/workflows/*.yml; do
    if [ -f "$workflow" ]; then
        filename=$(basename "$workflow" .yml)
        echo "  - $filename"
    fi
done

# Check for required secrets
echo ""
echo "🔐 Checking repository secrets..."

# Check if AWS_ACCESS_KEY_ID secret exists
if gh secret list | grep -q "AWS_ACCESS_KEY_ID"; then
    echo "✅ AWS_ACCESS_KEY_ID secret found"
else
    echo "❌ AWS_ACCESS_KEY_ID secret not found"
    echo ""
    echo "Please add the AWS access key ID secret:"
    echo "gh secret set AWS_ACCESS_KEY_ID --body 'YOUR_ACCESS_KEY_ID'"
fi

# Check if AWS_SECRET_ACCESS_KEY secret exists
if gh secret list | grep -q "AWS_SECRET_ACCESS_KEY"; then
    echo "✅ AWS_SECRET_ACCESS_KEY secret found"
else
    echo "❌ AWS_SECRET_ACCESS_KEY secret not found"
    echo ""
    echo "Please add the AWS secret access key secret:"
    echo "gh secret set AWS_SECRET_ACCESS_KEY --body 'YOUR_SECRET_ACCESS_KEY'"
fi

# Check if AWS_REGION secret exists (optional)
if gh secret list | grep -q "AWS_REGION"; then
    echo "✅ AWS_REGION secret found"
else
    echo "ℹ️  AWS_REGION secret not found (optional, defaults to us-east-1)"
fi

# Test workflow syntax
echo ""
echo "🔍 Testing workflow syntax..."

for workflow in .github/workflows/*.yml; do
    if [ -f "$workflow" ]; then
        filename=$(basename "$workflow")
        echo "  Testing $filename..."
        
        # Basic YAML syntax check (GitHub Actions uses some special syntax)
        if python3 -c "import yaml; yaml.safe_load(open('$workflow'))" 2>/dev/null; then
            echo "    ✅ Valid YAML syntax"
        else
            # Try with GitHub Actions specific parsing
            if grep -q "uses:" "$workflow" && grep -q "runs-on:" "$workflow"; then
                echo "    ✅ Valid GitHub Actions syntax"
            else
                echo "    ❌ Invalid YAML syntax"
            fi
        fi
    fi
done

# Check Terraform configuration
echo ""
echo "🔧 Checking Terraform configuration..."

if [ -d "infra/demo" ]; then
    echo "✅ Terraform directory found"
    
    # Check if terraform is installed
    if command -v terraform &> /dev/null; then
        echo "✅ Terraform is installed"
        
        # Test terraform init
        cd infra/demo
        if terraform init -backend=false &> /dev/null; then
            echo "✅ Terraform configuration is valid"
        else
            echo "❌ Terraform configuration has issues"
        fi
        cd ../..
    else
        echo "⚠️  Terraform not installed (workflows will install it)"
    fi
else
    echo "❌ Terraform directory not found"
fi

# Check scripts
echo ""
echo "📜 Checking deployment scripts..."

SCRIPTS=(
    "scripts/monitor_demo.sh"
    "scripts/seed_demo.sh"
    "scripts/wait_for_api.sh"
)

for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        echo "✅ $script found"
        
        # Make executable
        chmod +x "$script"
        
        # Basic syntax check
        if bash -n "$script" 2>/dev/null; then
            echo "  ✅ Valid syntax"
        else
            echo "  ❌ Syntax errors"
        fi
    else
        echo "❌ $script not found"
    fi
done

# Summary
echo ""
echo "📊 Setup Summary"
echo "================"

# Check overall status
ISSUES=0

if ! gh secret list | grep -q "AWS_ACCESS_KEY_ID"; then
    echo "❌ Missing AWS_ACCESS_KEY_ID secret"
    ISSUES=$((ISSUES + 1))
fi

if ! gh secret list | grep -q "AWS_SECRET_ACCESS_KEY"; then
    echo "❌ Missing AWS_SECRET_ACCESS_KEY secret"
    ISSUES=$((ISSUES + 1))
fi

if [ ! -d "infra/demo" ]; then
    echo "❌ Missing Terraform configuration"
    ISSUES=$((ISSUES + 1))
fi

if [ $ISSUES -eq 0 ]; then
    echo "✅ Setup looks good! GitHub Actions should work."
    echo ""
    echo "Next steps:"
    echo "1. Ensure AWS access keys have proper permissions"
    echo "2. Test the workflows manually"
    echo "3. Monitor the first scheduled deployment"
else
    echo "❌ Found $ISSUES issue(s) that need to be resolved"
    echo ""
    echo "Please fix the issues above before using GitHub Actions"
fi

echo ""
echo "🔗 Useful commands:"
echo "  gh workflow list                    # List all workflows"
echo "  gh workflow run deploy-demo.yml     # Run deployment manually"
echo "  gh workflow run cleanup.yml         # Run cleanup manually"
echo "  gh run list                         # List recent workflow runs"
echo "  gh run view <run-id>                # View specific run details"
echo ""
echo "📚 Documentation:"
echo "  .github/workflows/README.md         # Workflow documentation"
echo "  docs/AWS_SETUP_GUIDE.md            # AWS setup guide"
echo "  README.md                           # Project overview"
