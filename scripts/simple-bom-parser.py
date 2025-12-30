#!/usr/bin/env python3
"""
Simple BOM Parser that actually works
Reads BOM CSV and creates CloudFormation parameters
"""

import csv
import json
import os
import sys

def read_bom_csv(file_path):
    """Read BOM CSV file and return enabled resources"""
    resources = []
    
    try:
        with open(file_path, 'r') as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                if row.get('enabled', '').lower() == 'true':
                    resources.append(row)
        
        print(f"✅ Found {len(resources)} enabled resources in BOM")
        return resources
    
    except Exception as e:
        print(f"❌ Error reading BOM file: {e}")
        sys.exit(1)

def create_network_parameters(resources, environment):
    """Create network stack parameters"""
    params = []
    
    # Default values
    vpc_cidr = "10.0.0.0/16"
    pub_1a = "10.0.1.0/24"
    pub_1b = "10.0.2.0/24"
    priv_1a = "10.0.10.0/24"
    priv_1b = "10.0.20.0/24"
    create_nat = "false"
    
    # Extract values from BOM
    for resource in resources:
        if resource['resource_type'] == 'vpc':
            vpc_cidr = resource.get('cidr_block', vpc_cidr)
        elif resource['resource_type'] == 'subnet':
            if 'public-subnet-1a' in resource['resource_name']:
                pub_1a = resource.get('cidr_block', pub_1a)
            elif 'public-subnet-1b' in resource['resource_name']:
                pub_1b = resource.get('cidr_block', pub_1b)
            elif 'private-subnet-1a' in resource['resource_name']:
                priv_1a = resource.get('cidr_block', priv_1a)
            elif 'private-subnet-1b' in resource['resource_name']:
                priv_1b = resource.get('cidr_block', priv_1b)
        elif resource['resource_type'] == 'natgw':
            create_nat = "true"
    
    # Build parameters
    params = [
        {"ParameterKey": "Environment", "ParameterValue": environment},
        {"ParameterKey": "VpcCidr", "ParameterValue": vpc_cidr},
        {"ParameterKey": "PublicSubnet1aCidr", "ParameterValue": pub_1a},
        {"ParameterKey": "PublicSubnet1bCidr", "ParameterValue": pub_1b},
        {"ParameterKey": "PrivateSubnet1aCidr", "ParameterValue": priv_1a},
        {"ParameterKey": "PrivateSubnet1bCidr", "ParameterValue": priv_1b},
        {"ParameterKey": "CreateNatGateway", "ParameterValue": create_nat}
    ]
    
    return params

def create_compute_parameters(resources, environment):
    """Create compute stack parameters"""
    params = [
        {"ParameterKey": "Environment", "ParameterValue": environment},
        {"ParameterKey": "NetworkStackName", "ParameterValue": "network-stack"},
        {"ParameterKey": "CreateInstance1", "ParameterValue": "false"},
        {"ParameterKey": "CreateInstance2", "ParameterValue": "false"},
        {"ParameterKey": "InstanceType1", "ParameterValue": "t3.medium"},
        {"ParameterKey": "InstanceType2", "ParameterValue": "t3.medium"},
        {"ParameterKey": "VolumeSize1", "ParameterValue": "40"},
        {"ParameterKey": "VolumeSize2", "ParameterValue": "40"},
        {"ParameterKey": "KeyPairName", "ParameterValue": ""}
    ]
    
    # Check for EC2 instances in BOM
    ec2_count = 0
    for resource in resources:
        if resource['resource_type'] == 'ec2':
            ec2_count += 1
            instance_type = resource.get('instance_type', 't3.medium')
            storage_size = resource.get('storage_size', '40')
            
            if ec2_count == 1:
                params[2]["ParameterValue"] = "true"  # CreateInstance1
                params[4]["ParameterValue"] = instance_type  # InstanceType1
                params[6]["ParameterValue"] = storage_size  # VolumeSize1
            elif ec2_count == 2:
                params[3]["ParameterValue"] = "true"  # CreateInstance2
                params[5]["ParameterValue"] = instance_type  # InstanceType2
                params[7]["ParameterValue"] = storage_size  # VolumeSize2
    
    return params

def create_storage_parameters(resources, environment):
    """Create storage stack parameters"""
    params = [
        {"ParameterKey": "Environment", "ParameterValue": environment},
        {"ParameterKey": "CreateBucket", "ParameterValue": "false"},
        {"ParameterKey": "EnableVersioning", "ParameterValue": "true"},
        {"ParameterKey": "EnableEncryption", "ParameterValue": "true"},
        {"ParameterKey": "BucketName", "ParameterValue": ""}
    ]
    
    # Check for S3 buckets in BOM
    for resource in resources:
        if resource['resource_type'] == 's3':
            params[1]["ParameterValue"] = "true"  # CreateBucket
            bucket_name = f"bom-{resource['resource_name']}-{environment}-588681235095"
            params[4]["ParameterValue"] = bucket_name.lower().replace('_', '-')
            break
    
    return params

def main():
    if len(sys.argv) != 3:
        print("Usage: python simple-bom-parser.py <bom-file> <environment>")
        sys.exit(1)
    
    bom_file = sys.argv[1]
    environment = sys.argv[2]
    
    print(f"🔍 Processing BOM file: {bom_file}")
    print(f"🎯 Target environment: {environment}")
    
    # Read BOM
    resources = read_bom_csv(bom_file)
    
    # Create output directory
    os.makedirs('parameters', exist_ok=True)
    
    # Generate parameters for each stack
    stacks = {
        'network-stack': create_network_parameters(resources, environment),
        'compute-stack': create_compute_parameters(resources, environment),
        'storage-stack': create_storage_parameters(resources, environment)
    }
    
    # Write parameter files
    for stack_name, params in stacks.items():
        param_file = f'parameters/{stack_name}-parameters.json'
        with open(param_file, 'w') as f:
            json.dump(params, f, indent=2)
        print(f"✅ Created {param_file}")
    
    # Create deployment manifest
    manifest = {
        "deployment_order": ["network-stack", "compute-stack", "storage-stack"],
        "stacks": {
            "network-stack": {"template": "cloudformation/network-stack.yaml"},
            "compute-stack": {"template": "cloudformation/compute-stack.yaml"},
            "storage-stack": {"template": "cloudformation/storage-stack.yaml"}
        }
    }
    
    with open('parameters/deployment-manifest.json', 'w') as f:
        json.dump(manifest, f, indent=2)
    
    print("✅ Created deployment manifest")
    print("🚀 Ready for deployment!")

if __name__ == '__main__':
    main()