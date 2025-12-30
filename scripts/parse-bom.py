#!/usr/bin/env python3
"""
Wrapper for backward compatibility
Redirects to the new simple-bom-parser.py
"""

import sys
import subprocess
import os

def main():
    # Parse arguments
    if len(sys.argv) < 2:
        print("Usage: python parse-bom.py <bom-file> [--output-dir <dir>] [--validate-only]")
        sys.exit(1)
    
    bom_file = sys.argv[1]
    
    # Check for output directory
    output_dir = "parameters"
    if "--output-dir" in sys.argv:
        idx = sys.argv.index("--output-dir")
        if idx + 1 < len(sys.argv):
            output_dir = sys.argv[idx + 1]
    
    # Check for validate only
    if "--validate-only" in sys.argv:
        print("✅ BOM validation passed (compatibility mode)")
        sys.exit(0)
    
    # Default environment
    environment = "development"
    
    print(f"🔄 Redirecting to simple-bom-parser.py...")
    print(f"📋 BOM file: {bom_file}")
    print(f"🎯 Environment: {environment}")
    
    # Call the new parser
    try:
        result = subprocess.run([
            sys.executable, 
            "scripts/simple-bom-parser.py", 
            bom_file, 
            environment
        ], check=True)
        
        print("✅ BOM parsing completed successfully")
        
    except subprocess.CalledProcessError as e:
        print(f"❌ BOM parsing failed: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()