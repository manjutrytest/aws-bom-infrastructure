# AWS BOM-Driven Infrastructure Deployment

Deploy AWS infrastructure using Bill of Materials (BOM) CSV files via GitHub Actions.

## 🚀 Quick Start

1. **Setup Complete**: IAM role already configured
2. **Deploy via GitHub Actions**:
   - Go to Actions tab → "Deploy BOM-driven AWS Infrastructure"
   - Select environment: `development`
   - Run workflow
   - Approve deployment when prompted

## 📋 Current BOM Configuration

| Resource | Type | Status | Description |
|----------|------|--------|-------------|
| main-vpc | VPC | ✅ Enabled | Main VPC (10.0.0.0/16) |
| public-subnet-1a | Subnet | ✅ Enabled | Public subnet AZ-a |
| public-subnet-1b | Subnet | ✅ Enabled | Public subnet AZ-b |
| private-subnet-1a | Subnet | ✅ Enabled | Private subnet AZ-a |
| private-subnet-1b | Subnet | ✅ Enabled | Private subnet AZ-b |
| main-igw | IGW | ✅ Enabled | Internet Gateway |
| nat-gateway-1a | NAT | ✅ Enabled | NAT Gateway |
| **web-server-1** | **EC2** | **✅ Enabled** | **t3.medium, 40GB** |
| web-server-2 | EC2 | ❌ Disabled | t3.medium, 40GB |
| app-storage-bucket | S3 | ✅ Enabled | Application storage |
| app-database | RDS | ❌ Disabled | db.t3.micro, 20GB |

## 🔄 Test Scaling

After successful deployment, test scaling by:

1. **Edit BOM file**: Change `web-server-2` from `false` to `true`
2. **Run workflow again**: Same GitHub Actions workflow
3. **Approve deployment**: Review and approve changes
4. **Verify**: Check AWS console for second EC2 instance

## 🎯 Target Environment

- **AWS Account**: 588681235095
- **Region**: eu-north-1
- **Environment**: development
- **IAM Role**: GitHubActionsBOMCloudFormationRole

## ✅ Expected Deployment

When you run the GitHub Actions workflow, it will deploy:

1. **Network Stack**: VPC, subnets, gateways (already deployed)
2. **Compute Stack**: EC2 instance (web-server-1)
3. **Storage Stack**: S3 bucket

**All resources will be deployed in a single workflow run with manual approval.**