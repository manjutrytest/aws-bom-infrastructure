#!/usr/bin/env python3
"""
BOM CSV Parser for AWS Infrastructure Deployment
Converts BOM CSV entries into CloudFormation parameters
"""

import csv
import json
import sys
import os
from typing import Dict, List, Any
import argparse

class BOMParser:
    def __init__(self, bom_file_path: str):
        self.bom_file_path = bom_file_path
        self.bom_data = []
        self.stacks = {}
        
    def load_bom(self) -> None:
        """Load BOM CSV file and parse entries"""
        try:
            with open(self.bom_file_path, 'r', newline='', encoding='utf-8') as csvfile:
                reader = csv.DictReader(csvfile)
                self.bom_data = [row for row in reader if row.get('enabled', '').lower() == 'true']
                
            print(f"✅ Loaded {len(self.bom_data)} enabled entries from BOM")
            
        except FileNotFoundError:
            print(f"❌ Error: BOM file not found: {self.bom_file_path}")
            sys.exit(1)
        except Exception as e:
            print(f"❌ Error loading BOM file: {str(e)}")
            sys.exit(1)
    
    def group_by_stack(self) -> None:
        """Group BOM entries by stack name"""
        for entry in self.bom_data:
            stack_name = entry.get('stack_name', 'default-stack')
            if stack_name not in self.stacks:
                self.stacks[stack_name] = []
            self.stacks[stack_name].append(entry)
    
    def generate_network_parameters(self, entries: List[Dict]) -> Dict[str, Any]:
        """Generate parameters for network stack"""
        params = {
            'Environment': 'production',
            'CreateNatGateway': 'false'
        }
        
        for entry in entries:
            resource_type = entry.get('resource_type', '').lower()
            resource_name = entry.get('resource_name', '')
            cidr_block = entry.get('cidr_block', '')
            
            if resource_type == 'vpc' and cidr_block:
                params['VpcCidr'] = cidr_block
                params['Environment'] = entry.get('environment', 'production')
            
            elif resource_type == 'subnet':
                if 'public-subnet-1a' in resource_name and cidr_block:
                    params['PublicSubnet1aCidr'] = cidr_block
                elif 'public-subnet-1b' in resource_name and cidr_block:
                    params['PublicSubnet1bCidr'] = cidr_block
                elif 'private-subnet-1a' in resource_name and cidr_block:
                    params['PrivateSubnet1aCidr'] = cidr_block
                elif 'private-subnet-1b' in resource_name and cidr_block:
                    params['PrivateSubnet1bCidr'] = cidr_block
            
            elif resource_type == 'natgw':
                params['CreateNatGateway'] = 'true'
        
        return params
    
    def generate_compute_parameters(self, entries: List[Dict]) -> Dict[str, Any]:
        """Generate parameters for compute stack"""
        params = {
            'Environment': 'production',
            'NetworkStackName': 'network-stack',
            'CreateInstance1': 'false',
            'CreateInstance2': 'false',
            'InstanceType1': 't3.medium',
            'InstanceType2': 't3.medium',
            'VolumeSize1': 40,
            'VolumeSize2': 40,
            'KeyPairName': ''
        }
        
        instance_count = 0
        for entry in entries:
            resource_type = entry.get('resource_type', '').lower()
            
            if resource_type == 'ec2':
                instance_count += 1
                instance_type = entry.get('instance_type', 't3.medium')
                storage_size = int(entry.get('storage_size', 40))
                environment = entry.get('environment', 'production')
                
                if instance_count == 1:
                    params['CreateInstance1'] = 'true'
                    params['InstanceType1'] = instance_type
                    params['VolumeSize1'] = storage_size
                elif instance_count == 2:
                    params['CreateInstance2'] = 'true'
                    params['InstanceType2'] = instance_type
                    params['VolumeSize2'] = storage_size
                
                params['Environment'] = environment
        
        return params
    
    def generate_storage_parameters(self, entries: List[Dict]) -> Dict[str, Any]:
        """Generate parameters for storage stack"""
        params = {
            'Environment': 'production',
            'CreateBucket': 'false',
            'EnableVersioning': 'true',
            'EnableEncryption': 'true',
            'BucketName': ''
        }
        
        for entry in entries:
            resource_type = entry.get('resource_type', '').lower()
            
            if resource_type == 's3':
                params['CreateBucket'] = 'true'
                params['Environment'] = entry.get('environment', 'production')
                
                # Generate bucket name if not provided
                resource_name = entry.get('resource_name', '')
                if resource_name:
                    # S3 bucket names must be globally unique and DNS compliant
                    bucket_name = f"bom-{resource_name}-{params['Environment']}"
                    params['BucketName'] = bucket_name.lower().replace('_', '-')
        
        return params
    
    def generate_database_parameters(self, entries: List[Dict]) -> Dict[str, Any]:
        """Generate parameters for database stack"""
        params = {
            'Environment': 'production',
            'NetworkStackName': 'network-stack',
            'CreateDatabase': 'false',
            'DBInstanceClass': 'db.t3.micro',
            'DBAllocatedStorage': 20,
            'DBName': 'appdb',
            'DBUsername': 'admin',
            'MultiAZ': 'false',
            'BackupRetentionPeriod': 7
        }
        
        for entry in entries:
            resource_type = entry.get('resource_type', '').lower()
            
            if resource_type == 'rds':
                params['CreateDatabase'] = 'true'
                params['Environment'] = entry.get('environment', 'production')
                
                instance_type = entry.get('instance_type', 'db.t3.micro')
                storage_size = int(entry.get('storage_size', 20))
                
                params['DBInstanceClass'] = instance_type
                params['DBAllocatedStorage'] = storage_size
        
        return params
    
    def generate_parameters_files(self, output_dir: str = 'parameters') -> None:
        """Generate CloudFormation parameter files for each stack"""
        os.makedirs(output_dir, exist_ok=True)
        
        stack_generators = {
            'network-stack': self.generate_network_parameters,
            'compute-stack': self.generate_compute_parameters,
            'storage-stack': self.generate_storage_parameters,
            'database-stack': self.generate_database_parameters
        }
        
        for stack_name, entries in self.stacks.items():
            if stack_name in stack_generators:
                params = stack_generators[stack_name](entries)
                
                # Convert to CloudFormation parameter format
                cf_params = []
                for key, value in params.items():
                    cf_params.append({
                        'ParameterKey': key,
                        'ParameterValue': str(value)
                    })
                
                # Write parameter file
                param_file = os.path.join(output_dir, f'{stack_name}-parameters.json')
                with open(param_file, 'w') as f:
                    json.dump(cf_params, f, indent=2)
                
                print(f"✅ Generated parameters for {stack_name}: {param_file}")
            else:
                print(f"⚠️  Unknown stack type: {stack_name}")
    
    def get_deployment_order(self) -> List[str]:
        """Get the correct order for stack deployment"""
        deployment_order = []
        
        # Network stack must be deployed first
        if 'network-stack' in self.stacks:
            deployment_order.append('network-stack')
        
        # Storage can be deployed independently
        if 'storage-stack' in self.stacks:
            deployment_order.append('storage-stack')
        
        # Compute depends on network
        if 'compute-stack' in self.stacks:
            deployment_order.append('compute-stack')
        
        # Database depends on network and optionally compute
        if 'database-stack' in self.stacks:
            deployment_order.append('database-stack')
        
        return deployment_order
    
    def generate_deployment_manifest(self, output_dir: str = 'parameters') -> None:
        """Generate deployment manifest with stack order and metadata"""
        manifest = {
            'deployment_order': self.get_deployment_order(),
            'stacks': {},
            'metadata': {
                'bom_file': self.bom_file_path,
                'total_entries': len(self.bom_data),
                'enabled_stacks': list(self.stacks.keys())
            }
        }
        
        for stack_name in self.stacks:
            manifest['stacks'][stack_name] = {
                'template': f'cloudformation/{stack_name}.yaml',
                'parameters': f'parameters/{stack_name}-parameters.json',
                'resources': len(self.stacks[stack_name])
            }
        
        manifest_file = os.path.join(output_dir, 'deployment-manifest.json')
        with open(manifest_file, 'w') as f:
            json.dump(manifest, f, indent=2)
        
        print(f"✅ Generated deployment manifest: {manifest_file}")
    
    def validate_bom(self) -> bool:
        """Validate BOM entries for required fields"""
        required_fields = ['resource_type', 'resource_name', 'stack_name', 'enabled']
        errors = []
        
        for i, entry in enumerate(self.bom_data, 1):
            for field in required_fields:
                if not entry.get(field):
                    errors.append(f"Row {i}: Missing required field '{field}'")
        
        if errors:
            print("❌ BOM Validation Errors:")
            for error in errors:
                print(f"   {error}")
            return False
        
        print("✅ BOM validation passed")
        return True
    
    def print_summary(self) -> None:
        """Print deployment summary"""
        print("\n" + "="*50)
        print("BOM DEPLOYMENT SUMMARY")
        print("="*50)
        print(f"Total enabled entries: {len(self.bom_data)}")
        print(f"Stacks to deploy: {len(self.stacks)}")
        print("\nStack breakdown:")
        
        for stack_name, entries in self.stacks.items():
            print(f"  {stack_name}: {len(entries)} resources")
            for entry in entries:
                resource_type = entry.get('resource_type', 'unknown')
                resource_name = entry.get('resource_name', 'unnamed')
                print(f"    - {resource_type}: {resource_name}")
        
        print(f"\nDeployment order: {' → '.join(self.get_deployment_order())}")
        print("="*50)

def main():
    parser = argparse.ArgumentParser(description='Parse BOM CSV and generate CloudFormation parameters')
    parser.add_argument('bom_file', help='Path to BOM CSV file')
    parser.add_argument('--output-dir', default='parameters', help='Output directory for parameter files')
    parser.add_argument('--validate-only', action='store_true', help='Only validate BOM without generating files')
    
    args = parser.parse_args()
    
    # Initialize BOM parser
    bom_parser = BOMParser(args.bom_file)
    
    # Load and validate BOM
    bom_parser.load_bom()
    
    if not bom_parser.validate_bom():
        sys.exit(1)
    
    if args.validate_only:
        print("✅ BOM validation completed successfully")
        return
    
    # Group entries by stack
    bom_parser.group_by_stack()
    
    # Generate parameter files
    bom_parser.generate_parameters_files(args.output_dir)
    
    # Generate deployment manifest
    bom_parser.generate_deployment_manifest(args.output_dir)
    
    # Print summary
    bom_parser.print_summary()

if __name__ == '__main__':
    main()