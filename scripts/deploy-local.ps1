# PowerShell deployment script for BOM-driven infrastructure
# This script allows local testing and deployment without GitHub Actions

param(
    [string]$BomFile = "bom/customer-bom.csv",
    [string]$Environment = "production",
    [switch]$DryRun,
    [switch]$ValidateOnly,
    [string]$Region = "eu-north-1",
    [switch]$Help
)

# Configuration
$AWS_ACCOUNT_ID = "588681235095"
$ROLE_NAME = "GitHubActionsBOMCloudFormationRole"

# Function to show usage
function Show-Usage {
    Write-Host "Usage: .\deploy-local.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -BomFile FILE       Path to BOM CSV file (default: bom/customer-bom.csv)"
    Write-Host "  -Environment ENV    Environment name (default: production)"
    Write-Host "  -DryRun            Create change sets only, don't execute"
    Write-Host "  -ValidateOnly      Validate BOM file only"
    Write-Host "  -Region REGION     AWS region (default: eu-north-1)"
    Write-Host "  -Help              Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\deploy-local.ps1 -BomFile bom/staging-bom.csv -Environment staging"
    Write-Host "  .\deploy-local.ps1 -DryRun -ValidateOnly"
    Write-Host "  .\deploy-local.ps1 -BomFile bom/customer-bom.csv -Environment production"
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
    
    # Check if Python is installed
    try {
        python --version | Out-Null
    }
    catch {
        Write-Error "Python is not installed. Please install it first."
        exit 1
    }
    
    # Check if BOM file exists
    if (-not (Test-Path $BomFile)) {
        Write-Error "BOM file not found: $BomFile"
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
    
    Write-Success "Prerequisites check passed"
}

# Function to validate BOM file
function Test-BomFile {
    Write-Status "Validating BOM file: $BomFile"
    
    $result = python scripts/parse-bom.py $BomFile --validate-only
    if ($LASTEXITCODE -eq 0) {
        Write-Success "BOM validation passed"
        return $true
    }
    else {
        Write-Error "BOM validation failed"
        return $false
    }
}

# Function to generate parameters
function New-Parameters {
    Write-Status "Generating CloudFormation parameters..."
    
    # Create parameters directory
    if (-not (Test-Path "parameters")) {
        New-Item -ItemType Directory -Path "parameters" | Out-Null
    }
    
    # Generate parameters
    $result = python scripts/parse-bom.py $BomFile --output-dir parameters
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Parameters generated successfully"
        
        # Show generated files
        Write-Status "Generated parameter files:"
        Get-ChildItem -Path "parameters" | Format-Table Name, Length, LastWriteTime
        return $true
    }
    else {
        Write-Error "Failed to generate parameters"
        return $false
    }
}

# Function to validate CloudFormation templates
function Test-Templates {
    Write-Status "Validating CloudFormation templates..."
    
    $templates = @(
        "cloudformation/network-stack.yaml",
        "cloudformation/compute-stack.yaml",
        "cloudformation/storage-stack.yaml",
        "cloudformation/database-stack.yaml"
    )
    
    foreach ($template in $templates) {
        if (Test-Path $template) {
            Write-Status "Validating $template..."
            $result = aws cloudformation validate-template --template-body file://$template --region $Region 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Success "$template is valid"
            }
            else {
                Write-Error "$template validation failed"
                return $false
            }
        }
    }
    return $true
}

# Function to create change sets
function New-ChangeSets {
    Write-Status "Creating CloudFormation change sets..."
    
    # Read deployment manifest
    if (-not (Test-Path "parameters/deployment-manifest.json")) {
        Write-Error "Deployment manifest not found. Run parameter generation first."
        return $false
    }
    
    # Get deployment order
    $manifest = Get-Content "parameters/deployment-manifest.json" | ConvertFrom-Json
    $stacks = $manifest.deployment_order
    
    foreach ($stack in $stacks) {
        $stackName = "$stack-$Environment"
        $templateFile = "cloudformation/$stack.yaml"
        $parametersFile = "parameters/$stack-parameters.json"
        $changesetName = "changeset-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        
        Write-Status "Creating change set for stack: $stackName"
        
        # Check if files exist
        if (-not (Test-Path $templateFile)) {
            Write-Warning "Template file not found: $templateFile, skipping..."
            continue
        }
        
        if (-not (Test-Path $parametersFile)) {
            Write-Warning "Parameters file not found: $parametersFile, skipping..."
            continue
        }
        
        # Determine change set type
        $changesetType = "CREATE"
        $stackExists = aws cloudformation describe-stacks --stack-name $stackName --region $Region 2>$null
        if ($LASTEXITCODE -eq 0) {
            $changesetType = "UPDATE"
            Write-Status "Stack exists, creating UPDATE change set"
        }
        else {
            Write-Status "Stack does not exist, creating CREATE change set"
        }
        
        # Create change set
        $result = aws cloudformation create-change-set `
            --stack-name $stackName `
            --template-body file://$templateFile `
            --parameters file://$parametersFile `
            --change-set-name $changesetName `
            --change-set-type $changesetType `
            --capabilities CAPABILITY_NAMED_IAM `
            --region $Region `
            --tags `
                Key=Project,Value=BOM-Infrastructure `
                Key=Environment,Value=$Environment `
                Key=DeployedBy,Value=PowerShellScript `
                Key=Timestamp,Value=$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ') 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Change set created: $changesetName"
            
            # Wait for change set creation
            Write-Status "Waiting for change set creation to complete..."
            $result = aws cloudformation wait change-set-create-complete `
                --stack-name $stackName `
                --change-set-name $changesetName `
                --region $Region
            
            if ($LASTEXITCODE -eq 0) {
                # Show change set details
                Write-Status "Change set details for $stackName:"
                aws cloudformation describe-change-set `
                    --stack-name $stackName `
                    --change-set-name $changesetName `
                    --region $Region `
                    --query 'Changes[].{Action:Action,ResourceType:ResourceChange.ResourceType,LogicalId:ResourceChange.LogicalResourceId,Replacement:ResourceChange.Replacement}' `
                    --output table
            }
            else {
                Write-Error "Change set creation failed for $stackName"
                return $false
            }
        }
        else {
            Write-Error "Failed to create change set for $stackName"
            return $false
        }
    }
    return $true
}

# Function to execute change sets
function Invoke-ChangeSets {
    Write-Status "Executing CloudFormation change sets..."
    
    # Read deployment manifest
    $manifest = Get-Content "parameters/deployment-manifest.json" | ConvertFrom-Json
    $stacks = $manifest.deployment_order
    
    foreach ($stack in $stacks) {
        $stackName = "$stack-$Environment"
        
        Write-Status "Executing change set for stack: $stackName"
        
        # Find the latest change set
        $changesetName = aws cloudformation list-change-sets `
            --stack-name $stackName `
            --region $Region `
            --query 'Summaries[0].ChangeSetName' `
            --output text 2>$null
        
        if ([string]::IsNullOrEmpty($changesetName) -or $changesetName -eq "None") {
            Write-Warning "No change set found for stack: $stackName, skipping..."
            continue
        }
        
        # Execute change set
        $result = aws cloudformation execute-change-set `
            --stack-name $stackName `
            --change-set-name $changesetName `
            --region $Region 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Change set execution started for $stackName"
            
            # Wait for stack operation to complete
            Write-Status "Waiting for stack operation to complete..."
            
            # Determine wait condition
            $changesetType = aws cloudformation describe-change-set `
                --stack-name $stackName `
                --change-set-name $changesetName `
                --region $Region `
                --query 'ChangeSetType' `
                --output text
            
            if ($changesetType -eq "CREATE") {
                $result = aws cloudformation wait stack-create-complete --stack-name $stackName --region $Region
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Stack created successfully: $stackName"
                }
                else {
                    Write-Error "Stack creation failed: $stackName"
                    return $false
                }
            }
            else {
                $result = aws cloudformation wait stack-update-complete --stack-name $stackName --region $Region
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Stack updated successfully: $stackName"
                }
                else {
                    Write-Error "Stack update failed: $stackName"
                    return $false
                }
            }
            
            # Show stack outputs
            Write-Status "Stack outputs for $stackName:"
            aws cloudformation describe-stacks `
                --stack-name $stackName `
                --region $Region `
                --query 'Stacks[0].Outputs' `
                --output table
        }
        else {
            Write-Error "Failed to execute change set for $stackName"
            return $false
        }
    }
    return $true
}

# Function to show deployment summary
function Show-Summary {
    Write-Status "Deployment Summary"
    Write-Host "===================="
    Write-Host "BOM File: $BomFile"
    Write-Host "Environment: $Environment"
    Write-Host "Region: $Region"
    Write-Host "Dry Run: $DryRun"
    Write-Host "Validate Only: $ValidateOnly"
    Write-Host ""
    
    if (Test-Path "parameters/deployment-manifest.json") {
        Write-Host "Stacks to deploy:"
        $manifest = Get-Content "parameters/deployment-manifest.json" | ConvertFrom-Json
        foreach ($stack in $manifest.deployment_order) {
            Write-Host "  - $stack"
        }
        Write-Host ""
    }
    
    # Show current AWS identity
    Write-Host "AWS Identity:"
    aws sts get-caller-identity --output table
}

# Main execution
function Main {
    Write-Status "Starting BOM-driven infrastructure deployment"
    Write-Status "=============================================="
    
    # Show summary
    Show-Summary
    
    # Check prerequisites
    Test-Prerequisites
    
    # Validate BOM
    if (-not (Test-BomFile)) {
        exit 1
    }
    
    # If validate-only mode, exit here
    if ($ValidateOnly) {
        Write-Success "Validation completed successfully"
        exit 0
    }
    
    # Generate parameters
    if (-not (New-Parameters)) {
        exit 1
    }
    
    # Validate templates
    if (-not (Test-Templates)) {
        exit 1
    }
    
    # Create change sets
    if (-not (New-ChangeSets)) {
        exit 1
    }
    
    # If dry-run mode, exit here
    if ($DryRun) {
        Write-Success "Dry run completed successfully. Change sets created but not executed."
        Write-Status "To execute the change sets, run without -DryRun flag"
        exit 0
    }
    
    # Ask for confirmation before executing
    Write-Host ""
    Write-Warning "This will deploy infrastructure to AWS Account: $AWS_ACCOUNT_ID"
    Write-Warning "Environment: $Environment"
    Write-Warning "Region: $Region"
    Write-Host ""
    $confirmation = Read-Host "Do you want to proceed with deployment? (y/N)"
    
    if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
        Write-Status "Deployment cancelled by user"
        exit 0
    }
    
    # Execute change sets
    if (-not (Invoke-ChangeSets)) {
        exit 1
    }
    
    Write-Success "Deployment completed successfully!"
    Write-Status "Check the AWS CloudFormation console for detailed stack information"
}

# Run main function
Main