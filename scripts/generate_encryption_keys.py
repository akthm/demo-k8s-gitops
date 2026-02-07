#!/usr/bin/env python3
"""
Generate Database Encryption Keys for OCI Vault

This script generates the required encryption key fields for the flask-app
OCI Vault secret to enable database encryption.

Usage:
    python3 generate_encryption_keys.py

Output:
    JSON snippet to add to your OCI Vault secret 'flask-app'
"""

import json
from cryptography.fernet import Fernet
from datetime import datetime

def generate_encryption_keys():
    """Generate encryption key fields for OCI Vault"""
    
    # Generate a Fernet key
    encryption_key = Fernet.generate_key().decode('utf-8')
    
    # Create the encryption keys configuration
    encryption_config = {
        "DATABASE_ENCRYPTION_KEY_V1": encryption_key,
        "CURRENT_KEY_VERSION": "v1",
        "ROTATION_DATE": "",
        "MIGRATION_STATUS": "none"
    }
    
    return encryption_config

def main():
    print("=" * 80)
    print("Database Encryption Keys Generator")
    print("=" * 80)
    print()
    
    # Generate keys
    config = generate_encryption_keys()
    
    # Display in pretty format
    print("Add these fields to your OCI Vault secret 'flask-app':")
    print()
    print(json.dumps(config, indent=2))
    print()
    
    # Display individual values for easy copying
    print("=" * 80)
    print("Individual Values (for manual entry):")
    print("=" * 80)
    for key, value in config.items():
        print(f"\n{key}:")
        print(f"  {value}")
    
    print()
    print("=" * 80)
    print("Next Steps:")
    print("=" * 80)
    print("1. Copy the JSON above")
    print("2. Open OCI Console: Identity & Security → Vault")
    print("3. Select your vault and the 'flask-app' secret")
    print("4. Click 'Create Secret Version'")
    print("5. Merge these fields with your existing secret content")
    print("6. Save the new version")
    print()
    print("⚠️  IMPORTANT: Keep this key secure!")
    print("   Without it, encrypted data cannot be decrypted.")
    print("=" * 80)

if __name__ == "__main__":
    try:
        main()
    except ImportError as e:
        print("Error: cryptography package not installed")
        print()
        print("Install it with:")
        print("  pip install cryptography")
        print()
        print("Or generate a key manually with:")
        print("  python3 -c \"from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())\"")
