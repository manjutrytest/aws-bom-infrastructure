# AWS BOM-Driven Infrastructure Deployment

A production-ready solution for deploying AWS infrastructure using Bill of Materials (BOM) CSV files as the single source of truth.

## 🚀 Quick Start

1. **Setup IAM Role** (one-time):
   ```powershell
   .\scripts\setup-iam-role.ps1 -Repository "manjutrytest/aws-bom-infrastructure"
   ```

2. **Test BOM Deployment**:
   ```powershell
   .\test-bom-deployment.ps1
   ```

3. **Deploy via GitHub Actions**:
   - Go to Actions tab → "Deploy BOM-driven AWS Infrastructure"
   - Select environment: `development`
   - Run workflow

## 📋 Current BOM Configuration

The BOM file defines these resources for **development** environment:

| Resource | Type | Status | Description |
|----------|------|--------|-------------|
| main-vpc | VPC | ✅ Enabled | Main VPC (10.0.0.0/16) |
| public-subnet-1a | Subnet | ✅ Enabled | Public subnet AZ-a |
| public-subnet-1b | Subnet | ✅ Enabled | Public subnet AZ-b |
| private-subnet-1a | Subnet | ✅ Enabled | Private subnet AZ-a |
| private-subnet-1b | Subnet | ✅ Enabled | Private subnet AZ-b |
| main-igw | IGW | ✅ Enabled | Internet Gateway |
| nat-gateway-1a | NAT | ✅ Enabled | NAT Gateway |
| web-server-1 | EC2 | ✅ Enabled | t3.medium, 40GB |
| web-server-2 | EC2 | ❌ Disabled | t3.medium, 40GB |
| app-storage-bucket | S3 | ✅ Enabled | Application storage |
| app-database | RDS | ❌ Disabled | db.t3.micro, 20GB |

## 🔄 Scaling Instructions

To add more resources:

1. **Enable web-server-2**:
   ```csv
   ec2,web-server-2,development,compute-stack,,t3.medium,40,true,eu-north-1,Secondary web server
   ```

2. **Enable database**:
   ```csv
   rds,app-database,development,database-stack,,db.t3.micro,20,true,eu-north-1,Application database
   ```

3. **Deploy changes**: Run GitHub Actions workflow again

## 🎯 Target Environment

- **AWS Account**: 588681235095
- **Region**: eu-north-1
- **Environment**: development
- **IAM Role**: GitHubActionsBOMCloudFormationRole

## 📁 Repository Structure

```
aws-bom-infrastructure/
├── bom/customer-bom.csv           # BOM configuration
├── cloudformation/                # CloudFormation templates
├── .github/workflows/             # GitHub Actions
├── scripts/                       # Automation scripts
├── iam/setup-oidc-role.yaml      # IAM role setup
└── test-bom-deployment.ps1       # Local testing
```

## 🔒 Security Features

- ✅ OIDC-based authentication (no access keys)
- ✅ Manual approval required for deployments
- ✅ Repository-specific trust policy
- ✅ Least privilege IAM permissions
- ✅ All resources encrypted by default