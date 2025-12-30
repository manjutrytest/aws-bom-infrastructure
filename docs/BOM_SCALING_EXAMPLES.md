# BOM Scaling Examples

This document demonstrates how to scale your AWS infrastructure using the BOM-driven approach with real-world scenarios.

## Initial Deployment

Let's start with a minimal infrastructure setup:

### Initial BOM (`bom/customer-bom.csv`)

```csv
resource_type,resource_name,environment,stack_name,cidr_block,instance_type,storage_size,enabled,region,description
vpc,main-vpc,production,network-stack,10.0.0.0/16,,,true,eu-north-1,Main VPC for production environment
subnet,public-subnet-1a,production,network-stack,10.0.1.0/24,,,true,eu-north-1,Public subnet in AZ 1a
subnet,private-subnet-1a,production,network-stack,10.0.10.0/24,,,true,eu-north-1,Private subnet in AZ 1a
igw,main-igw,production,network-stack,,,,true,eu-north-1,Internet Gateway for public access
ec2,web-server-1,production,compute-stack,,t3.medium,40,true,eu-north-1,Primary web server
s3,app-storage-bucket,production,storage-stack,,,,true,eu-north-1,Application storage bucket
```

### What Gets Deployed

1. **Network Stack**:
   - VPC with CIDR 10.0.0.0/16
   - One public subnet (10.0.1.0/24)
   - One private subnet (10.0.10.0/24)
   - Internet Gateway

2. **Compute Stack**:
   - One t3.medium EC2 instance in public subnet
   - Security groups for web access

3. **Storage Stack**:
   - One S3 bucket with encryption and lifecycle policies

## Scaling Scenario 1: Adding High Availability

### Updated BOM - Multi-AZ Setup

```csv
resource_type,resource_name,environment,stack_name,cidr_block,instance_type,storage_size,enabled,region,description
vpc,main-vpc,production,network-stack,10.0.0.0/16,,,true,eu-north-1,Main VPC for production environment
subnet,public-subnet-1a,production,network-stack,10.0.1.0/24,,,true,eu-north-1,Public subnet in AZ 1a
subnet,public-subnet-1b,production,network-stack,10.0.2.0/24,,,true,eu-north-1,Public subnet in AZ 1b
subnet,private-subnet-1a,production,network-stack,10.0.10.0/24,,,true,eu-north-1,Private subnet in AZ 1a
subnet,private-subnet-1b,production,network-stack,10.0.20.0/24,,,true,eu-north-1,Private subnet in AZ 1b
igw,main-igw,production,network-stack,,,,true,eu-north-1,Internet Gateway for public access
natgw,nat-gateway-1a,production,network-stack,,,,true,eu-north-1,NAT Gateway for private subnet access
ec2,web-server-1,production,compute-stack,,t3.medium,40,true,eu-north-1,Web server in AZ 1a
ec2,web-server-2,production,compute-stack,,t3.medium,40,true,eu-north-1,Web server in AZ 1b
s3,app-storage-bucket,production,storage-stack,,,,true,eu-north-1,Application storage bucket
```

### Changes Made

- ✅ **Added**: Second public subnet (AZ 1b)
- ✅ **Added**: Second private subnet (AZ 1b)
- ✅ **Added**: NAT Gateway for private subnet internet access
- ✅ **Added**: Second EC2 instance for high availability
- ✅ **Enabled**: `web-server-2` by setting `enabled=true`

### Deployment Impact

- **Existing resources**: No changes to VPC, existing subnets, or first EC2 instance
- **New resources**: Additional subnets, NAT Gateway, and second EC2 instance
- **Zero downtime**: Existing web server continues running during deployment

## Scaling Scenario 2: Adding Database Tier

### Updated BOM - Database Integration

```csv
resource_type,resource_name,environment,stack_name,cidr_block,instance_type,storage_size,enabled,region,description
vpc,main-vpc,production,network-stack,10.0.0.0/16,,,true,eu-north-1,Main VPC for production environment
subnet,public-subnet-1a,production,network-stack,10.0.1.0/24,,,true,eu-north-1,Public subnet in AZ 1a
subnet,public-subnet-1b,production,network-stack,10.0.2.0/24,,,true,eu-north-1,Public subnet in AZ 1b
subnet,private-subnet-1a,production,network-stack,10.0.10.0/24,,,true,eu-north-1,Private subnet in AZ 1a
subnet,private-subnet-1b,production,network-stack,10.0.20.0/24,,,true,eu-north-1,Private subnet in AZ 1b
igw,main-igw,production,network-stack,,,,true,eu-north-1,Internet Gateway for public access
natgw,nat-gateway-1a,production,network-stack,,,,true,eu-north-1,NAT Gateway for private subnet access
ec2,web-server-1,production,compute-stack,,t3.medium,40,true,eu-north-1,Web server in AZ 1a
ec2,web-server-2,production,compute-stack,,t3.medium,40,true,eu-north-1,Web server in AZ 1b
s3,app-storage-bucket,production,storage-stack,,,,true,eu-north-1,Application storage bucket
rds,app-database,production,database-stack,,db.t3.micro,20,true,eu-north-1,Application MySQL database
```

### Changes Made

- ✅ **Added**: RDS MySQL database in private subnets
- ✅ **Enabled**: Database deployment by setting `enabled=true`

### Deployment Impact

- **New stack**: Database stack gets deployed
- **New resources**: RDS instance, DB subnet group, security groups
- **Existing resources**: No impact on network, compute, or storage stacks

## Scaling Scenario 3: Performance Optimization

### Updated BOM - Upgraded Instances

```csv
resource_type,resource_name,environment,stack_name,cidr_block,instance_type,storage_size,enabled,region,description
vpc,main-vpc,production,network-stack,10.0.0.0/16,,,true,eu-north-1,Main VPC for production environment
subnet,public-subnet-1a,production,network-stack,10.0.1.0/24,,,true,eu-north-1,Public subnet in AZ 1a
subnet,public-subnet-1b,production,network-stack,10.0.2.0/24,,,true,eu-north-1,Public subnet in AZ 1b
subnet,private-subnet-1a,production,network-stack,10.0.10.0/24,,,true,eu-north-1,Private subnet in AZ 1a
subnet,private-subnet-1b,production,network-stack,10.0.20.0/24,,,true,eu-north-1,Private subnet in AZ 1b
igw,main-igw,production,network-stack,,,,true,eu-north-1,Internet Gateway for public access
natgw,nat-gateway-1a,production,network-stack,,,,true,eu-north-1,NAT Gateway for private subnet access
ec2,web-server-1,production,compute-stack,,t3.large,80,true,eu-north-1,Upgraded web server in AZ 1a
ec2,web-server-2,production,compute-stack,,t3.large,80,true,eu-north-1,Upgraded web server in AZ 1b
s3,app-storage-bucket,production,storage-stack,,,,true,eu-north-1,Application storage bucket
rds,app-database,production,database-stack,,db.t3.small,50,true,eu-north-1,Upgraded MySQL database
```

### Changes Made

- 🔄 **Updated**: EC2 instances from `t3.medium` to `t3.large`
- 🔄 **Updated**: EC2 storage from `40GB` to `80GB`
- 🔄 **Updated**: RDS instance from `db.t3.micro` to `db.t3.small`
- 🔄 **Updated**: RDS storage from `20GB` to `50GB`

### Deployment Impact

- **EC2 instances**: Will be replaced with larger instances (brief downtime)
- **RDS database**: Will be modified in-place (minimal downtime)
- **Storage**: EBS volumes will be expanded without downtime

## Scaling Scenario 4: Cost Optimization

### Updated BOM - Temporary Scale Down

```csv
resource_type,resource_name,environment,stack_name,cidr_block,instance_type,storage_size,enabled,region,description
vpc,main-vpc,production,network-stack,10.0.0.0/16,,,true,eu-north-1,Main VPC for production environment
subnet,public-subnet-1a,production,network-stack,10.0.1.0/24,,,true,eu-north-1,Public subnet in AZ 1a
subnet,public-subnet-1b,production,network-stack,10.0.2.0/24,,,true,eu-north-1,Public subnet in AZ 1b
subnet,private-subnet-1a,production,network-stack,10.0.10.0/24,,,true,eu-north-1,Private subnet in AZ 1a
subnet,private-subnet-1b,production,network-stack,10.0.20.0/24,,,true,eu-north-1,Private subnet in AZ 1b
igw,main-igw,production,network-stack,,,,true,eu-north-1,Internet Gateway for public access
natgw,nat-gateway-1a,production,network-stack,,,,false,eu-north-1,NAT Gateway (disabled for cost savings)
ec2,web-server-1,production,compute-stack,,t3.medium,40,true,eu-north-1,Primary web server
ec2,web-server-2,production,compute-stack,,t3.medium,40,false,eu-north-1,Secondary web server (disabled)
s3,app-storage-bucket,production,storage-stack,,,,true,eu-north-1,Application storage bucket
rds,app-database,production,database-stack,,db.t3.micro,20,false,eu-north-1,Database (disabled for cost savings)
```

### Changes Made

- ❌ **Disabled**: NAT Gateway (`enabled=false`)
- ❌ **Disabled**: Second EC2 instance (`enabled=false`)
- ❌ **Disabled**: RDS database (`enabled=false`)
- 🔄 **Downgraded**: Remaining EC2 back to `t3.medium`

### Deployment Impact

- **Disabled resources**: Will be skipped during deployment (existing resources remain)
- **Cost savings**: Significant reduction in monthly costs
- **Functionality**: Single instance setup, no database tier

## Scaling Scenario 5: Multi-Environment Setup

### Staging Environment BOM (`bom/staging-bom.csv`)

```csv
resource_type,resource_name,environment,stack_name,cidr_block,instance_type,storage_size,enabled,region,description
vpc,staging-vpc,staging,network-stack,10.1.0.0/16,,,true,eu-north-1,Staging VPC
subnet,public-subnet-1a,staging,network-stack,10.1.1.0/24,,,true,eu-north-1,Staging public subnet
subnet,private-subnet-1a,staging,network-stack,10.1.10.0/24,,,true,eu-north-1,Staging private subnet
igw,staging-igw,staging,network-stack,,,,true,eu-north-1,Staging Internet Gateway
ec2,staging-web-server,staging,compute-stack,,t3.small,20,true,eu-north-1,Staging web server
s3,staging-storage-bucket,staging,storage-stack,,,,true,eu-north-1,Staging storage bucket
```

### Changes Made

- 🆕 **New environment**: Separate staging infrastructure
- 🆕 **Different CIDR**: 10.1.0.0/16 to avoid conflicts
- 🆕 **Smaller instances**: t3.small for cost efficiency
- 🆕 **Minimal setup**: Single AZ, no database

## Advanced Scaling Patterns

### Pattern 1: Blue-Green Deployment Preparation

```csv
# Add new "green" environment resources
ec2,web-server-1-green,production,compute-stack-green,,t3.large,80,false,eu-north-1,Green deployment web server 1
ec2,web-server-2-green,production,compute-stack-green,,t3.large,80,false,eu-north-1,Green deployment web server 2
```

### Pattern 2: Disaster Recovery Region

```csv
# Add DR resources in different region
vpc,dr-vpc,production,network-stack-dr,10.2.0.0/16,,,true,us-west-2,DR VPC in us-west-2
ec2,dr-web-server,production,compute-stack-dr,,t3.medium,40,false,us-west-2,DR web server (standby)
```

### Pattern 3: Microservices Architecture

```csv
# Add service-specific resources
ec2,api-server-1,production,api-stack,,t3.medium,40,true,eu-north-1,API service server
ec2,worker-server-1,production,worker-stack,,t3.large,80,true,eu-north-1,Background worker server
rds,api-database,production,api-database-stack,,db.t3.small,50,true,eu-north-1,API service database
```

## BOM Evolution Timeline

### Week 1: MVP Launch
- Basic VPC + 1 EC2 + S3
- **Cost**: ~$50/month

### Week 4: High Availability
- Multi-AZ setup + NAT Gateway
- **Cost**: ~$120/month

### Month 3: Database Integration
- RDS MySQL + enhanced monitoring
- **Cost**: ~$180/month

### Month 6: Performance Optimization
- Larger instances + more storage
- **Cost**: ~$280/month

### Month 12: Full Production
- Multi-environment + DR setup
- **Cost**: ~$500/month

## Best Practices for BOM Scaling

### 1. Incremental Changes
```csv
# ✅ Good: Add one resource at a time
ec2,web-server-3,production,compute-stack,,t3.medium,40,true,eu-north-1,Additional web server

# ❌ Avoid: Multiple major changes at once
```

### 2. Test in Staging First
```bash
# Deploy to staging environment first
python scripts/parse-bom.py bom/staging-bom.csv
# Then promote to production
python scripts/parse-bom.py bom/production-bom.csv
```

### 3. Use Descriptive Names
```csv
# ✅ Good: Clear, descriptive names
ec2,api-server-primary,production,compute-stack,,t3.medium,40,true,eu-north-1,Primary API server

# ❌ Avoid: Generic names
ec2,server1,production,compute-stack,,t3.medium,40,true,eu-north-1,Server
```

### 4. Plan for Dependencies
```csv
# Deploy network resources first
vpc,main-vpc,production,network-stack,10.0.0.0/16,,,true,eu-north-1,Main VPC
# Then compute resources
ec2,web-server-1,production,compute-stack,,t3.medium,40,true,eu-north-1,Web server
# Finally database resources
rds,app-database,production,database-stack,,db.t3.micro,20,true,eu-north-1,Application database
```

### 5. Monitor Costs
```bash
# Use AWS Cost Explorer to track spending
# Set up billing alerts for budget management
# Review BOM regularly for optimization opportunities
```

## Rollback Strategies

### Disable New Resources
```csv
# If new resource causes issues, disable it
ec2,problematic-server,production,compute-stack,,t3.large,80,false,eu-north-1,Disabled due to issues
```

### Revert Instance Types
```csv
# Revert to previous instance type
ec2,web-server-1,production,compute-stack,,t3.medium,40,true,eu-north-1,Reverted to stable size
```

### Use Git for BOM History
```bash
# Track BOM changes in Git
git log --oneline bom/customer-bom.csv
git diff HEAD~1 bom/customer-bom.csv
git checkout HEAD~1 -- bom/customer-bom.csv  # Rollback BOM
```

This BOM-driven approach provides unprecedented flexibility for scaling AWS infrastructure while maintaining consistency, traceability, and cost control.