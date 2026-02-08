#!/bin/bash
# Script to run the Oracle sequence fix
# This connects to the Oracle ATP database and executes the fix script

set -e

echo "=== Oracle Sequence Fix Script ==="
echo ""

# Check if required environment variables are set
if [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ] || [ -z "$TNS_ALIAS" ]; then
  echo "Required environment variables not set. Attempting to read from kubectl..."
  
  # Get credentials from the secret
  DB_USER=$(kubectl get secret -n platform flask-app-db-credentials -o jsonpath='{.data.DB_USER}' | base64 -d)
  DB_PASSWORD=$(kubectl get secret -n platform flask-app-db-credentials -o jsonpath='{.data.DB_PASSWORD}' | base64 -d)
  TNS_ALIAS="stagingdb_high"
  
  echo "Retrieved credentials from Kubernetes secret"
fi

# Check if wallet location is set
if [ -z "$WALLET_LOCATION" ]; then
  WALLET_LOCATION="/tmp/wallet"
  echo "WALLET_LOCATION not set, using default: $WALLET_LOCATION"
fi

# Download wallet if needed
if [ ! -d "$WALLET_LOCATION" ] || [ -z "$(ls -A $WALLET_LOCATION)" ]; then
  echo "Wallet not found at $WALLET_LOCATION"
  echo "You need to download the Oracle wallet first."
  echo "Run this from a pod with OCI CLI access, or download manually."
  exit 1
fi

echo ""
echo "Database User: $DB_USER"
echo "TNS Alias: $TNS_ALIAS"
echo "Wallet Location: $WALLET_LOCATION"
echo ""

# Run the SQL script using sqlplus
echo "Executing fix-oracle-sequences.sql..."
echo ""

sqlplus -S "${DB_USER}/${DB_PASSWORD}@${TNS_ALIAS}" <<EOF
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE
@$(dirname $0)/fix-oracle-sequences.sql
EXIT;
EOF

if [ $? -eq 0 ]; then
  echo ""
  echo "✓ Sequences and triggers created successfully!"
  echo ""
  echo "You can now restart the platform-backend pods to apply the fix."
  echo "Run: kubectl rollout restart deployment platform-backend -n platform"
else
  echo ""
  echo "✗ Error executing SQL script"
  exit 1
fi
