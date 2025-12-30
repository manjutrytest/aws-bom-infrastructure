#!/usr/bin/env python3
"""
Test the BOM parser locally
"""

import sys
import os

# Add scripts directory to path
sys.path.append('scripts')

# Test the parser
if __name__ == '__main__':
    print("Testing BOM parser...")
    
    # Check if files exist
    if os.path.exists('scripts/simple-bom-parser.py'):
        print("✅ simple-bom-parser.py exists")
    else:
        print("❌ simple-bom-parser.py not found")
    
    if os.path.exists('bom/customer-bom.csv'):
        print("✅ customer-bom.csv exists")
    else:
        print("❌ customer-bom.csv not found")
    
    # Try to run the parser
    try:
        import subprocess
        result = subprocess.run([
            'python', 'scripts/simple-bom-parser.py', 
            'bom/customer-bom.csv', 'development'
        ], capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ Parser ran successfully")
            print("Output:", result.stdout)
        else:
            print("❌ Parser failed")
            print("Error:", result.stderr)
    
    except Exception as e:
        print(f"❌ Error running parser: {e}")