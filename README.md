# AWS BOM-Driven Infrastructure Deployment

**Simple, Working BOM-driven AWS Infrastructure Deployment**

## 🚀 Quick Start

1. **Go to Actions tab** → "Deploy BOM Infrastructure (Simple)"
2. **Select environment**: `development`
3. **Run workflow**
4. **Wait for deployment** (no manual approval needed)

## 📋 Current BOM Configuration

| Resource | Type | Status | Will Deploy |
|----------|------|--------|-------------|
| main-vpc | VPC | ✅ Enabled | VPC with subnets |
| web-server-1 | EC2 | ✅ Enabled | **t3.medium instance** |
| web-server-2 | EC2 | ❌ Disabled | Ready for scaling |
| app-storage-bucket | S3 | ✅ Enabled | **S3 bucket** |

## 🎯 What Will Be Deployed

When you run the workflow:

1. **Network Stack**: VPC, subnets, internet gateway, NAT gateway
2. **Compute Stack**: **1 EC2 instance (web-server-1)** 
3. **Storage Stack**: **1 S3 bucket**

## 🔄 Test Scaling

After successful deployment:

1. **Edit BOM file**: Change `web-server-2` from `false` to `true`
2. **Run workflow again**: Same GitHub Actions workflow  
3. **Verify**: Second EC2 instance will be created

## ✅ Expected Results

After deployment you'll have:
- ✅ **VPC**: 10.0.0.0/16 with public/private subnets
- ✅ **EC2 Instance**: web-server-1 running Apache
- ✅ **S3 Bucket**: Encrypted storage bucket
- ✅ **Public IP**: Access web server via HTTP

## 🎯 Target Environment

- **AWS Account**: 588681235095
- **Region**: eu-north-1  
- **Environment**: development

**This simplified solution actually works and deploys your BOM resources!**