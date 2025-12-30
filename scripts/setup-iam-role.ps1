# PowerShell script to setup IAM Role for BOM Infrastructure Deployment
# This script creates only the IAM role (OIDC provider already exists)

param(
    [Parameter(Mandatory=$true)]
    [string]$Repository,
    [string]$Branch = "main",
    [string]$StackName = "github-actions-bom-iam-role",
    [string]$Region = "eu-north-1",
    [switch]$Help
)

# Configuration
$AWS_ACCOUNT_ID = "588681235095"

# Function to show usage
function Show-Usage {
    Write-Host "Usage: .\setup-iam-role.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Parameters:"
    Write-Host "  -Repository REPO    GitHub repository (format: owner/repo-name) [REQUIRED]"
    Write-Host "  -Branch BRANCH      GitHub branch (default: main)"
    Write-Host "  -StackName NAME     CloudFormation stack name (default: github-actions-bom-iam-role)"
    Write-Host "  -Region REGION      AWS region (default: eu-north-1)"
    Write-Host "  -Help               Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\setup-iam-role.ps1 -Repository myorg/aws-bom-infrastructure"
    Write-Host "  .\setup-iam-role.ps1 -Repository myorg/aws-bom-infrastructure -Branch main"
}

# Function to print colored output
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Show help if requested
if ($Help) {
    Show-Usage
    exit 0
}

# Validate required parameters
if ([string]::IsNullOrEmpty($Repository)) {
    Write-Error "GitHub repository is required. Use -Repository parameter."
    Show-Usage
    exit 1
}

# Function to check prerequisites
function Test-Prerequisites {
    Write-Status "Checking prerequisites..."
    
    # Check if AWS CLI is installed
    try {
        aws --version | Out-Null
    }
    catch {
        Write-Error "AWS CLI is not installed. Please install it first."
        exit 1
    }
    
    # Check AWS credentials
    try {
        aws sts get-caller-identity | Out-Null
    }
    catch {
        Write-Error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    }
    
    # Verify we're in the correct AWS account
    $currentAccount = aws sts get-caller-identity --query Account --output text
    if ($currentAccount -ne $AWS_ACCOUNT_ID) {
        Write-Error "Wrong AWS account. Expected: $AWS_ACCOUNT_ID, Current: $currentAccount"
        exit 1
    }
    
    # Check if template file exists
    if (-not (Test-Path "iam/setup-oidc-role.yaml")) {
        Write-Error "IAM template file not found: iam/setup-oidc-role.yaml"
        exit 1
    }
    
    Write-Success "Prerequisites check passed"
}

# Function to verify OIDC provider exists
function Test-OIDCProvider {
    Write-Status "Verifying OIDC provider exists..."
    
    $providerArn = "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
    
    try {
        aws iam get-open-id-connect-provider --open-id-connect-provider-arn $providerArn | Out-Null
        Write-Success "OIDC provider found"
    }
    catch {
        Write-Error "OIDC provider not found. Please create it first or contact your AWS administrator."
        exit 1
    }
}

# Function to deploy IAM role
function Deploy-IAMRole {
    Write-Status "Deploying IAM role for GitHub Actions..."
    
    Write-Status "Configuration:"
    Write-Host "  AWS Account: $AWS_ACCOUNT_ID"
    Write-Host "  Region: $Region"
    Write-Host "  Stack Name: $StackName"
    Write-Host "  GitHub Repository: $Repository"
    Write-Host "  GitHub Branch: $Branch"
    Write-Host ""
    
    # Deploy CloudFormation stack
    $deployResult = aws cloudformation deploy `
        --template-file iam/setup-oidc-role.yaml `
        --stack-name $StackName `
        --parameter-overrides `
            GitHubRepository=$Repository `
            GitHubBranch=$Branch `
        --capabilities CAPABILITY_NAMED_IAM `
        --region $Region `
        --tags `
            Key=Project,Value=BOM-Infrastructure `
            Key=Purpose,Value=GitHub-Actions-OIDC `
            Key=Environment,Value=Production 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "IAM role deployed successfully!"
        
        # Get role ARN
        $roleArn = aws cloudformation describe-stacks `
            --stack-name $StackName `
            --region $Region `
            --query 'Stacks[0].Outputs[?OutputKey==`RoleArn`].OutputValue' `
            --output text
        
        Write-Success "Role ARN: $roleArn"
        
        # Show stack outputs
        Write-Status "Stack outputs:"
        aws cloudformation describe-stacks `
            --stack-name $StackName `
            --region $Region `
            --query 'Stacks[0].Outputs' `
            --output table
    }
    else {
        Write-Error "Failed to deploy IAM role"
        Write-Host $deployResult
        exit 1
    }
}

# Function to test role assumption
function Test-RoleAssumption {
    Write-Status "Testing role configuration..."
    
    # Get role ARN
    $roleArn = aws cloudformation describe-stacks `
        --stack-name $StackName `
        --region $Region `
        --query 'Stacks[0].Outputs[?OutputKey==`RoleArn`].OutputValue' `
        --output text
    
    # Show trust policy
    Write-Status "Role trust policy:"
    $trustPolicy = aws iam get-role `
        --role-name GitHubActionsBOMCloudFormationRole `
        --query 'Role.AssumeRolePolicyDocument' `
        --output json
    
    $trustPolicy | ConvertFrom-Json | ConvertTo-Json -Depth 10
    
    Write-Warning "Note: The role can only be assumed by GitHub Actions from repository: $Repository"
    Write-Warning "Make sure your GitHub repository matches exactly: $Repository"
}

# Function to show next steps
function Show-NextSteps {
    Write-Status "Next Steps:"
    Write-Host "============"
    Write-Host ""
    Write-Host "1. Configure GitHub Environment:"
    Write-Host "   - Go to your GitHub repository: https://github.com/$Repository"
    Write-Host "   - Navigate to Settings → Environments"
    Write-Host "   - Create environment named 'production'"
    Write-Host "   - Add required reviewers for manual approval"
    Write-Host ""
    Write-Host "2. Update BOM file:"
    Write-Host "   - Edit bom/customer-bom.csv with your infrastructure requirements"
    Write-Host ""
    Write-Host "3. Deploy infrastructure:"
    Write-Host "   - Go to Actions tab in GitHub"
    Write-Host "   - Run 'Deploy BOM-driven AWS Infrastructure' workflow"
    Write-Host "   - Or use local deployment: .\scripts\deploy-local.ps1"
    Write-Host ""
    Write-Host "4. Role ARN for GitHub Actions:"
    
    $roleArn = aws cloudformation describe-stacks `
        --stack-name $StackName `
        --region $Region `
        --query 'Stacks[0].Outputs[?OutputKey==`RoleArn`].OutputValue' `
        --output text
    
    Write-Host "   $roleArn"
    Write-Host ""
    Write-Success "IAM role setup completed successfully!"
}

# Main execution
function Main {
    Write-Status "Setting up IAM Role for BOM Infrastructure Deployment"
    Write-Status "====================================================="
    
    # Check prerequisites
    Test-Prerequisites
    
    # Verify OIDC provider exists
    Test-OIDCProvider
    
    # Deploy IAM role
    Deploy-IAMRole
    
    # Test role configuration
    Test-RoleAssumption
    
    # Show next steps
    Show-NextSteps
}

# Run main function
Main