-- ============================================================================
-- Fix Keycloak Oracle ATP Database - Drop existing tables
-- ============================================================================
-- This script drops all Keycloak tables to allow a fresh installation
-- WARNING: This will delete ALL Keycloak data!
-- ============================================================================

-- Run this as the KEYCLOAK user in Oracle ATP

-- Drop all Keycloak tables (adjust list based on what exists in your schema)
BEGIN
   FOR cur_rec IN (SELECT table_name FROM user_tables WHERE table_name LIKE '%EVENT%' OR table_name LIKE '%USER%' OR table_name LIKE 'CLIENT%' OR table_name LIKE 'REALM%' OR table_name LIKE 'ROLE%' OR table_name LIKE '%CREDENTIAL%' OR table_name LIKE 'FED%' OR table_name LIKE 'IDENTITY%' OR table_name LIKE 'MIGRATION%' OR table_name LIKE 'AUTHENTICAT%' OR table_name LIKE 'DATABASECHANGE%' OR table_name LIKE 'RESOURCE%' OR table_name LIKE 'POLICY%' OR table_name LIKE 'SCOPE%' OR table_name LIKE 'GROUP%' OR table_name LIKE 'COMPONENT%' OR table_name LIKE 'KEYCLOAK%' OR table_name LIKE 'PROTOCOL%' OR table_name LIKE 'WEB_%' OR table_name LIKE 'REDIRECT%' OR table_name LIKE 'USERNAME_%' OR table_name LIKE 'DEFAULT_%' OR table_name LIKE 'BROKER_%' OR table_name LIKE 'OFFLINE_%')
   LOOP
      EXECUTE IMMEDIATE 'DROP TABLE ' || cur_rec.table_name || ' CASCADE CONSTRAINTS';
   END LOOP;
END;
/

-- Verify all tables are dropped
SELECT COUNT(*) as remaining_tables FROM user_tables;

-- Expected output: 0 remaining_tables
