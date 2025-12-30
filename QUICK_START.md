# Quick Start Guide

Get your BOM-driven AWS infrastructure up and running in 15 minutes.

## Prerequisites

- AWS Account ID: `588681235095`
- AWS CLI installed and configured
- GitHub repository access
- Python 3.7+ installed

## Step 1: Deploy OIDC IAM Role (5 minutes)

```bash
# Clone the repository
git clone <your-repo-url>
cd aws-bom-infrastructure

# Deploy the OIDC role (one-time setup)
aws cloudformation deploy \
  --template-file iam/setup-oidc-role.yaml \
  --stack-name github-actions-oidc-role \
  --parameter-overrides \
    GitHubRepository="your-org/aws-bom-infrastructure" \
    GitHubBranch="main" \
  --capabilities CAPABILITY_NAMED_IAM \
  --region eu-north-1
```

## Step 2: Configure GitHub Environment (2 minutes)

1. Go to your GitHub repository
2. Navigate to **Settings** → **Environments**
3. Create environment named `production`
4. Add required reviewers for manual approval

## Step 3: Customize Your BOM (3 minutes)

Edit `bom/customer-bom.csv` with your infrastructure needs:

```csv
resource_type,resource_name,environment,stack_name,cidr_block,instance_type,storage_size,enabled,region,description
vpc,main-vpc,production,network-stack,10.0.0.0/16,,,true,eu-north-1,Main VPC
subnet,public-subnet-1a,production,network-stack,10.0.1.0/24,,,true,eu-north-1,Public subnet
ec2,web-server-1,production,compute-stack,,t3.medium,40,true,eu-north-1,Web server
s3,app-storage,production,storage-stack,,,,true,eu-north-1,Storage bucket
```

## Step 4: Deploy Infrastructure (5 minutes)

### Option A: GitHub Actions (Recommended)

1. Go to **Actions** tab in GitHub
2. Select **Deploy BOM-driven AWS Infrastructure**
3. Click **Run workflow**
4. Set parameters:
   - BOM File: `bom/customer-bom.csv`
   - Environment: `production`
   - Dry Run: `false`
5. Review and approve the deployment

### Option B: Local Deployment

```bash
# Validate BOM file
python scripts/parse-bom.py bom/customer-bom.csv --validate-only

# Deploy infrastructure
./scripts/deploy-local.sh --bom-file bom/customer-bom.csv --environment production
```

Or on Windows:
```powershell
# Deploy infrastructure
.\scripts\deploy-local.ps1 -BomFile bom/customer-bom.csv -Environment production
```

## What Gets Deployed

Based on the sample BOM above:

### Network Stack
- ✅ VPC (10.0.0.0/16)
- ✅ Public subnet (10.0.1.0/24)
- ✅ Internet Gateway
- ✅ Route tables and security groups

### Compute Stack
- ✅ EC2 instance (t3.medium)
- ✅ Security groups for web access
- ✅ IAM roles and instance profiles

### Storage Stack
- ✅ S3 bucket with encryption
- ✅ Lifecycle policies
- ✅ Access policies

## Verify Deployment

1. **AWS Console**: Check CloudFormation stacks
2. **EC2 Instance**: SSH or use Session Manager
3. **S3 Bucket**: Verify bucket creation and policies
4. **VPC**: Check network configuration

## Next Steps

### Scale Your Infrastructure

Add more resources to your BOM:

```csv
# Add database
rds,app-database,production,database-stack,,db.t3.micro,20,true,eu-north-1,MySQL database

# Add second web server
ec2,web-server-2,production,compute-stack,,t3.medium,40,true,eu-north-1,Second web server

# Add NAT Gateway
natgw,nat-gateway-1a,production,network-stack,,,,true,eu-north-1,NAT Gateway
```

### Test Changes Safely

```bash
# Dry run to see what would change
./scripts/deploy-local.sh --bom-file bom/customer-bom.csv --dry-run
```

### Monitor Costs

- Set up AWS Cost Explorer
- Create billing alerts
- Review BOM regularly for optimization

## Common Issues

### Issue: OIDC Role Not Found
**Solution**: Ensure the IAM role is deployed and the repository name matches

### Issue: BOM Validation Errors
**Solution**: Check required fields and data types in CSV

### Issue: CloudFormation Failures
**Solution**: Check AWS service limits and IAM permissions

## Support

- 📖 [Full Deployment Guide](docs/DEPLOYMENT_GUIDE.md)
- 📈 [Scaling Examples](docs/BOM_SCALING_EXAMPLES.md)
- 🔧 [Troubleshooting Guide](docs/TROUBLESHOOTING.md)

## Security Notes

- ✅ No AWS access keys required
- ✅ OIDC-based authentication
- ✅ Manual approval for all deployments
- ✅ Least privilege IAM permissions
- ✅ All resources encrypted by default

---

**🎉 Congratulations!** You now have a production-ready, BOM-driven AWS infrastructure deployment system.