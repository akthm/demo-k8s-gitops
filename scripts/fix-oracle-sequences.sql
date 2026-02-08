-- Fix Oracle Sequences and Triggers for Auto-Incrementing IDs
-- This script creates sequences and triggers for tables created by SQLAlchemy's db.create_all()
-- which doesn't automatically set up Oracle sequences/triggers

-- ============================================================================
-- 1. USERS TABLE
-- ============================================================================
CREATE SEQUENCE users_seq START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TRIGGER users_id_trigger
BEFORE INSERT ON users
FOR EACH ROW
WHEN (new.id IS NULL)
BEGIN
  :new.id := users_seq.NEXTVAL;
END;
/

-- ============================================================================
-- 2. PATIENTS TABLE
-- ============================================================================
CREATE SEQUENCE patients_seq START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TRIGGER patients_id_trigger
BEFORE INSERT ON patients
FOR EACH ROW
WHEN (new.id IS NULL)
BEGIN
  :new.id := patients_seq.NEXTVAL;
END;
/

-- ============================================================================
-- 3. APPOINTMENTS TABLE
-- ============================================================================
CREATE SEQUENCE appointments_seq START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TRIGGER appointments_id_trigger
BEFORE INSERT ON appointments
FOR EACH ROW
WHEN (new.id IS NULL)
BEGIN
  :new.id := appointments_seq.NEXTVAL;
END;
/

-- ============================================================================
-- 4. MESSAGES TABLE
-- ============================================================================
CREATE SEQUENCE messages_seq START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TRIGGER messages_id_trigger
BEFORE INSERT ON messages
FOR EACH ROW
WHEN (new.id IS NULL)
BEGIN
  :new.id := messages_seq.NEXTVAL;
END;
/

-- ============================================================================
-- 5. REFRESH_TOKENS TABLE
-- ============================================================================
CREATE SEQUENCE refresh_tokens_seq START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TRIGGER refresh_tokens_id_trigger
BEFORE INSERT ON refresh_tokens
FOR EACH ROW
WHEN (new.id IS NULL)
BEGIN
  :new.id := refresh_tokens_seq.NEXTVAL;
END;
/

-- ============================================================================
-- 6. SYSTEM_SETTINGS TABLE
-- ============================================================================
CREATE SEQUENCE system_settings_seq START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TRIGGER system_settings_id_trigger
BEFORE INSERT ON system_settings
FOR EACH ROW
WHEN (new.id IS NULL)
BEGIN
  :new.id := system_settings_seq.NEXTVAL;
END;
/

-- ============================================================================
-- Update sequences to start from current max IDs (if data exists)
-- ============================================================================

DECLARE
  v_max_id NUMBER;
BEGIN
  -- Users
  SELECT NVL(MAX(id), 0) INTO v_max_id FROM users;
  IF v_max_id > 0 THEN
    EXECUTE IMMEDIATE 'DROP SEQUENCE users_seq';
    EXECUTE IMMEDIATE 'CREATE SEQUENCE users_seq START WITH ' || (v_max_id + 1) || ' INCREMENT BY 1';
  END IF;
  
  -- Patients
  SELECT NVL(MAX(id), 0) INTO v_max_id FROM patients;
  IF v_max_id > 0 THEN
    EXECUTE IMMEDIATE 'DROP SEQUENCE patients_seq';
    EXECUTE IMMEDIATE 'CREATE SEQUENCE patients_seq START WITH ' || (v_max_id + 1) || ' INCREMENT BY 1';
  END IF;
  
  -- Appointments
  SELECT NVL(MAX(id), 0) INTO v_max_id FROM appointments;
  IF v_max_id > 0 THEN
    EXECUTE IMMEDIATE 'DROP SEQUENCE appointments_seq';
    EXECUTE IMMEDIATE 'CREATE SEQUENCE appointments_seq START WITH ' || (v_max_id + 1) || ' INCREMENT BY 1';
  END IF;
  
  -- Messages
  SELECT NVL(MAX(id), 0) INTO v_max_id FROM messages;
  IF v_max_id > 0 THEN
    EXECUTE IMMEDIATE 'DROP SEQUENCE messages_seq';
    EXECUTE IMMEDIATE 'CREATE SEQUENCE messages_seq START WITH ' || (v_max_id + 1) || ' INCREMENT BY 1';
  END IF;
  
  -- Refresh Tokens
  SELECT NVL(MAX(id), 0) INTO v_max_id FROM refresh_tokens;
  IF v_max_id > 0 THEN
    EXECUTE IMMEDIATE 'DROP SEQUENCE refresh_tokens_seq';
    EXECUTE IMMEDIATE 'CREATE SEQUENCE refresh_tokens_seq START WITH ' || (v_max_id + 1) || ' INCREMENT BY 1';
  END IF;
  
  -- System Settings
  SELECT NVL(MAX(id), 0) INTO v_max_id FROM system_settings;
  IF v_max_id > 0 THEN
    EXECUTE IMMEDIATE 'DROP SEQUENCE system_settings_seq';
    EXECUTE IMMEDIATE 'CREATE SEQUENCE system_settings_seq START WITH ' || (v_max_id + 1) || ' INCREMENT BY 1';
  END IF;
END;
/

-- Verify sequences are created
SELECT sequence_name, last_number FROM user_sequences 
WHERE sequence_name IN ('USERS_SEQ', 'PATIENTS_SEQ', 'APPOINTMENTS_SEQ', 
                        'MESSAGES_SEQ', 'REFRESH_TOKENS_SEQ', 'SYSTEM_SETTINGS_SEQ')
ORDER BY sequence_name;
