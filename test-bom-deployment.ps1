# Test BOM deployment locally
# This script tests the complete BOM deployment process

Write-Host "[INFO] Testing BOM deployment process..." -ForegroundColor Blue

# Step 1: Validate BOM
Write-Host "[INFO] Step 1: Validating BOM file..." -ForegroundColor Blue
python scripts/parse-bom.py bom/customer-bom.csv --validate-only

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] BOM validation failed" -ForegroundColor Red
    exit 1
}

# Step 2: Generate parameters
Write-Host "[INFO] Step 2: Generating CloudFormation parameters..." -ForegroundColor Blue
python scripts/parse-bom.py bom/customer-bom.csv --output-dir parameters

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Parameter generation failed" -ForegroundColor Red
    exit 1
}

# Step 3: Show what will be deployed
Write-Host "[INFO] Step 3: Deployment plan..." -ForegroundColor Blue
if (Test-Path "parameters/deployment-manifest.json") {
    $manifest = Get-Content "parameters/deployment-manifest.json" | ConvertFrom-Json
    Write-Host "Deployment order:" -ForegroundColor Yellow
    foreach ($stack in $manifest.deployment_order) {
        Write-Host "  - $stack" -ForegroundColor Cyan
    }
    
    Write-Host "`nStack details:" -ForegroundColor Yellow
    foreach ($stackName in $manifest.stacks.PSObject.Properties.Name) {
        $stack = $manifest.stacks.$stackName
        Write-Host "  $stackName`: $($stack.resources) resources" -ForegroundColor Cyan
    }
}

# Step 4: Validate CloudFormation templates
Write-Host "[INFO] Step 4: Validating CloudFormation templates..." -ForegroundColor Blue
$templates = @("network-stack", "compute-stack", "storage-stack")

foreach ($template in $templates) {
    $templateFile = "cloudformation/$template.yaml"
    if (Test-Path $templateFile) {
        Write-Host "  Validating $templateFile..." -ForegroundColor Cyan
        aws cloudformation validate-template --template-body file://$templateFile --region eu-north-1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✓ Valid" -ForegroundColor Green
        } else {
            Write-Host "    ✗ Invalid" -ForegroundColor Red
        }
    }
}

# Step 5: Show parameter files
Write-Host "[INFO] Step 5: Generated parameter files..." -ForegroundColor Blue
if (Test-Path "parameters") {
    Get-ChildItem "parameters" -Filter "*.json" | ForEach-Object {
        Write-Host "  - $($_.Name)" -ForegroundColor Cyan
        $content = Get-Content $_.FullName | ConvertFrom-Json
        Write-Host "    Parameters: $($content.Count)" -ForegroundColor Gray
    }
}

Write-Host "[SUCCESS] BOM deployment test completed!" -ForegroundColor Green
Write-Host "[INFO] Ready to deploy via GitHub Actions or local deployment" -ForegroundColor Yellow