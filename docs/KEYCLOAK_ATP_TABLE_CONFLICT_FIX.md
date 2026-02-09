# Keycloak Oracle ATP - Table Conflict Resolution Guide

## Problem
Keycloak fails to start with error:
```
ORA-00955: name is already used by an existing object
```

This happens because:
1. Keycloak tables already exist from a previous installation
2. Liquibase control tables (`DATABASECHANGELOG`, `DATABASECHANGELOGLOCK`) are missing or incomplete
3. Liquibase tries to run all migrations from scratch, attempting to recreate existing tables

## Root Cause
The configuration options `KC_SPI_CONNECTIONS_JPA_LEGACY_MIGRATION_STRATEGY` and similar don't work because:
- Modern Keycloak (25+) doesn't support manual migration mode via these env vars
- Liquibase ALWAYS attempts to validate/update the schema on startup
- There's no "skip migration" option that works reliably

## Solution Options

### **Option 1: Drop All Tables (Recommended - Fresh Start)**

This is the cleanest solution if you don't have important data in Keycloak.

**Steps:**
1. Connect to Oracle ATP as the KEYCLOAK user (use SQL Developer, SQL*Plus, or OCI Console)
2. Generate drop statements:
   ```sql
   SELECT 'DROP TABLE ' || table_name || ' CASCADE CONSTRAINTS;' 
   FROM user_tables 
   ORDER BY table_name;
   ```
3. Copy and execute all the DROP TABLE statements
4. Verify tables are gone:
   ```sql
   SELECT COUNT(*) FROM user_tables;  -- Should be 0
   ```
5. Restart Keycloak pods:
   ```bash
   kubectl delete pods -n keycloak -l app.kubernetes.io/name=keycloak
   ```

Keycloak will now create all tables fresh with proper Liquibase tracking.

---

### **Option 2: Drop Only Liquibase Control Tables**

This won't work because Keycloak will still try to create the business tables.

---

### **Option 3: Export/Import (Keep Data)**

If you have important Keycloak configuration (realms, users, clients):

1. **Export current configuration:**
   ```bash
   # Connect to a working Keycloak instance (if you have one)
   kubectl exec -n keycloak keycloak-0 -- /opt/bitnami/keycloak/bin/kc.sh export \
     --dir /tmp/export \
     --users realm_file
   
   # Copy export to local
   kubectl cp keycloak/keycloak-0:/tmp/export ./keycloak-export
   ```

2. **Drop all tables** (see Option 1)

3. **Let Keycloak recreate schema**

4. **Import configuration:**
   ```bash
   kubectl exec -n keycloak keycloak-0 -- /opt/bitnami/keycloak/bin/kc.sh import \
     --dir /tmp/import
   ```

---

### **Option 4: Quick Fix Using SQL**

Connect to ATP and run this script to drop all Keycloak tables:

```sql
-- Drop all Keycloak tables in one go
BEGIN
   FOR cur_rec IN (
     SELECT table_name 
     FROM user_tables 
     WHERE table_name IN (
       'ADMIN_EVENT_ENTITY', 'ASSOCIATED_POLICY', 'AUTHENTICATION_EXECUTION',
       'AUTHENTICATION_FLOW', 'AUTHENTICATOR_CONFIG', 'AUTHENTICATOR_CONFIG_ENTRY',
       'BROKER_LINK', 'CLIENT', 'CLIENT_ATTRIBUTES', 'CLIENT_AUTH_FLOW_BINDINGS',
       'CLIENT_INITIAL_ACCESS', 'CLIENT_NODE_REGISTRATIONS', 'CLIENT_SCOPE',
       'CLIENT_SCOPE_ATTRIBUTES', 'CLIENT_SCOPE_CLIENT', 'CLIENT_SCOPE_ROLE_MAPPING',
       'CLIENT_SESSION', 'CLIENT_SESSION_AUTH_STATUS', 'CLIENT_SESSION_NOTE',
       'CLIENT_SESSION_PROT_MAPPER', 'CLIENT_SESSION_ROLE', 'CLIENT_USER_SESSION_NOTE',
       'COMPONENT', 'COMPONENT_CONFIG', 'COMPOSITE_ROLE', 'CREDENTIAL',
       'DATABASECHANGELOG', 'DATABASECHANGELOGLOCK', 'DEFAULT_CLIENT_SCOPE',
       'EVENT_ENTITY', 'FED_USER_ATTRIBUTE', 'FED_USER_CONSENT',
       'FED_USER_CONSENT_CL_SCOPE', 'FED_USER_CREDENTIAL', 'FED_USER_GROUP_MEMBERSHIP',
       'FED_USER_REQUIRED_ACTION', 'FED_USER_ROLE_MAPPING', 'FEDERATED_IDENTITY',
       'FEDERATED_USER', 'GROUP_ATTRIBUTE', 'GROUP_ROLE_MAPPING', 'IDENTITY_PROVIDER',
       'IDENTITY_PROVIDER_CONFIG', 'IDENTITY_PROVIDER_MAPPER', 'IDP_MAPPER_CONFIG',
       'KEYCLOAK_GROUP', 'KEYCLOAK_ROLE', 'MIGRATION_MODEL', 'OFFLINE_CLIENT_SESSION',
       'OFFLINE_USER_SESSION', 'POLICY_CONFIG', 'PROTOCOL_MAPPER',
       'PROTOCOL_MAPPER_CONFIG', 'REALM', 'REALM_ATTRIBUTE', 'REALM_DEFAULT_GROUPS',
       'REALM_DEFAULT_ROLES', 'REALM_ENABLED_EVENT_TYPES', 'REALM_EVENTS_LISTENERS',
       'REALM_LOCALIZATIONS', 'REALM_REQUIRED_CREDENTIAL', 'REALM_SMTP_CONFIG',
       'REALM_SUPPORTED_LOCALES', 'REDIRECT_URIS', 'REQUIRED_ACTION_CONFIG',
       'REQUIRED_ACTION_PROVIDER', 'RESOURCE_ATTRIBUTE', 'RESOURCE_POLICY',
       'RESOURCE_SCOPE', 'RESOURCE_SERVER', 'RESOURCE_SERVER_PERM_TICKET',
       'RESOURCE_SERVER_POLICY', 'RESOURCE_SERVER_RESOURCE', 'RESOURCE_SERVER_SCOPE',
       'RESOURCE_URIS', 'ROLE_ATTRIBUTE', 'SCOPE_MAPPING', 'SCOPE_POLICY',
       'USER_ATTRIBUTE', 'USER_CONSENT', 'USER_CONSENT_CLIENT_SCOPE', 'USER_ENTITY',
       'USER_FEDERATION_CONFIG', 'USER_FEDERATION_MAPPER', 'USER_FEDERATION_MAPPER_CONFIG',
       'USER_FEDERATION_PROVIDER', 'USER_GROUP_MEMBERSHIP', 'USER_REQUIRED_ACTION',
       'USER_ROLE_MAPPING', 'USER_SESSION', 'USER_SESSION_NOTE', 'USERNAME_LOGIN_FAILURE',
       'WEB_ORIGINS'
     )
   )
   LOOP
      BEGIN
         EXECUTE IMMEDIATE 'DROP TABLE ' || cur_rec.table_name || ' CASCADE CONSTRAINTS PURGE';
         DBMS_OUTPUT.PUT_LINE('Dropped: ' || cur_rec.table_name);
      EXCEPTION
         WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Failed to drop: ' || cur_rec.table_name || ' - ' || SQLERRM);
      END;
   END LOOP;
END;
/

-- Verify
SELECT COUNT(*) as remaining_tables FROM user_tables;
```

---

## Recommended Action

**Use Option 1** - Drop all tables and let Keycloak recreate them.

### Quick Commands:

```bash
# 1. Generate DROP statements
kubectl exec -n keycloak jdbc-test -- bash -c '
KC_USER=$(cat /db-creds/username)
KC_PASS=$(cat /db-creds/password)
java -cp "/jars/*" JdbcQuery "jdbc:oracle:thin:@stagingdb_high?TNS_ADMIN=/wallet" "$KC_USER" "$KC_PASS" "SELECT '\''DROP TABLE '\'' || table_name || '\'' CASCADE CONSTRAINTS;'\'' FROM user_tables"
'

# 2. Connect to ATP and execute the DROP statements

# 3. Restart Keycloak
kubectl delete pods -n keycloak -l app.kubernetes.io/name=keycloak
```

---

## Prevention

Once fixed, Keycloak will maintain proper Liquibase state. To prevent this in future:
- Never manually drop/create Keycloak tables
- Always let Keycloak manage its own schema
- If you need to reset, drop ALL tables, not just some

---

## Alternative: Use PostgreSQL Protocol

If these issues persist with Oracle native driver, consider using ATP's PostgreSQL-compatible endpoint instead (simpler, better Keycloak support).
