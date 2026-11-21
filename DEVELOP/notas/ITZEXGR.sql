--------------------------------------------------------------------------------
-- TABLE: ITZEXGR
-- PURPOSE:
--   Integration table for partial grades received from external LMS platforms
--   (Brightspace / Moodle) for Banner gradable components.
--
-- SCHEMA:
--   INTEGRACION
--
-- PUBLIC SYNONYM:
--   ITZEXGR
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- 1. SEQUENCE
--------------------------------------------------------------------------------

CREATE SEQUENCE INTEGRACION.ITZEXGR_SEQ
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;


--------------------------------------------------------------------------------
-- 2. TABLE
--------------------------------------------------------------------------------

CREATE TABLE INTEGRACION.ITZEXGR
(
    ITZEXGR_ID              NUMBER(19,0)       NOT NULL,
    ITZEXGR_SOURCE          VARCHAR2(2 CHAR)   NOT NULL,
    ITZEXGR_TERM_CODE       VARCHAR2(6 CHAR)   NOT NULL,
    ITZEXGR_NRC             VARCHAR2(5 CHAR)   NOT NULL,
    ITZEXGR_PIDM            NUMBER(8,0)        NOT NULL,
    ITZEXGR_GRADE_CODE      VARCHAR2(10 CHAR)  NOT NULL,
    ITZEXGR_GRADE           NUMBER(5,2),
    ITZEXGR_GRADE_DATE      DATE,
    ITZEXGR_REQUEST_DATE    DATE DEFAULT SYSDATE NOT NULL,
    ITZEXGR_RESPONSE        CLOB,
    ITZEXGR_STATUS          VARCHAR2(20 CHAR)  NOT NULL,

    CONSTRAINT PK_ITZEXGR
        PRIMARY KEY (ITZEXGR_ID),

    CONSTRAINT CK_ITZEXGR_SOURCE
        CHECK (ITZEXGR_SOURCE IN ('BS', 'MD')),

    CONSTRAINT CK_ITZEXGR_STATUS
        CHECK (
            ITZEXGR_STATUS IN (
                'INVALID',
                'PENDING',
                'PROCESSED_OK',
                'PROCESSED_KO'
            )
        ),

    CONSTRAINT CK_ITZEXGR_RESPONSE_JSON
        CHECK (ITZEXGR_RESPONSE IS JSON)
);


--------------------------------------------------------------------------------
-- 3. INDEXES
--------------------------------------------------------------------------------

CREATE INDEX INTEGRACION.IX_ITZEXGR_TERM_NRC
    ON INTEGRACION.ITZEXGR
    (
        ITZEXGR_TERM_CODE,
        ITZEXGR_NRC
    );


CREATE INDEX INTEGRACION.IX_ITZEXGR_PIDM
    ON INTEGRACION.ITZEXGR
    (
        ITZEXGR_PIDM
    );


CREATE INDEX INTEGRACION.IX_ITZEXGR_STATUS
    ON INTEGRACION.ITZEXGR
    (
        ITZEXGR_STATUS
    );


--------------------------------------------------------------------------------
-- 4. TRIGGER FOR ID
--------------------------------------------------------------------------------

CREATE OR REPLACE TRIGGER INTEGRACION.TR_ITZEXGR_BI
BEFORE INSERT ON INTEGRACION.ITZEXGR
FOR EACH ROW
WHEN (NEW.ITZEXGR_ID IS NULL)
BEGIN
    SELECT INTEGRACION.ITZEXGR_SEQ.NEXTVAL
      INTO :NEW.ITZEXGR_ID
      FROM DUAL;
END;
/


--------------------------------------------------------------------------------
-- 5. PUBLIC SYNONYM
--------------------------------------------------------------------------------

CREATE OR REPLACE PUBLIC SYNONYM ITZEXGR
    FOR INTEGRACION.ITZEXGR;


--------------------------------------------------------------------------------
-- 6. COMMENTS
--------------------------------------------------------------------------------

COMMENT ON TABLE INTEGRACION.ITZEXGR IS
    'Integration table for partial grades from external LMS platforms';

COMMENT ON COLUMN INTEGRACION.ITZEXGR.ITZEXGR_ID IS
    'Unique identifier';

COMMENT ON COLUMN INTEGRACION.ITZEXGR.ITZEXGR_SOURCE IS
    'Source LMS: BS = Brightspace, MD = Moodle';

COMMENT ON COLUMN INTEGRACION.ITZEXGR.ITZEXGR_TERM_CODE IS
    'Banner term code';

COMMENT ON COLUMN INTEGRACION.ITZEXGR.ITZEXGR_NRC IS
    'Banner course reference number';

COMMENT ON COLUMN INTEGRACION.ITZEXGR.ITZEXGR_PIDM IS
    'Banner person identifier';

COMMENT ON COLUMN INTEGRACION.ITZEXGR.ITZEXGR_GRADE_CODE IS
    'Banner gradable component code';

COMMENT ON COLUMN INTEGRACION.ITZEXGR.ITZEXGR_GRADE IS
    'Partial grade obtained by the student';

COMMENT ON COLUMN INTEGRACION.ITZEXGR.ITZEXGR_GRADE_DATE IS
    'Date when the grade was assigned by the LMS';

COMMENT ON COLUMN INTEGRACION.ITZEXGR.ITZEXGR_REQUEST_DATE IS
    'Date when the integration request was received';

COMMENT ON COLUMN INTEGRACION.ITZEXGR.ITZEXGR_RESPONSE IS
    'JSON response generated during integration processing';

COMMENT ON COLUMN INTEGRACION.ITZEXGR.ITZEXGR_STATUS IS
    'Integration processing status';
