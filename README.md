# AWS BOM-Driven Infrastructure Deployment

A production-ready solution for deploying AWS infrastructure using Bill of Materials (BOM) CSV files as the single source of truth.

## Overview

This solution provides:
- **BOM-Driven Deployment**: Single CSV file per customer defines all infrastructure
- **OIDC Authentication**: Secure GitHub Actions integration without access keys
- **Manual Approval**: Required approval before any deployment
- **Modular CloudFormation**: Separate stacks for different resource types
- **Incremental Scaling**: Add new resources without recreating existing ones

## Quick Start

1. **Setup IAM Role**: Deploy the OIDC IAM role using `iam/setup-oidc-role.yaml`
2. **Configure BOM**: Update `bom/customer-bom.csv` with your infrastructure requirements
3. **Deploy**: Run the GitHub Actions workflow with manual approval
4. **Scale**: Add new rows to BOM CSV for additional resources

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   BOM CSV       │───▶│  GitHub Actions  │───▶│  CloudFormation │
│ (Source of      │    │  (OIDC + Manual  │    │  (Modular       │
│  Truth)         │    │   Approval)      │    │   Stacks)       │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Target Environment

- **AWS Account**: 588681235095
- **Region**: eu-north-1
- **Authentication**: OIDC-based IAM role

## Repository Structure

```
aws-bom-infrastructure/
├── .github/workflows/          # GitHub Actions workflows
├── bom/                        # BOM CSV files
├── cloudformation/             # CloudFormation templates
├── iam/                        # IAM role setup
├── scripts/                    # BOM processing scripts
└── docs/                       # Documentation
```

## Security

- No AWS access keys required
- OIDC trust policy restricts access by repository and branch
- Least privilege IAM permissions
- Manual approval required for all deployments

## Scaling

The BOM CSV supports incremental scaling:
- **Add rows**: Deploy new resources
- **Update rows**: Modify existing resources
- **Disable rows**: Skip resource deployment
- **No pipeline changes**: Same workflow handles any BOM size