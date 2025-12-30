#!/bin/bash

# Setup IAM Role for BOM Infrastructure Deployment
# This script creates only the IAM role (OIDC provider already exists)

set -e

# Configuration
AWS_REGION="eu-north-1"
AWS_ACCOUNT_ID="588681235095"
STACK_NAME="github-actions-bom-iam-role"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -r, --repository REPO   GitHub repository (format: owner/repo-name)"
    echo "  -b, --branch BRANCH     GitHub branch (default: main)"
    echo "  -s, --stack-name NAME   CloudFormation stack name (default: github-actions-bom-iam-role)"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --repository myorg/aws-bom-infrastructure"
    echo "  $0 --repository myorg/aws-bom-infrastructure --branch main"
}

# Default values
GITHUB_REPOSITORY=""
GITHUB_BRANCH="main"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--repository)
            GITHUB_REPOSITORY="$2"
            shift 2
            ;;
        -b|--branch)
            GITHUB_BRANCH="$2"
            shift 2
            ;;
        -s|--stack-name)
            STACK_NAME="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$GITHUB_REPOSITORY" ]]; then
    print_error "GitHub repository is required. Use --repository option."
    show_usage
    exit 1
fi

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    # Verify we're in the correct AWS account
    CURRENT_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    if [[ "$CURRENT_ACCOUNT" != "$AWS_ACCOUNT_ID" ]]; then
        print_error "Wrong AWS account. Expected: $AWS_ACCOUNT_ID, Current: $CURRENT_ACCOUNT"
        exit 1
    fi
    
    # Check if template file exists
    if [[ ! -f "iam/setup-oidc-role.yaml" ]]; then
        print_error "IAM template file not found: iam/setup-oidc-role.yaml"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to verify OIDC provider exists
verify_oidc_provider() {
    print_status "Verifying OIDC provider exists..."
    
    if aws iam get-open-id-connect-provider \
        --open-id-connect-provider-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com" \
        &> /dev/null; then
        print_success "OIDC provider found"
    else
        print_error "OIDC provider not found. Please create it first or contact your AWS administrator."
        exit 1
    fi
}

# Function to deploy IAM role
deploy_iam_role() {
    print_status "Deploying IAM role for GitHub Actions..."
    
    print_status "Configuration:"
    echo "  AWS Account: $AWS_ACCOUNT_ID"
    echo "  Region: $AWS_REGION"
    echo "  Stack Name: $STACK_NAME"
    echo "  GitHub Repository: $GITHUB_REPOSITORY"
    echo "  GitHub Branch: $GITHUB_BRANCH"
    echo ""
    
    # Deploy CloudFormation stack
    if aws cloudformation deploy \
        --template-file iam/setup-oidc-role.yaml \
        --stack-name "$STACK_NAME" \
        --parameter-overrides \
            GitHubRepository="$GITHUB_REPOSITORY" \
            GitHubBranch="$GITHUB_BRANCH" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$AWS_REGION" \
        --tags \
            Project=BOM-Infrastructure \
            Purpose=GitHub-Actions-OIDC \
            Environment=Production; then
        
        print_success "IAM role deployed successfully!"
        
        # Get role ARN
        ROLE_ARN=$(aws cloudformation describe-stacks \
            --stack-name "$STACK_NAME" \
            --region "$AWS_REGION" \
            --query 'Stacks[0].Outputs[?OutputKey==`RoleArn`].OutputValue' \
            --output text)
        
        print_success "Role ARN: $ROLE_ARN"
        
        # Show stack outputs
        print_status "Stack outputs:"
        aws cloudformation describe-stacks \
            --stack-name "$STACK_NAME" \
            --region "$AWS_REGION" \
            --query 'Stacks[0].Outputs' \
            --output table
        
    else
        print_error "Failed to deploy IAM role"
        exit 1
    fi
}

# Function to test role assumption
test_role_assumption() {
    print_status "Testing role configuration..."
    
    # Get role ARN
    ROLE_ARN=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`RoleArn`].OutputValue' \
        --output text)
    
    # Show trust policy
    print_status "Role trust policy:"
    aws iam get-role \
        --role-name GitHubActionsBOMCloudFormationRole \
        --query 'Role.AssumeRolePolicyDocument' \
        --output json | jq '.'
    
    print_warning "Note: The role can only be assumed by GitHub Actions from repository: $GITHUB_REPOSITORY"
    print_warning "Make sure your GitHub repository matches exactly: $GITHUB_REPOSITORY"
}

# Function to show next steps
show_next_steps() {
    print_status "Next Steps:"
    echo "============"
    echo ""
    echo "1. Configure GitHub Environment:"
    echo "   - Go to your GitHub repository: https://github.com/$GITHUB_REPOSITORY"
    echo "   - Navigate to Settings → Environments"
    echo "   - Create environment named 'production'"
    echo "   - Add required reviewers for manual approval"
    echo ""
    echo "2. Update BOM file:"
    echo "   - Edit bom/customer-bom.csv with your infrastructure requirements"
    echo ""
    echo "3. Deploy infrastructure:"
    echo "   - Go to Actions tab in GitHub"
    echo "   - Run 'Deploy BOM-driven AWS Infrastructure' workflow"
    echo "   - Or use local deployment: ./scripts/deploy-local.sh"
    echo ""
    echo "4. Role ARN for GitHub Actions:"
    
    ROLE_ARN=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`RoleArn`].OutputValue' \
        --output text)
    
    echo "   $ROLE_ARN"
    echo ""
    print_success "IAM role setup completed successfully!"
}

# Main execution
main() {
    print_status "Setting up IAM Role for BOM Infrastructure Deployment"
    print_status "====================================================="
    
    # Check prerequisites
    check_prerequisites
    
    # Verify OIDC provider exists
    verify_oidc_provider
    
    # Deploy IAM role
    deploy_iam_role
    
    # Test role configuration
    test_role_assumption
    
    # Show next steps
    show_next_steps
}

# Run main function
main "$@"