# PowerShell script to fix IAM role trust policy for OIDC
# This script updates the trust policy to allow the correct repository and environments

param(
    [string]$RoleName = "GitHubActionsBOMCloudFormationRole",
    [string]$Repository = "manjutrytest/aws-bom-infrastructure",
    [string]$Branch = "main",
    [switch]$Help
)

# Function to show usage
function Show-Usage {
    Write-Host "Usage: .\fix-oidc-trust-policy.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Parameters:"
    Write-Host "  -RoleName NAME      IAM role name (default: GitHubActionsBOMCloudFormationRole)"
    Write-Host "  -Repository REPO    GitHub repository (default: manjutrytest/aws-bom-infrastructure)"
    Write-Host "  -Branch BRANCH      GitHub branch (default: main)"
    Write-Host "  -Help               Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\fix-oidc-trust-policy.ps1"
    Write-Host "  .\fix-oidc-trust-policy.ps1 -Repository myorg/my-repo"
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

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Show help if requested
if ($Help) {
    Show-Usage
    exit 0
}

Write-Status "Fixing IAM Role Trust Policy for OIDC"
Write-Status "====================================="
Write-Host "Role Name: $RoleName"
Write-Host "Repository: $Repository"
Write-Host "Branch: $Branch"
Write-Host ""

# Create trust policy document
$trustPolicy = @{
    Version = "2012-10-17"
    Statement = @(
        @{
            Effect = "Allow"
            Principal = @{
                Federated = "arn:aws:iam::588681235095:oidc-provider/token.actions.githubusercontent.com"
            }
            Action = "sts:AssumeRoleWithWebIdentity"
            Condition = @{
                StringEquals = @{
                    "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
                }
                StringLike = @{
                    "token.actions.githubusercontent.com:sub" = @(
                        "repo:${Repository}:ref:refs/heads/${Branch}",
                        "repo:${Repository}:environment:development",
                        "repo:${Repository}:environment:staging", 
                        "repo:${Repository}:environment:production"
                    )
                }
            }
        }
    )
}

# Convert to JSON
$trustPolicyJson = $trustPolicy | ConvertTo-Json -Depth 10 -Compress

Write-Status "Generated trust policy:"
Write-Host ($trustPolicy | ConvertTo-Json -Depth 10)
Write-Host ""

# Update the role trust policy
try {
    Write-Status "Updating IAM role trust policy..."
    
    $result = aws iam update-assume-role-policy `
        --role-name $RoleName `
        --policy-document $trustPolicyJson
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Trust policy updated successfully!"
        Write-Host ""
        Write-Status "The role now allows OIDC access from:"
        Write-Host "  - Repository: $Repository"
        Write-Host "  - Branch: $Branch"
        Write-Host "  - Environments: development, staging, production"
        Write-Host ""
        Write-Success "You can now run GitHub Actions workflows with OIDC authentication"
    }
    else {
        Write-Error "Failed to update trust policy"
        exit 1
    }
}
catch {
    Write-Error "Error updating trust policy: $_"
    exit 1
}

# Verify the update
try {
    Write-Status "Verifying trust policy update..."
    $currentPolicy = aws iam get-role --role-name $RoleName --query 'Role.AssumeRolePolicyDocument' --output json
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Trust policy verification completed"
        Write-Host "Current trust policy:"
        Write-Host $currentPolicy
    }
}
catch {
    Write-Status "Could not verify trust policy (this is normal if AWS CLI credentials are limited)"
}

Write-Success "OIDC trust policy fix completed!"