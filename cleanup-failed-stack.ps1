# PowerShell script to cleanup failed CloudFormation stack
# This script deletes a stack that's in ROLLBACK_IN_PROGRESS or ROLLBACK_COMPLETE state

param(
    [string]$StackName = "compute-stack-development",
    [string]$Region = "eu-north-1",
    [switch]$Help
)

# Function to show usage
function Show-Usage {
    Write-Host "Usage: .\cleanup-failed-stack.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Parameters:"
    Write-Host "  -StackName NAME     CloudFormation stack name (default: compute-stack-development)"
    Write-Host "  -Region REGION      AWS region (default: eu-north-1)"
    Write-Host "  -Help               Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\cleanup-failed-stack.ps1"
    Write-Host "  .\cleanup-failed-stack.ps1 -StackName my-failed-stack"
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

Write-Status "Cleaning up failed CloudFormation stack"
Write-Status "======================================"
Write-Host "Stack Name: $StackName"
Write-Host "Region: $Region"
Write-Host ""

# Check stack status
try {
    Write-Status "Checking stack status..."
    $stackStatus = aws cloudformation describe-stacks `
        --stack-name $StackName `
        --region $Region `
        --query 'Stacks[0].StackStatus' `
        --output text 2>$null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Stack $StackName does not exist or cannot be accessed"
        Write-Success "No cleanup needed"
        exit 0
    }
    
    Write-Status "Current stack status: $stackStatus"
    
    # Check if stack is in a failed state that can be deleted
    $deletableStates = @(
        "CREATE_FAILED",
        "ROLLBACK_COMPLETE", 
        "ROLLBACK_FAILED",
        "DELETE_FAILED",
        "UPDATE_ROLLBACK_COMPLETE",
        "UPDATE_ROLLBACK_FAILED"
    )
    
    if ($stackStatus -in $deletableStates) {
        Write-Status "Stack is in a deletable state: $stackStatus"
    }
    elseif ($stackStatus -eq "ROLLBACK_IN_PROGRESS") {
        Write-Status "Stack is currently rolling back. Waiting for rollback to complete..."
        
        # Wait for rollback to complete
        $result = aws cloudformation wait stack-rollback-complete `
            --stack-name $StackName `
            --region $Region
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Rollback completed"
        }
        else {
            Write-Warning "Rollback wait timed out or failed, but continuing with deletion attempt"
        }
    }
    else {
        Write-Error "Stack is in state '$stackStatus' which cannot be safely deleted"
        Write-Status "Please wait for the stack to reach a stable state before cleanup"
        exit 1
    }
}
catch {
    Write-Error "Error checking stack status: $_"
    exit 1
}

# Delete the stack
try {
    Write-Status "Deleting stack: $StackName"
    
    $result = aws cloudformation delete-stack `
        --stack-name $StackName `
        --region $Region
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Stack deletion initiated"
        
        # Wait for deletion to complete
        Write-Status "Waiting for stack deletion to complete..."
        $result = aws cloudformation wait stack-delete-complete `
            --stack-name $StackName `
            --region $Region
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Stack deleted successfully: $StackName"
        }
        else {
            Write-Warning "Stack deletion wait timed out, but deletion may still be in progress"
            Write-Status "Check AWS Console for current status"
        }
    }
    else {
        Write-Error "Failed to initiate stack deletion"
        exit 1
    }
}
catch {
    Write-Error "Error deleting stack: $_"
    exit 1
}

Write-Success "Stack cleanup completed!"
Write-Status "You can now redeploy the stack with the corrected configuration"