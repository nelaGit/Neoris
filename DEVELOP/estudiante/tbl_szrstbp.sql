
CREATE TABLE integracion.szrstbp (
    SZRSTBP_PIDM           NUMBER(8,0) NOT NULL,
	SZRSTBP_TERM_CODE	   VARCHAR2(6),
    SZRSTBP_LINE_NEG       VARCHAR2(2),
    SZRSTBP_ROL_ID         NUMBER(5),
	SZRSTBP_USER_ID_BS     VARCHAR2(10 CHAR),
    SZRSTBP_STATE          VARCHAR2(10),
    SZRSTBP_STATE_DET VARCHAR2(200 BYTE),
	SZRSTBP_OPERACION	   VARCHAR2(1),
	SZRSTBP_ID_MAESTRO	   NUMBER(19,0),
    SZRSTBP_SURROGATE_ID   NUMBER(19,0),
    SZRSTBP_VERSION        NUMBER(19,0),
    SZRSTBP_DATA_ORIGIN   VARCHAR2(30 CHAR),
    SZRSTBP_USER_ID        VARCHAR2(30 CHAR),
    SZRSTBP_ACTIVITY_DATE  DATE
);

 ALTER TABLE INTEGRACION.ITZBGSP ADD( PIDM	NUMBER(8,0), ID_SPRIDEN	VARCHAR2(9 CHAR))

COMMENT ON TABLE integracion.szrstbp IS 'INTEGRACION ESTUDIANTES sistema Brightspace';
COMMENT ON COLUMN integracion.szrstbp.szrstbp_PIDM IS 'PIDIM estudiante';
COMMENT ON COLUMN integracion.szrstbp.szrstbp_TERM_CODE IS 'PERIODO DEL DOCENTE';
COMMENT ON COLUMN integracion.szrstbp.szrstbp_LINE_NEG IS 'LINEA DE NEGOCIO (ON Online) ';
COMMENT ON COLUMN integracion.szrstbp.SZRSTBP_ROL_ID IS 'ROL ESTUDIANTE. VALOR 110';
COMMENT ON COLUMN integracion.szrstbp.szrstbp_STATE IS 'ESTADO DEL REGISTRO (NEW -> BANNER)/(SEND -> TABLA INTEGRACION/ FAIL -> .NET/TABLA INT) ';
COMMENT ON COLUMN integracion.szrstbp.szrstbp_OPERACION IS 'OPERACION EFECTUADA EN EL REGISTRO ((I)nsert, (U)pdate, (D)elete) ';
COMMENT ON COLUMN integracion.szrstbp.szrstbp_ID_MAESTRO IS 'Identificador único de la tabla de integracion ITZBGSP.id ';
COMMENT ON COLUMN integracion.szrstbp.szrstbp_SURROGATE_ID IS 'Identificador único para cada registro ';
COMMENT ON COLUMN integracion.szrstbp.szrstbp_VERSION IS 'Versión del registro ';
COMMENT ON COLUMN integracion.szrstbp.szrstbp_DATA_ORIGIN IS ' Origen de datos';
COMMENT ON COLUMN integracion.szrstbp.szrstbp_USER_ID IS ' Usuario última modificación';
COMMENT ON COLUMN integracion.szrstbp.szrstbp_ACTIVITY_DATE IS 'Fecha de creación o actualización ';


CREATE SEQUENCE integracion.SEQ_szrstbp
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;

-- ============================================
-- TRIGGER PARA SURROGATE_ID
-- ============================================

CREATE OR REPLACE TRIGGER integracion.TRG_szrstbp_BI
BEFORE INSERT ON integracion.szrstbp
FOR EACH ROW
BEGIN
    IF :NEW.szrstbp_SURROGATE_ID IS NULL THEN
        SELECT integracion.SEQ_szrstbp.NEXTVAL
        INTO :NEW.szrstbp_SURROGATE_ID
        FROM DUAL;
    END IF;

    :NEW.szrstbp_ACTIVITY_DATE := SYSDATE;
END;
/

GRANT SELECT, UPDATE, DELETE ON integracion.szrstbp TO PUBLIC;


CREATE PUBLIC SYNONYM szrstbp FOR integracion.szrstbp;