-- ==========================================================
-- TABLA: INTEGRACION.SZREDBP
-- DESCRIPCIÓN: Tabla intermedia de ENROLLMENT DOCENTE
-- Integración Brightspace
-- ==========================================================

CREATE TABLE integracion.SZREDBP (
    SZREDBP_TERM_CODE       VARCHAR2(6 CHAR),
    SZREDBP_CRN             VARCHAR2(5 CHAR),
    SZREDBP_PIDM            NUMBER(8,0),
    SZREDBP_CATEGORY        VARCHAR2(2 CHAR),
    SZREDBP_LINE_NEG        VARCHAR2(2 BYTE),
    SZREDBP_STATE           VARCHAR2(10 BYTE),
    SZREDBP_OPERACION       VARCHAR2(1 BYTE),
    SZREDBP_SURROGATE_ID    NUMBER(19,0) NOT NULL,
    SZREDBP_VERSION         NUMBER(19,0) DEFAULT 0,
    SZREDBP_DATA_ORIGIN     VARCHAR2(30 CHAR),
    SZREDBP_USER_ID         VARCHAR2(30 CHAR),
    SZREDBP_STATE_DET       VARCHAR2(200 BYTE),
	SZREDBP_ROLE_ID         VARCHAR2(10 CHAR),
    SZREDBP_ADDIC_ID	    VARCHAR2(10 CHAR),
    SZREDBP_NRC_ID          VARCHAR2(10 CHAR),
    SZREDBP_ID_MAESTRO      NUMBER(19,0),
    SZREDBP_ACTIVITY_DATE   DATE
);


CREATE SEQUENCE integracion.SEQ_SZREDBP
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

GRANT SELECT, INSERT, UPDATE, DELETE ON integracion.SZREDBP TO PUBLIC;



CREATE PUBLIC SYNONYM SZREDBP FOR integracion.SZREDBP;


	
	COMMENT ON TABLE integracion.SZREDBP IS
'Tabla intermedia de ENROLLMENT DOCENTE - Integración Brightspace';

COMMENT ON COLUMN integracion.SZREDBP.SZREDBP_TERM_CODE IS 'Periodo del docente';

COMMENT ON COLUMN integracion.SZREDBP.SZREDBP_CRN IS 'CRN del curso';

COMMENT ON COLUMN integracion.SZREDBP.SZREDBP_PIDM IS 'PIDM del docente';

COMMENT ON COLUMN integracion.SZREDBP.SZREDBP_CATEGORY IS 'Categoría del docente';

COMMENT ON COLUMN integracion.SZREDBP.SZREDBP_LINE_NEG IS 'Línea de negocio (00 Online, 01 Flex, 03 CyP)';

COMMENT ON COLUMN integracion.SZREDBP.SZREDBP_STATE IS 'Estado del registro (NEW -> Banner, SEND -> Tabla Integración, FAIL -> Error integración)';

COMMENT ON COLUMN integracion.SZREDBP.SZREDBP_OPERACION IS 'Operación efectuada en el registro (I=Insert, U=Update, D=Delete)';

COMMENT ON COLUMN integracion.SZREDBP.SZREDBP_SURROGATE_ID IS 'Identificador único del registro';

COMMENT ON COLUMN integracion.SZREDBP.SZREDBP_VERSION IS 'Versión del registro';

COMMENT ON COLUMN integracion.SZREDBP.SZREDBP_DATA_ORIGIN IS 'Origen de los datos';

COMMENT ON COLUMN integracion.SZREDBP.SZREDBP_USER_ID IS 'Usuario de la última modificación';

COMMENT ON COLUMN integracion.SZREDBP.SZREDBP_STATE_DET IS 'Detalle del estado o descripción del error';

COMMENT ON COLUMN integracion.SZREDBP.SZREDBP_ID_MAESTRO IS 'Identificador del registro maestro en la tabla de integración';

COMMENT ON COLUMN integracion.SZREDBP.SZREDBP_ACTIVITY_DATE IS 'Fecha de creación o última actualización del registro';