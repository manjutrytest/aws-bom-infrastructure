# BOM-Driven AWS Infrastructure Deployment

A production-ready solution for deploying AWS infrastructure using a Bill of Materials (BOM) CSV file as the source of truth.

## 🚀 Quick Start

1. **Prerequisites**: Ensure IAM role `GitHubActionsBOMCloudFormationRole` exists in AWS account 588681235095
2. **Update BOM**: Edit `bom/customer-bom.csv` to enable/disable resources
3. **Deploy**: Run the "Deploy BOM Infrastructure (Direct)" GitHub Actions workflow
4. **Monitor**: Check AWS CloudFormation console for stack status

## 📋 Current BOM Status

Based on `bom/customer-bom.csv`:

### ✅ Enabled Resources (will be deployed)
- **VPC**: 10.0.0.0/16 with public/private subnets
- **NAT Gateway**: For private subnet internet access  
- **EC2 Instance**: web-server-1 (t3.medium, 40GB)
- **S3 Bucket**: app-storage-bucket

### ❌ Disabled Resources (will NOT be deployed)
- **EC2 Instance**: web-server-2 (disabled in BOM)
- **RDS Database**: app-database (disabled in BOM)

## 🔧 How It Works

1. **BOM Parser** reads `bom/customer-bom.csv` and generates CloudFormation parameters
2. **GitHub Actions** workflow deploys stacks in order: Network → Compute → Storage
3. **CloudFormation** creates only enabled resources using conditional logic
4. **Scaling**: Enable web-server-2 in BOM to add second instance

## 📁 Repository Structure

```
├── bom/
│   └── customer-bom.csv              # Infrastructure definition (source of truth)
├── cloudformation/
│   ├── network-stack.yaml            # VPC, subnets, gateways
│   ├── compute-stack.yaml            # EC2 instances
│   ├── storage-stack.yaml            # S3 buckets
│   └── database-stack.yaml           # RDS instances (optional)
├── scripts/
│   ├── simple-bom-parser.py          # BOM to CloudFormation converter
│   ├── parse-bom.py                  # Backward compatibility wrapper
│   ├── setup-iam-role.*              # IAM role setup scripts
│   └── fix-oidc-trust-policy.ps1     # OIDC troubleshooting script
├── .github/workflows/
│   └── deploy-bom-direct.yml         # Main deployment workflow
└── parameters/                       # Generated CloudFormation parameters
```

## 🎯 Target Environment

- **AWS Account**: 588681235095
- **Region**: eu-north-1  
- **Environment**: development

## 🔄 Scaling Example

To add the second web server:
1. Edit `bom/customer-bom.csv`
2. Change `web-server-2` enabled from `false` to `true`
3. Run the workflow again
4. Only the new instance will be created (existing resources unchanged)

## 🛠️ Troubleshooting

### OIDC Authentication Issues
If you get "Not authorized to perform sts:AssumeRoleWithWebIdentity":
```powershell
.\scripts\fix-oidc-trust-policy.ps1
```

### Setup IAM Role
If the IAM role doesn't exist:
```powershell
.\scripts\setup-iam-role.ps1 -Repository "manjutrytest/aws-bom-infrastructure"
```

## ✅ Deployment Status

- ✅ Network Stack: Deployed successfully
- 🔄 Compute Stack: Ready to deploy web-server-1
- 🔄 Storage Stack: Ready to deploy S3 bucket

**Ready for deployment! Use the "Deploy BOM Infrastructure (Direct)" workflow.**