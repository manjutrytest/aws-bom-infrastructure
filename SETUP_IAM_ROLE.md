# Setup IAM Role for BOM Infrastructure

Since the OIDC provider already exists in your AWS account (588681235095), you only need to create the IAM role.

## Quick Setup Commands

### Option 1: Using Setup Script (Recommended)

**Linux/macOS:**
```bash
# Make script executable
chmod +x scripts/setup-iam-role.sh

# Run setup (replace with your GitHub repository)
./scripts/setup-iam-role.sh --repository "your-org/aws-bom-infrastructure"
```

**Windows PowerShell:**
```powershell
# Run setup (replace with your GitHub repository)
.\scripts\setup-iam-role.ps1 -Repository "your-org/aws-bom-infrastructure"
```

### Option 2: Direct AWS CLI Command

```bash
# Deploy IAM role directly
aws cloudformation deploy \
  --template-file iam/setup-oidc-role.yaml \
  --stack-name github-actions-bom-iam-role \
  --parameter-overrides \
    GitHubRepository="your-org/aws-bom-infrastructure" \
    GitHubBranch="main" \
  --capabilities CAPABILITY_NAMED_IAM \
  --region eu-north-1
```

## What Gets Created

The IAM role will be created with:
- **Role Name**: `GitHubActionsBOMCloudFormationRole`
- **Trust Policy**: Only allows your specific GitHub repository and branch
- **Permissions**: Least privilege for CloudFormation, EC2, VPC, S3, RDS operations
- **Region**: eu-north-1
- **Account**: 588681235095

## Verification

After deployment, verify the role:

```bash
# Check role exists
aws iam get-role --role-name GitHubActionsBOMCloudFormationRole

# Get role ARN
aws cloudformation describe-stacks \
  --stack-name github-actions-bom-iam-role \
  --query 'Stacks[0].Outputs[?OutputKey==`RoleArn`].OutputValue' \
  --output text
```

## Next Steps

1. **Configure GitHub Environment**:
   - Go to your repository → Settings → Environments
   - Create environment named `production`
   - Add required reviewers

2. **Update BOM File**:
   - Edit `bom/customer-bom.csv` with your infrastructure

3. **Deploy Infrastructure**:
   - Use GitHub Actions workflow
   - Or run local deployment scripts

## Role ARN Format

Your role ARN will be:
```
arn:aws:iam::588681235095:role/GitHubActionsBOMCloudFormationRole
```

## Important Notes

- ✅ OIDC provider already exists (no need to create)
- ✅ Role restricted to your specific GitHub repository
- ✅ Manual approval required for all deployments
- ✅ Least privilege permissions only
- ⚠️ Replace `your-org/aws-bom-infrastructure` with your actual repository name

## Troubleshooting

**Issue**: Role creation fails
**Solution**: Ensure you have IAM permissions and are in the correct AWS account (588681235095)

**Issue**: GitHub Actions can't assume role
**Solution**: Verify repository name matches exactly in trust policy

**Issue**: Permission denied during deployment
**Solution**: Check IAM role has required CloudFormation permissions