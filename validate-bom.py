#!/usr/bin/env python3
"""
Simple BOM validation script for GitHub Actions
"""

import sys
import os
sys.path.append('scripts')

from parse_bom import BOMParser

def main():
    print("🔍 Validating BOM configuration...")
    
    # Initialize parser
    parser = BOMParser('bom/customer-bom.csv')
    
    # Load and validate BOM
    parser.load_bom()
    
    if not parser.validate_bom():
        print("❌ BOM validation failed")
        sys.exit(1)
    
    # Group by stack
    parser.group_by_stack()
    
    # Generate parameters
    parser.generate_parameters_files('parameters')
    
    # Generate manifest
    parser.generate_deployment_manifest('parameters')
    
    # Print summary
    parser.print_summary()
    
    print("✅ BOM validation completed successfully")

if __name__ == '__main__':
    main()