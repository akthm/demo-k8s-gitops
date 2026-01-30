#!/bin/bash
# ============================================================================
# Fix Keycloak Liquibase State - Mark all migrations as complete
# ============================================================================
# This script connects to Oracle ATP and marks all Keycloak Liquibase
# changesets as already deployed, preventing re-execution
# ============================================================================

set -e

echo "Fixing Keycloak Liquibase changelog state..."

# Get database credentials from Kubernetes secrets
KC_USER=$(kubectl get secret keycloak-postgres-credentials -n keycloak -o jsonpath='{.data.username}' | base64 -d)
KC_PASS=$(kubectl get secret keycloak-postgres-credentials -n keycloak -o jsonpath='{.data.password}' | base64 -d)
KC_JDBC_URL=$(kubectl get secret keycloak-postgres-credentials -n keycloak -o jsonpath='{.data.jdbc-url}' | base64 -d)

echo "Database user: $KC_USER"
echo "JDBC URL: $KC_JDBC_URL"

# Create SQL script to mark changelogs as complete
cat > /tmp/fix-liquibase.sql << 'EOF'
-- Check if DATABASECHANGELOG table exists
SELECT COUNT(*) FROM user_tables WHERE table_name = 'DATABASECHANGELOG';

-- If it doesn't exist, Keycloak will create it on first run
-- If it does exist but is empty or incomplete, we have two options:

-- Option A: Drop the control tables so Keycloak recreates them
DROP TABLE DATABASECHANGELOG PURGE;
DROP TABLE DATABASECHANGELOGLOCK PURGE;

-- Then Keycloak will fail again with ORA-00955
-- So we need to drop the actual tables too (see fix-keycloak-db.sql)

-- Option B: Manual insert of all changesets (complex, not recommended)
EOF

cat << 'EOF'

=================================================================
DATABASE FIX REQUIRED
=================================================================

The Keycloak database has existing tables but Liquibase doesn't 
know they exist. You need to run ONE of these commands in Oracle ATP:

OPTION 1 (Recommended - Fresh Start):
--------------------------------------
Connect to ATP as KEYCLOAK user and run:

  SELECT 'DROP TABLE ' || table_name || ' CASCADE CONSTRAINTS;' 
  FROM user_tables;

Copy the output and execute all DROP statements, then restart Keycloak.

OPTION 2 (Keep Data - Advanced):
---------------------------------
1. Export your Keycloak configuration (realms, users, clients)
2. Drop all tables (Option 1)
3. Let Keycloak recreate the schema
4. Import your configuration

OPTION 3 (Quick Fix - Drop Control Tables):
--------------------------------------------
Connect to ATP and run:

  DROP TABLE DATABASECHANGELOG CASCADE CONSTRAINTS;
  DROP TABLE DATABASECHANGELOGLOCK CASCADE CONSTRAINTS;
  
Then drop ALL other Keycloak tables and restart.

=================================================================

Would you like to proceed with Option 1 (drop all tables)?
EOF

read -p "Enter 'yes' to generate drop scripts: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

# Connect via jdbc-test pod
kubectl exec -n keycloak jdbc-test -- sqlplus -s "$KC_USER/$KC_PASS@stagingdb_high" << 'EOSQL'
SET PAGESIZE 0
SET FEEDBACK OFF
SET HEADING OFF
SELECT 'DROP TABLE ' || table_name || ' CASCADE CONSTRAINTS;' 
FROM user_tables 
WHERE table_name NOT LIKE 'SYS_%' 
  AND table_name NOT LIKE 'MLOG$_%'
ORDER BY table_name;
EOSQL

echo ""
echo "Copy the DROP TABLE statements above and execute them in Oracle ATP"
echo "Then delete the Keycloak pods to restart: kubectl delete pods -n keycloak -l app.kubernetes.io/name=keycloak"
