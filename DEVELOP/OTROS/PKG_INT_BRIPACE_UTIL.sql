create or replace PACKAGE                                  PKG_INT_BRIPACE_UTIL AS

    ----------------------------------------------------------------------
    -- LOG DE INTEGRACIÓN
    ----------------------------------------------------------------------
    PROCEDURE p_registra_error_log (
        p_business_line    IN SZRLGBP.SZRLGBP_BUSINESS_LINE%TYPE,
        p_op_type          IN SZRLGBP.SZRLGBP_OP_TYPE%TYPE,
        p_term_code        IN SZRLGBP.SZRLGBP_TERM_CODE%TYPE,
        p_ptrm_code        IN SZRLGBP.SZRLGBP_PTRM_CODE%TYPE DEFAULT NULL,
        p_crn              IN SZRLGBP.SZRLGBP_CRN%TYPE DEFAULT NULL,
        p_pidm              IN SZRLGBP.SZRLGBP_PIDM%TYPE DEFAULT NULL,
        p_error_code       IN SZRLGBP.SZRLGBP_ERROR_CODE%TYPE,
        p_error_message    IN SZRLGBP.SZRLGBP_ERROR_MESSAGE%TYPE,
        p_id_maestro       IN SZRLGBP.SZRLGBP_ID_MAESTRO%TYPE DEFAULT NULL,
        p_state            IN SZRLGBP.SZRLGBP_STATE%TYPE DEFAULT 'ERROR',
        p_user_id          IN SZRLGBP.SZRLGBP_USER_ID%TYPE DEFAULT USER,
        p_data_origin      IN SZRLGBP.SZRLGBP_DATA_ORIGIN%TYPE DEFAULT NULL
    );

   ----------------------------------------------------------------------
    -- LOG DE INTEGRACIÓN unico para que no repita el mismo error. Log controlado
    ----------------------------------------------------------------------
  PROCEDURE p_registra_error_log_uk (
        p_business_line    IN SZRLGBP.SZRLGBP_BUSINESS_LINE%TYPE,
        p_op_type          IN SZRLGBP.SZRLGBP_OP_TYPE%TYPE,
        p_term_code        IN SZRLGBP.SZRLGBP_TERM_CODE%TYPE,
        p_ptrm_code       IN SZRLGBP.SZRLGBP_PTRM_CODE%TYPE DEFAULT NULL,
        p_crn              IN SZRLGBP.SZRLGBP_CRN%TYPE DEFAULT NULL,
        p_pidm             IN SZRLGBP.SZRLGBP_PIDM%TYPE DEFAULT NULL,
        p_error_code       IN  SZRLGBP.SZRLGBP_ERROR_CODE%TYPE,
        p_error_message    IN  SZRLGBP.SZRLGBP_ERROR_MESSAGE%TYPE,
        p_id_maestro       IN SZRLGBP.SZRLGBP_ID_MAESTRO%TYPE DEFAULT NULL,
        p_state            IN SZRLGBP.SZRLGBP_STATE%TYPE DEFAULT 'ERROR',
        p_user_id          IN SZRLGBP.SZRLGBP_USER_ID%TYPE DEFAULT USER,
        p_data_origin      IN SZRLGBP.SZRLGBP_DATA_ORIGIN%TYPE DEFAULT NULL
    );

    ----------------------------------------------------------------------
    -- TABLA INTERMEDIA: SZRTMBP - PERIODOS
    ----------------------------------------------------------------------
    PROCEDURE p_intermedia_szrtmbp (
        p_registro       IN SZRTMBP%ROWTYPE,
        p_business_line  IN SZRLGBP.SZRLGBP_BUSINESS_LINE%TYPE,
        p_op_type        IN SZRLGBP.SZRLGBP_OP_TYPE%TYPE
    );


    ----------------------------------------------------------------------
    -- TABLA INTERMEDIA: SZRSSBP - NRC
    ----------------------------------------------------------------------
    PROCEDURE p_intermedia_szrssbp (
        p_registro       IN SZRSSBP%ROWTYPE,
        p_business_line  IN SZRLGBP.SZRLGBP_BUSINESS_LINE%TYPE,
        p_op_type        IN SZRLGBP.SZRLGBP_OP_TYPE%TYPE
    );


    ----------------------------------------------------------------------
    -- TABLA INTERMEDIA: SZRPEBP - PERSONAS
    ----------------------------------------------------------------------
    PROCEDURE p_intermedia_szrpebp (
        p_registro       IN SZRPEBP%ROWTYPE,
        p_business_line  IN SZRLGBP.SZRLGBP_BUSINESS_LINE%TYPE,
        p_op_type        IN SZRLGBP.SZRLGBP_OP_TYPE%TYPE
    );
    

    ----------------------------------------------------------------------
    -- TABLA INTERMEDIA: SZREDBP - ENROLLMENT
    ----------------------------------------------------------------------
    PROCEDURE p_intermedia_szredbp (
        p_registro       IN SZREDBP%ROWTYPE,
        p_business_line  IN SZRLGBP.SZRLGBP_BUSINESS_LINE%TYPE,
        p_op_type        IN SZRLGBP.SZRLGBP_OP_TYPE%TYPE
    );
    
        -- procedimiento que genra el JSON e inserta en la tabla de integracion general itzbgsp
 PROCEDURE p_genera_inserta_itzbgsp (
    p_business_line IN INTEGRACION.ITZBGSP.BUSINESS_LINE%TYPE,
    p_op_type       IN INTEGRACION.ITZBGSP.OP_TYPE%TYPE,
    p_endpoint      IN VARCHAR2,
    p_method        IN VARCHAR2,
    p_body          IN CLOB,
    p_id_generado   OUT INTEGRACION.ITZBGSP.ID%TYPE,
    p_pidm            IN NUMBER DEFAULT NULL,
    p_id_spriden      IN NUMBER DEFAULT NULL
);
    
TYPE t_itzbgsp_rec IS RECORD (
      request_id   NUMBER,
      endpoint     VARCHAR2(4000),
      method       VARCHAR2(20),
      body         CLOB
   );

   TYPE t_itzbgsp_tab IS TABLE OF t_itzbgsp_rec
      INDEX BY PLS_INTEGER;


   -- Nuevo proc de generacion de JSON compuesto con insert a la tabla de integración
   PROCEDURE p_genera_inserta_itzbgsp_multi (
      p_business_line   IN INTEGRACION.ITZBGSP.BUSINESS_LINE%TYPE,
      p_op_type         IN INTEGRACION.ITZBGSP.OP_TYPE%TYPE,
      p_registros       IN t_itzbgsp_tab,
      p_id_generado   OUT INTEGRACION.ITZBGSP.ID%TYPE,
      p_pidm            IN NUMBER DEFAULT NULL,
      p_id_spriden      IN NUMBER DEFAULT NULL
   );
   
   PROCEDURE P_PROCESA_RESPONSE;
   
   PROCEDURE P_PROCESA_RESPONSE_ALU;
   
   PROCEDURE P_ACTUALIZA_ESTADO_ITZBGSP (
    P_ID_MAESTRO      IN INTEGRACION.ITZBGSP.ID%TYPE,
    P_OP_TYPE         IN INTEGRACION.ITZBGSP.OP_TYPE%TYPE,
    P_STATUS_RESPONSE IN INTEGRACION.ITZBGSP.STATUS_RESPONSE%TYPE
);

PROCEDURE P_ACTUALIZA_ESTADO_ITZERST (
    P_ID              IN INTEGRACION.ITZERST.ID%TYPE,
    P_OP_TYPE         IN INTEGRACION.ITZERST.OP_TYPE%TYPE,
    P_STATUS_RESPONSE IN INTEGRACION.ITZERST.STATUS_RESPONSE%TYPE
);

PROCEDURE P_ACTUALIZA_INTERMEDIA_STATE (
    P_TIPO        IN VARCHAR2,
    P_ID_MAESTRO  IN NUMBER,
    P_STATE_OLD   IN VARCHAR2,
    P_STATE       IN VARCHAR2,
    P_MENSAJE     IN VARCHAR2 DEFAULT NULL
);

PROCEDURE p_obtener_config_api (
        p_operacion IN  VARCHAR2,
        p_url       OUT VARCHAR2,
        p_method    OUT VARCHAR2,
        p_path      OUT VARCHAR2
    );

END PKG_INT_BRIPACE_UTIL;

create or replace PACKAGE BODY                         PKG_INT_BRIPACE_UTIL AS


    ----------------------------------------------------------------------
    -- LOG DE INTEGRACIÓN
    --
    -- Este procedimiento es AUTÓNOMO para garantizar que el log
    -- permanezca aunque la transacción que originó el error haga ROLLBACK.
    --
    -- También se utiliza para registrar operaciones exitosas.
    ----------------------------------------------------------------------
    PROCEDURE p_registra_error_log (
        p_business_line    IN SZRLGBP.SZRLGBP_BUSINESS_LINE%TYPE,
        p_op_type          IN SZRLGBP.SZRLGBP_OP_TYPE%TYPE,
        p_term_code        IN SZRLGBP.SZRLGBP_TERM_CODE%TYPE,
        p_ptrm_code        IN SZRLGBP.SZRLGBP_PTRM_CODE%TYPE DEFAULT NULL,
        p_crn              IN SZRLGBP.SZRLGBP_CRN%TYPE DEFAULT NULL,
        p_pidm             IN SZRLGBP.SZRLGBP_PIDM%TYPE DEFAULT NULL,
        p_error_code       IN SZRLGBP.SZRLGBP_ERROR_CODE%TYPE,
        p_error_message    IN SZRLGBP.SZRLGBP_ERROR_MESSAGE%TYPE,
        p_id_maestro       IN SZRLGBP.SZRLGBP_ID_MAESTRO%TYPE DEFAULT NULL,
        p_state            IN SZRLGBP.SZRLGBP_STATE%TYPE DEFAULT 'ERROR',
        p_user_id          IN SZRLGBP.SZRLGBP_USER_ID%TYPE DEFAULT USER,
        p_data_origin      IN SZRLGBP.SZRLGBP_DATA_ORIGIN%TYPE DEFAULT NULL
    )
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;

    BEGIN

        INSERT INTO SZRLGBP (
            SZRLGBP_ID,
            SZRLGBP_BUSINESS_LINE,
            SZRLGBP_OP_TYPE,
            SZRLGBP_TERM_CODE,
            SZRLGBP_PTRM_CODE,
            SZRLGBP_CRN,
            SZRLGBP_PIDM,
            SZRLGBP_ERROR_CODE,
            SZRLGBP_ERROR_MESSAGE,
            SZRLGBP_ID_MAESTRO,
            SZRLGBP_STATE,
            SZRLGBP_USER_ID,
            SZRLGBP_ACTIVITY_DATE,
            SZRLGBP_DATA_ORIGIN
        )
        VALUES (
            SEQ_SZRLGBP.NEXTVAL,
            p_business_line,
            p_op_type,
            p_term_code,
            p_ptrm_code,
            p_crn,
            p_pidm,
            p_error_code,
            p_error_message,
            p_id_maestro,
            p_state,
            p_user_id,
            SYSDATE,
            p_data_origin
        );

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;

            -- El error del LOG no debe afectar al proceso principal.
            NULL;

    END p_registra_error_log;

  PROCEDURE p_registra_error_log_uk (
        p_business_line    IN SZRLGBP.SZRLGBP_BUSINESS_LINE%TYPE,
        p_op_type          IN SZRLGBP.SZRLGBP_OP_TYPE%TYPE,
        p_term_code        IN SZRLGBP.SZRLGBP_TERM_CODE%TYPE,
        p_ptrm_code        IN SZRLGBP.SZRLGBP_PTRM_CODE%TYPE DEFAULT NULL,
        p_crn              IN SZRLGBP.SZRLGBP_CRN%TYPE DEFAULT NULL,
        p_pidm             IN SZRLGBP.SZRLGBP_PIDM%TYPE DEFAULT NULL,
        p_error_code       IN SZRLGBP.SZRLGBP_ERROR_CODE%TYPE,
        p_error_message    IN SZRLGBP.SZRLGBP_ERROR_MESSAGE%TYPE,
        p_id_maestro       IN SZRLGBP.SZRLGBP_ID_MAESTRO%TYPE DEFAULT NULL,
        p_state            IN SZRLGBP.SZRLGBP_STATE%TYPE DEFAULT 'ERROR',
        p_user_id          IN SZRLGBP.SZRLGBP_USER_ID%TYPE DEFAULT USER,
        p_data_origin      IN SZRLGBP.SZRLGBP_DATA_ORIGIN%TYPE DEFAULT NULL
    )
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;

        v_existe       NUMBER;
        v_error_mess   VARCHAR2(4000);

    BEGIN

        ------------------------------------------------------------------
        -- Comprobar si el mismo error ya está registrado
        ------------------------------------------------------------------
        SELECT COUNT(1)
          INTO v_existe
          FROM SZRLGBP
         WHERE SZRLGBP_BUSINESS_LINE = p_business_line
           AND SZRLGBP_OP_TYPE       = p_op_type
           AND NVL(SZRLGBP_TERM_CODE, '0') = NVL(p_term_code, '0')
           AND NVL(SZRLGBP_PTRM_CODE, '0') = NVL(p_ptrm_code, '0')
           AND NVL(SZRLGBP_CRN, '0')       = NVL(p_crn, '0')
           AND NVL(SZRLGBP_PIDM, 0)        = NVL(p_pidm, 0)
           AND SZRLGBP_ERROR_CODE          = p_error_code
           AND SZRLGBP_STATE               = p_state;

        ------------------------------------------------------------------
        -- Registrar solamente si no existe
        ------------------------------------------------------------------
        IF v_existe = 0 THEN

            INSERT INTO SZRLGBP
            (
                SZRLGBP_ID,
                SZRLGBP_BUSINESS_LINE,
                SZRLGBP_OP_TYPE,
                SZRLGBP_TERM_CODE,
                SZRLGBP_PTRM_CODE,
                SZRLGBP_CRN,
                SZRLGBP_PIDM,
                SZRLGBP_ERROR_CODE,
                SZRLGBP_ERROR_MESSAGE,
                SZRLGBP_ID_MAESTRO,
                SZRLGBP_STATE,
                SZRLGBP_USER_ID,
                SZRLGBP_ACTIVITY_DATE,
                SZRLGBP_DATA_ORIGIN
            )
            VALUES
            (
                SEQ_SZRLGBP.NEXTVAL,
                p_business_line,
                p_op_type,
                p_term_code,
                p_ptrm_code,
                p_crn,
                p_pidm,
                p_error_code,
                p_error_message,
                p_id_maestro,
                p_state,
                p_user_id,
                SYSDATE,
                p_data_origin
            );

        END IF;

        ------------------------------------------------------------------
        -- IMPORTANTE:
        -- La transacción autónoma debe finalizar con COMMIT
        ------------------------------------------------------------------
        COMMIT;


    EXCEPTION
        WHEN OTHERS THEN

            ------------------------------------------------------------------
            -- Guardamos el error que provocó el fallo del procedimiento
            ------------------------------------------------------------------
            v_error_mess := SQLERRM;

            BEGIN

                INSERT INTO SZRLGBP
                (
                    SZRLGBP_ID,
                    SZRLGBP_BUSINESS_LINE,
                    SZRLGBP_OP_TYPE,
                    SZRLGBP_TERM_CODE,
                    SZRLGBP_PTRM_CODE,
                    SZRLGBP_CRN,
                    SZRLGBP_PIDM,
                    SZRLGBP_ERROR_CODE,
                    SZRLGBP_ERROR_MESSAGE,
                    SZRLGBP_ID_MAESTRO,
                    SZRLGBP_STATE,
                    SZRLGBP_USER_ID,
                    SZRLGBP_ACTIVITY_DATE,
                    SZRLGBP_DATA_ORIGIN
                )
                VALUES
                (
                    SEQ_SZRLGBP.NEXTVAL,
                    p_business_line,
                    p_op_type,
                    p_term_code,
                    p_ptrm_code,
                    p_crn,
                    p_pidm,
                    'ERROR_ORACLE',
                    v_error_mess,
                    p_id_maestro,
                    'ERROR',
                    p_user_id,
                    SYSDATE,
                    p_data_origin
                );

                COMMIT;

            EXCEPTION
                WHEN OTHERS THEN
                    ------------------------------------------------------------------
                    -- Si incluso el registro del error falla,
                    -- deshacemos la transacción autónoma.
                    ------------------------------------------------------------------
                    ROLLBACK;
            END;

    END p_registra_error_log_uk;
    ----------------------------------------------------------------------
    -- TABLA INTERMEDIA: SZRTMBP
    -- PERIODOS
    --
    -- Comportamiento:
    --   Si existe TERM_CODE + PTRM_CODE -> UPDATE
    --   Si no existe                   -> INSERT
    ----------------------------------------------------------------------
    PROCEDURE p_intermedia_szrtmbp (
        p_registro       IN SZRTMBP%ROWTYPE,
        p_business_line  IN SZRLGBP.SZRLGBP_BUSINESS_LINE%TYPE,
        p_op_type        IN SZRLGBP.SZRLGBP_OP_TYPE%TYPE
    )
    IS

    BEGIN

        MERGE INTO SZRTMBP tgt
        USING (
            SELECT
                p_registro.SZRTMBP_TERM_CODE AS term_code,
                p_registro.SZRTMBP_PTRM_CODE AS ptrm_code
            FROM dual
        ) src
        ON (
            tgt.SZRTMBP_TERM_CODE = src.term_code
            AND tgt.SZRTMBP_PTRM_CODE = src.ptrm_code
        )

        WHEN MATCHED THEN

            UPDATE SET
                tgt.SZRTMBP_DESC          = p_registro.SZRTMBP_DESC,
                tgt.SZRTMBP_START_DATE    = p_registro.SZRTMBP_START_DATE,
                tgt.SZRTMBP_END_DATE      = p_registro.SZRTMBP_END_DATE,
                tgt.SZRTMBP_STATE         = 'NEW',
                tgt.SZRTMBP_OPERACION     = 'U',
                tgt.SZRTMBP_VERSION       = NVL(tgt.SZRTMBP_VERSION, 0) + 1,
                tgt.SZRTMBP_DATA_ORIGIN   = p_registro.SZRTMBP_DATA_ORIGIN,
                tgt.SZRTMBP_USER_ID       = USER,
                tgt.SZRTMBP_ACTIVITY_DATE = SYSDATE

        WHEN NOT MATCHED THEN

            INSERT (
                SZRTMBP_TERM_CODE,
                SZRTMBP_PTRM_CODE,
                SZRTMBP_DESC,
                SZRTMBP_START_DATE,
                SZRTMBP_END_DATE,
                SZRTMBP_STATE,
                SZRTMBP_OPERACION,
                SZRTMBP_VERSION,
                SZRTMBP_DATA_ORIGIN,
                SZRTMBP_USER_ID,
                SZRTMBP_ACTIVITY_DATE
            )
            VALUES (
                p_registro.SZRTMBP_TERM_CODE,
                p_registro.SZRTMBP_PTRM_CODE,
                p_registro.SZRTMBP_DESC,
                p_registro.SZRTMBP_START_DATE,
                p_registro.SZRTMBP_END_DATE,
                'NEW',
                'I',
                1,
                p_registro.SZRTMBP_DATA_ORIGIN,
                USER,
                SYSDATE
            );


        ------------------------------------------------------------------
        -- LOG ÉXITO
        ------------------------------------------------------------------
--
--        p_registra_error_log(
--            p_business_line => p_business_line,
--            p_op_type       => p_op_type,
--            p_term_code     => p_registro.SZRTMBP_TERM_CODE,
--            p_ptrm_code     => p_registro.SZRTMBP_PTRM_CODE,
--            p_error_code    => 'INTERMEDIA_OK',
--            p_error_message => 'Registro de periodo procesado correctamente',
--            p_state         => 'OK',
--            p_data_origin   => p_registro.SZRTMBP_DATA_ORIGIN
--        );


    EXCEPTION
        WHEN OTHERS THEN

            p_registra_error_log(
                p_business_line => p_business_line,
                p_op_type       => p_op_type,
                p_term_code     => p_registro.SZRTMBP_TERM_CODE,
                p_ptrm_code     => p_registro.SZRTMBP_PTRM_CODE,
                p_error_code    => 'INTERMEDIA_ERR',
                p_error_message => SQLERRM ||
                                   ' | BACKTRACE: ' ||
                                   DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,
                p_state         => 'ERROR',
                p_data_origin   => p_registro.SZRTMBP_DATA_ORIGIN
            );

            RAISE;

    END p_intermedia_szrtmbp;


    ----------------------------------------------------------------------
    -- TABLA INTERMEDIA: SZRSSBP
    -- NRC
    --
    -- Comportamiento:
    --   Si no existe TERM_CODE + CRN -> INSERT
    --   Si existe                    -> no hace nada
    ----------------------------------------------------------------------
    PROCEDURE p_intermedia_szrssbp (
        p_registro       IN SZRSSBP%ROWTYPE,
        p_business_line  IN SZRLGBP.SZRLGBP_BUSINESS_LINE%TYPE,
        p_op_type        IN SZRLGBP.SZRLGBP_OP_TYPE%TYPE
    )
    IS

    BEGIN

        INSERT INTO SZRSSBP (
            SZRSSBP_TERM_CODE,
            SZRSSBP_CRN,
            SZRSSBP_PTRM_CODE,
            SZRSSBP_SUBJ_CODE,
            SZRSSBP_CRSE_NUMB,
            SZRSSBP_PTRM_START_DATE,
            SZRSSBP_CRSE_TITLE,
            SZRSSBP_MAX_ENRL,
            SZRSSBP_LINE_NEG,
            SZRSSBP_STATE,
            SZRSSBP_OPERACION,
            SZRSSBP_VERSION,
            SZRSSBP_DATA_ORIGIN,
            SZRSSBP_USER_ID,
            SZRSSBP_ACTIVITY_DATE
        )
        SELECT
            p_registro.SZRSSBP_TERM_CODE,
            p_registro.SZRSSBP_CRN,
            p_registro.SZRSSBP_PTRM_CODE,
            p_registro.SZRSSBP_SUBJ_CODE,
            p_registro.SZRSSBP_CRSE_NUMB,
            p_registro.SZRSSBP_PTRM_START_DATE,
            p_registro.SZRSSBP_CRSE_TITLE,
            p_registro.SZRSSBP_MAX_ENRL,
            p_registro.SZRSSBP_LINE_NEG,
            'NEW',
            'I',
            1,
            p_registro.SZRSSBP_DATA_ORIGIN,
            USER,
            SYSDATE
        FROM dual
        WHERE NOT EXISTS (
            SELECT 1
              FROM SZRSSBP
             WHERE SZRSSBP_TERM_CODE = p_registro.SZRSSBP_TERM_CODE
               AND SZRSSBP_CRN       = p_registro.SZRSSBP_CRN
        );


--        ------------------------------------------------------------------
--        -- LOG ÉXITO
--        ------------------------------------------------------------------
--
--        p_registra_error_log(
--            p_business_line => p_business_line,
--            p_op_type       => p_op_type,
--            p_term_code     => p_registro.SZRSSBP_TERM_CODE,
--            p_crn           => p_registro.SZRSSBP_CRN,
--            p_error_code    => 'INTERMEDIA_OK',
--            p_error_message => 'Registro de NRC procesado correctamente',
--            p_state         => 'OK',
--            p_data_origin   => p_registro.SZRSSBP_DATA_ORIGIN
--        );


    EXCEPTION
        WHEN OTHERS THEN

            p_registra_error_log(
                p_business_line => p_business_line,
                p_op_type       => p_op_type,
                p_term_code     => p_registro.SZRSSBP_TERM_CODE,
                p_crn           => p_registro.SZRSSBP_CRN,
                p_error_code    => 'INTERMEDIA_ERR',
                p_error_message => SQLERRM ||
                                   ' | BACKTRACE: ' ||
                                   DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,
                p_state         => 'ERROR',
                p_data_origin   => p_registro.SZRSSBP_DATA_ORIGIN
            );

            RAISE;

    END p_intermedia_szrssbp;


    ----------------------------------------------------------------------
    -- TABLA INTERMEDIA: SZRPEBP
    -- PERSONA
    --
    -- Comportamiento:
    --   Si no existe PIDM + TERM_CODE -> INSERT
    --   Si existe                     -> no hace nada
    ----------------------------------------------------------------------
    PROCEDURE p_intermedia_szrpebp (
        p_registro       IN SZRPEBP%ROWTYPE,
        p_business_line  IN SZRLGBP.SZRLGBP_BUSINESS_LINE%TYPE,
        p_op_type        IN SZRLGBP.SZRLGBP_OP_TYPE%TYPE
    )
    IS

        v_existe NUMBER;

    BEGIN

        SELECT COUNT(*)
          INTO v_existe
          FROM SZRPEBP
         WHERE SZRPEBP_PIDM      = p_registro.SZRPEBP_PIDM
           AND SZRPEBP_TERM_CODE = p_registro.SZRPEBP_TERM_CODE;


        IF v_existe = 0 THEN

            INSERT INTO SZRPEBP (
                SZRPEBP_PIDM,
                SZRPEBP_TERM_CODE,
                SZRPEBP_LINE_NEG,
                SZRPEBP_ROL,
                SZRPEBP_STATE,
                SZRPEBP_OPERACION,
                SZRPEBP_VERSION,
                SZRPEBP_DATA_ORIGIN,
                SZRPEBP_USER_ID,
                SZRPEBP_ACTIVITY_DATE
            )
            VALUES (
                p_registro.SZRPEBP_PIDM,
                p_registro.SZRPEBP_TERM_CODE,
                p_registro.SZRPEBP_LINE_NEG,
                p_registro.SZRPEBP_ROL,
                'NEW',
                'I',
                1,
                p_registro.SZRPEBP_DATA_ORIGIN,
                USER,
                SYSDATE
            );

        END IF;


        ------------------------------------------------------------------
        -- LOG ÉXITO
        ------------------------------------------------------------------
--
--        p_registra_error_log(
--            p_business_line => p_business_line,
--            p_op_type       => p_op_type,
--            p_term_code     => p_registro.SZRPEBP_TERM_CODE,
--            p_pidm          => p_registro.SZRPEBP_PIDM,
--            p_error_code    => 'INTERMEDIA_OK',
--            p_error_message => 'Registro de persona procesado correctamente',
--            p_state         => 'OK',
--            p_data_origin   => p_registro.SZRPEBP_DATA_ORIGIN
--        );


    EXCEPTION
        WHEN OTHERS THEN

            p_registra_error_log(
                p_business_line => p_business_line,
                p_op_type       => p_op_type,
                p_term_code     => p_registro.SZRPEBP_TERM_CODE,
                p_pidm          => p_registro.SZRPEBP_PIDM,
                p_error_code    => 'INTERMEDIA_ERR',
                p_error_message => SQLERRM ||
                                   ' | BACKTRACE: ' ||
                                   DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,
                p_state         => 'ERROR',
                p_data_origin   => p_registro.SZRPEBP_DATA_ORIGIN
            );

            RAISE;

    END p_intermedia_szrpebp;


    ----------------------------------------------------------------------
    -- TABLA INTERMEDIA: SZREDBP
    -- ENROLLMENT
    --
    -- Comportamiento:
    --   OPERACION = I -> INSERT si no existe
    --   OPERACION = D -> DELETE lógico
    ----------------------------------------------------------------------
    PROCEDURE p_intermedia_szredbp (
        p_registro       IN SZREDBP%ROWTYPE,
        p_business_line  IN SZRLGBP.SZRLGBP_BUSINESS_LINE%TYPE,
        p_op_type        IN SZRLGBP.SZRLGBP_OP_TYPE%TYPE
    )
    IS

        v_existe NUMBER;

    BEGIN

        ------------------------------------------------------------------
        -- INSERT
        ------------------------------------------------------------------

        IF p_registro.SZREDBP_OPERACION = 'I' THEN

            SELECT COUNT(*)
              INTO v_existe
              FROM SZREDBP
             WHERE SZREDBP_TERM_CODE = p_registro.SZREDBP_TERM_CODE
               AND SZREDBP_CRN       = p_registro.SZREDBP_CRN
               AND SZREDBP_PIDM      = p_registro.SZREDBP_PIDM
               AND SZREDBP_CATEGORY  = p_registro.SZREDBP_CATEGORY
               AND SZREDBP_LINE_NEG  = p_registro.SZREDBP_LINE_NEG;


            IF v_existe = 0 THEN

                INSERT INTO SZREDBP (
                    SZREDBP_TERM_CODE,
                    SZREDBP_CRN,
                    SZREDBP_PIDM,
                    SZREDBP_CATEGORY,
                    SZREDBP_LINE_NEG,
                    SZREDBP_STATE,
                    SZREDBP_OPERACION,
                    SZREDBP_VERSION,
                    SZREDBP_DATA_ORIGIN,
                    SZREDBP_USER_ID,
                    SZREDBP_ROLE_ID,
                    SZREDBP_ADDIC_ID,
                    SZREDBP_NRC_ID
                )
                VALUES (
                    p_registro.SZREDBP_TERM_CODE,
                    p_registro.SZREDBP_CRN,
                    p_registro.SZREDBP_PIDM,
                    p_registro.SZREDBP_CATEGORY,
                    p_registro.SZREDBP_LINE_NEG,
                    'NEW',
                    'I',
                    1,
                    p_registro.SZREDBP_DATA_ORIGIN,
                    USER,
                    p_registro.SZREDBP_ROLE_ID,
                    p_registro.SZREDBP_ADDIC_ID,
                    p_registro.SZREDBP_NRC_ID
                );

            END IF;


        ------------------------------------------------------------------
        -- DELETE LÓGICO
        ------------------------------------------------------------------

        ELSIF p_registro.SZREDBP_OPERACION = 'D' THEN

            UPDATE SZREDBP
               SET SZREDBP_STATE         = 'DEL',
                   SZREDBP_OPERACION     = 'D',
                   SZREDBP_VERSION       = NVL(SZREDBP_VERSION, 0) + 1,
                   SZREDBP_USER_ID       = USER,
                   SZREDBP_ACTIVITY_DATE = SYSDATE
             WHERE SZREDBP_TERM_CODE = p_registro.SZREDBP_TERM_CODE
               AND SZREDBP_CRN       = p_registro.SZREDBP_CRN
               AND SZREDBP_PIDM      = p_registro.SZREDBP_PIDM
               AND SZREDBP_CATEGORY  = p_registro.SZREDBP_CATEGORY
               AND SZREDBP_LINE_NEG  = p_registro.SZREDBP_LINE_NEG;

        END IF;


        ------------------------------------------------------------------
        -- LOG ÉXITO
        ------------------------------------------------------------------
--
--        p_registra_error_log(
--            p_business_line => p_business_line,
--            p_op_type       => p_op_type,
--            p_term_code     => p_registro.SZREDBP_TERM_CODE,
--            p_crn           => p_registro.SZREDBP_CRN,
--            p_pidm          => p_registro.SZREDBP_PIDM,
--            p_error_code    => 'INTERMEDIA_OK',
--            p_error_message => 'Registro de enrollment procesado correctamente',
--            p_state         => 'OK',
--            p_data_origin   => p_registro.SZREDBP_DATA_ORIGIN
--        );


    EXCEPTION
        WHEN OTHERS THEN

            p_registra_error_log(
                p_business_line => p_business_line,
                p_op_type       => p_op_type,
                p_term_code     => p_registro.SZREDBP_TERM_CODE,
                p_crn           => p_registro.SZREDBP_CRN,
                p_pidm          => p_registro.SZREDBP_PIDM,
                p_error_code    => 'INTERMEDIA_ERR',
                p_error_message => SQLERRM ||
                                   ' | BACKTRACE: ' ||
                                   DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,
                p_state         => 'ERROR',
                p_data_origin   => p_registro.SZREDBP_DATA_ORIGIN
            );

            RAISE;

    END p_intermedia_szredbp;
    

   /* *********************************************************************** */
   PROCEDURE p_genera_inserta_itzbgsp_multi (
    p_business_line   IN INTEGRACION.ITZBGSP.BUSINESS_LINE%TYPE,
    p_op_type         IN INTEGRACION.ITZBGSP.OP_TYPE%TYPE,
    p_registros       IN t_itzbgsp_tab,
    p_id_generado   OUT INTEGRACION.ITZBGSP.ID%TYPE,
    p_pidm            IN NUMBER DEFAULT NULL,
    p_id_spriden      IN NUMBER DEFAULT NULL
    )
    IS
        l_request CLOB;
        l_json    CLOB := '[';
    BEGIN
      p_id_generado := INTEGRACION.SEQ_ITZBGSP.NEXTVAL;
      
        IF p_registros.COUNT = 0 THEN
            RETURN;
        END IF;
    
        FOR i IN p_registros.FIRST .. p_registros.LAST LOOP
    
            IF p_registros.EXISTS(i) THEN
    
                IF l_json <> '[' THEN
                    l_json := l_json || ',';
                END IF;
    
                SELECT JSON_OBJECT(
                           'request' VALUE JSON_OBJECT(
                               'id'       VALUE p_id_generado,
                               'endpoint' VALUE p_registros(i).endpoint,
                               'method'   VALUE p_registros(i).method,
                               'body'     VALUE p_registros(i).body FORMAT JSON
                           ),
                           'response' VALUE NULL
                           RETURNING CLOB
                       )
                INTO l_request
                FROM dual;
    
                l_json := l_json || l_request;
    
            END IF;
    
        END LOOP;
    
        l_json := l_json || ']';
    
    
        INSERT INTO INTEGRACION.ITZBGSP (
            ID,
            BUSINESS_LINE,
            REQUEST,
            RESPONSE,
            CREATE_DATE,
            REQUEST_DATE,
            RESPONSE_DATE,
            OP_TYPE,
            STATUS,
            PIDM,
            ID_SPRIDEN
        )
        VALUES (
            p_id_generado,
            p_business_line,
            l_json,
            NULL,
            SYSDATE,
            NULL,
            NULL,
            p_op_type,
            'PENDING',
            p_pidm,
            p_id_spriden
        );

END p_genera_inserta_itzbgsp_multi;
   
   
   
   /* *********************************************************************** */
   

    PROCEDURE p_genera_inserta_itzbgsp (
    p_business_line IN INTEGRACION.ITZBGSP.BUSINESS_LINE%TYPE,
    p_op_type       IN INTEGRACION.ITZBGSP.OP_TYPE%TYPE,
    p_endpoint      IN VARCHAR2,
    p_method        IN VARCHAR2,
    p_body          IN CLOB,
    p_id_generado   OUT INTEGRACION.ITZBGSP.ID%TYPE,
    p_pidm            IN NUMBER DEFAULT NULL,
    p_id_spriden      IN NUMBER DEFAULT NULL
)
IS
    l_json CLOB;
BEGIN

    --------------------------------------------------------------
    -- Generar ID
    --------------------------------------------------------------
    p_id_generado := INTEGRACION.SEQ_ITZBGSP.NEXTVAL;


    --------------------------------------------------------------
    -- Generar JSON completo
    --------------------------------------------------------------
    SELECT JSON_ARRAY(
               JSON_OBJECT(
                   'request' VALUE JSON_OBJECT(
                       'id'       VALUE p_id_generado,
                       'endpoint' VALUE p_endpoint,
                       'method'   VALUE p_method,
                       'body'     VALUE p_body FORMAT JSON
                       RETURNING CLOB
                   ),
                   'response' VALUE NULL
                   RETURNING CLOB
               )
               RETURNING CLOB
           )
      INTO l_json
      FROM dual;


    --------------------------------------------------------------
    -- Insertar en ITZBGSP
    --------------------------------------------------------------
    INSERT INTO INTEGRACION.ITZBGSP (
        ID,
        BUSINESS_LINE,
        REQUEST,
        RESPONSE,
        CREATE_DATE,
        REQUEST_DATE,
        RESPONSE_DATE,
        OP_TYPE,
        STATUS,
        PIDM,
        ID_SPRIDEN
    )
    VALUES (
        p_id_generado,
        p_business_line,
        l_json,
        NULL,
        SYSDATE,
        SYSDATE,
        NULL,
        p_op_type,
        'PENDING',
        p_pidm,
        p_id_spriden
    );

END p_genera_inserta_itzbgsp;

PROCEDURE P_PROCESA_RESPONSE
IS
  v_error VARCHAR2(200);
BEGIN

    FOR R IN (
        SELECT ROWID AS RID,
               ID,
               OP_TYPE,
               STATUS
          FROM INTEGRACION.ITZBGSP
         WHERE STATUS_RESPONSE IS NULL
           AND STATUS IN ('PROCESSED_OK', 'PROCESSED_KO')
         ORDER BY ID
    )
    LOOP

        BEGIN
            ------------------------------------------------------------
            -- 1. Marcar el registro como PROCESSING_RESPONSE
            ------------------------------------------------------------
            UPDATE INTEGRACION.ITZBGSP
               SET STATUS_RESPONSE = 'PROCESSING_RESPONSE'
             WHERE ROWID = R.RID
               AND STATUS_RESPONSE IS NULL;

            COMMIT;

            ------------------------------------------------------------
            -- 2. Procesar según STATUS
            ------------------------------------------------------------

            IF R.STATUS = 'PROCESSED_KO' THEN

                --------------------------------------------------------
                -- PROCESSED_KO
                -- REGISTROS CON ERROR
                --------------------------------------------------------
                v_error:= 'Falló la operación de '||R.OP_TYPE;
                
                  PKG_INT_BRIPACE_UTIL.p_registra_error_log_uk(
                            p_business_line => 'ONLINE',
                            p_op_type       => R.OP_TYPE,
                            p_term_code     => null,
                            p_ptrm_code     => null,
                            p_error_code    => R.OP_TYPE||'_ERR',
                            p_error_message => v_error
                        );

            ELSIF R.STATUS = 'PROCESSED_OK' THEN

                --------------------------------------------------------
                -- PROCESSED_OK
                -- Ejecutar procedimiento según OP_TYPE
                --------------------------------------------------------

                CASE R.OP_TYPE

                    WHEN 'CREATE_TERM' THEN

                        INTEGRACION.PKG_INT_BRIPACE_TERM.p_insert_itzsupl(
                            p_id_maestro => R.ID
                        );


                    WHEN 'CREATE_NRC' THEN

                        INTEGRACION.PKG_INT_BRIPACE_NRC.p_insert_itzsupl(
                            p_id_maestro => R.ID
                        );


                    WHEN 'CREATE_USER_TH' THEN
                    -- DOCENTES             

                        INTEGRACION.PKG_INT_BRIPACE_PERS.p_insert_goradid(
                            p_id_maestro => R.ID
                        );
                     WHEN 'CREATE_USER_ST' THEN
                        -- ALUMNOS
                        INTEGRACION.PKG_INT_BRIPACE_PERS.p_insert_goradid_alu(
                            p_id_maestro => R.ID
                        );

                    ELSE
                       --los demas procesos en 'PROCESSED_OK' los pasa a COMPLETED_OK
                       PKG_INT_BRIPACE_UTIL.P_ACTUALIZA_ESTADO_ITZBGSP( r.id, R.OP_TYPE, 'COMPLETED_OK');

                END CASE;

            END IF;


        EXCEPTION
            WHEN OTHERS THEN

                --------------------------------------------------------
                -- Si ocurre un error, dejar nuevamente el registro
                -- disponible para un próximo procesamiento
                --------------------------------------------------------
                UPDATE INTEGRACION.ITZBGSP
                   SET STATUS_RESPONSE = NULL
                 WHERE ROWID = R.RID;

                COMMIT;

        END;

    END LOOP;
    

END P_PROCESA_RESPONSE;

PROCEDURE P_PROCESA_RESPONSE_ALU
IS
  v_error VARCHAR2(200);
BEGIN

    FOR R IN (
        SELECT ROWID AS RID,
               ID,
               OP_TYPE,
               STATUS
          FROM INTEGRACION.ITZERST
         WHERE STATUS_RESPONSE IS NULL
           AND STATUS IN ('PROCESSED_OK', 'PROCESSED_KO')
         ORDER BY ID
    )
    LOOP

        BEGIN
            ------------------------------------------------------------
            -- 1. Marcar el registro como PROCESSING_RESPONSE
            ------------------------------------------------------------
            UPDATE INTEGRACION.ITZERST
               SET STATUS_RESPONSE = 'PROCESSING_RESPONSE'
             WHERE ROWID = R.RID
               AND STATUS_RESPONSE IS NULL;

            COMMIT;

            ------------------------------------------------------------
            -- 2. Procesar según STATUS
            ------------------------------------------------------------

            IF R.STATUS = 'PROCESSED_KO' THEN

                --------------------------------------------------------
                -- PROCESSED_KO
                -- REGISTROS CON ERROR
                --------------------------------------------------------
                v_error:= 'Falló la operación de '||R.OP_TYPE;
                
                  PKG_INT_BRIPACE_UTIL.p_registra_error_log_uk(
                            p_business_line => 'ONLINE',
                            p_op_type       => R.OP_TYPE,
                            p_term_code     => null,
                            p_ptrm_code     => null,
                            p_error_code    => R.OP_TYPE||'_ERR',
                            p_error_message => v_error
                        );

            ELSIF R.STATUS = 'PROCESSED_OK' THEN

                --------------------------------------------------------
                -- PROCESSED_OK
                -- Ejecutar procedimiento según OP_TYPE
                --------------------------------------------------------

                CASE R.OP_TYPE

                    WHEN 'CREATE_ENRROLLMENT' THEN

                        INTEGRACION.PKG_INT_BRIPACE_ENROLL.p_ins_dato_supl_enroll(
                            p_id => R.ID
                        );

                    ELSE
                       --los demas procesos en 'PROCESSED_OK' los pasa a COMPLETED_OK/COMPLETED KO
                       PKG_INT_BRIPACE_UTIL.P_ACTUALIZA_ESTADO_ITZERST( r.id, R.OP_TYPE, 'COMPLETED_OK');
                       PKG_INT_BRIPACE_UTIL.P_ACTUALIZA_ESTADO_ITZERST( r.id, R.OP_TYPE, 'COMPLETED_KO');

                END CASE;

            END IF;


        EXCEPTION
            WHEN OTHERS THEN

                --------------------------------------------------------
                -- Si ocurre un error, dejar nuevamente el registro
                -- disponible para un próximo procesamiento
                --------------------------------------------------------
                UPDATE INTEGRACION.ITZERST
                   SET STATUS_RESPONSE = NULL
                 WHERE ROWID = R.RID;

                COMMIT;

        END;

    END LOOP;
    
END P_PROCESA_RESPONSE_ALU;

PROCEDURE P_ACTUALIZA_ESTADO_ITZBGSP (
    P_ID_MAESTRO      IN INTEGRACION.ITZBGSP.ID%TYPE,
    P_OP_TYPE         IN INTEGRACION.ITZBGSP.OP_TYPE%TYPE,
    P_STATUS_RESPONSE IN INTEGRACION.ITZBGSP.STATUS_RESPONSE%TYPE
)
IS
BEGIN

    UPDATE INTEGRACION.ITZBGSP
       SET STATUS_RESPONSE = P_STATUS_RESPONSE
     WHERE STATUS = 'PROCESSED_OK'
       AND OP_TYPE = P_OP_TYPE
       AND ID = P_ID_MAESTRO;

END P_ACTUALIZA_ESTADO_ITZBGSP;

PROCEDURE P_ACTUALIZA_ESTADO_ITZERST (
    P_ID              IN INTEGRACION.ITZERST.ID%TYPE,
    P_OP_TYPE         IN INTEGRACION.ITZERST.OP_TYPE%TYPE,
    P_STATUS_RESPONSE IN INTEGRACION.ITZERST.STATUS_RESPONSE%TYPE
)
IS
BEGIN
  IF P_STATUS_RESPONSE = 'COMPLETED_OK' THEN
    UPDATE INTEGRACION.ITZERST
       SET STATUS_RESPONSE = P_STATUS_RESPONSE
     WHERE STATUS = 'PROCESSED_OK'
       AND OP_TYPE = P_OP_TYPE
       AND ID = P_ID;
  ELSE     
     UPDATE INTEGRACION.ITZERST
       SET STATUS_RESPONSE = P_STATUS_RESPONSE
     WHERE STATUS = 'PROCESSED_KO'
       AND OP_TYPE = P_OP_TYPE
       AND ID = P_ID;
  END IF;
END P_ACTUALIZA_ESTADO_ITZERST;

PROCEDURE P_ACTUALIZA_INTERMEDIA_STATE (
    P_TIPO        IN VARCHAR2,
    P_ID_MAESTRO  IN NUMBER,
    P_STATE_OLD   IN VARCHAR2,
    P_STATE       IN VARCHAR2,
    P_MENSAJE     IN VARCHAR2 DEFAULT NULL
)
IS
BEGIN

    IF P_STATE_OLD NOT IN ('SEND', 'APPLIED', 'FAIL') THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'Estado anterior no válido: ' || P_STATE_OLD
        );
    END IF;

    IF P_STATE NOT IN ('SEND', 'APPLIED', 'FAIL') THEN
        RAISE_APPLICATION_ERROR(
            -20002,
            'Estado nuevo no válido: ' || P_STATE
        );
    END IF;


    IF P_TIPO = 'CREATE_TERM' THEN

        UPDATE INTEGRACION.SZRTMBP
           SET SZRTMBP_STATE     = P_STATE,
               SZRTMBP_STATE_DET = P_MENSAJE
         WHERE SZRTMBP_STATE = P_STATE_OLD
           AND SZRTMBP_ID_MAESTRO = P_ID_MAESTRO;


    ELSIF P_TIPO = 'CREATE_NRC' THEN

        UPDATE INTEGRACION.SZRSSBP
           SET SZRSSBP_STATE     = P_STATE,
               SZRSSBP_STATE_DET = P_MENSAJE
         WHERE SZRSSBP_STATE = P_STATE_OLD
           AND SZRSSBP_ID_MAESTRO = P_ID_MAESTRO;


    ELSIF P_TIPO = 'CREATE_USER_TH' THEN

        UPDATE INTEGRACION.SZRPEBP
           SET SZRPEBP_STATE     = P_STATE,
               SZRPEBP_STATE_DET = P_MENSAJE
         WHERE SZRPEBP_STATE = P_STATE_OLD  AND 
         SZRPEBP_ID_MAESTRO = P_ID_MAESTRO;
         
    ELSIF P_TIPO = 'CREATE_USER_ST' THEN

        UPDATE INTEGRACION.SZRSTBP
           SET SZRSTBP_STATE     = P_STATE,
               SZRSTBP_STATE_DET = P_MENSAJE
         WHERE SZRSTBP_STATE = P_STATE_OLD  AND 
         SZRSTBP_ID_MAESTRO = P_ID_MAESTRO;


    ELSE

        RAISE_APPLICATION_ERROR(
            -20003,
            'Tipo no válido: ' || P_TIPO ||
            '. Valores permitidos: CREATE_TERM, CREATE_NRC, CREATE_USER'
        );

    END IF;

END P_ACTUALIZA_INTERMEDIA_STATE;

 PROCEDURE p_obtener_config_api (
        p_operacion IN  VARCHAR2,
        p_url       OUT VARCHAR2,
        p_method    OUT VARCHAR2,
        p_path      OUT VARCHAR2
    )
    IS
        v_path_base VARCHAR2(4000);
        v_posicion  PLS_INTEGER;
    BEGIN
        -- Obtener URL base
        p_url := PKG_INT_BRIPACE_PERS.f_get_gtvsdax(
            'ONLINE',
            'INSTANAME',
            'DEV_INT_BRIGTHSPACE'
        );

        -- Obtener configuración de la operación
        v_path_base := PKG_INT_BRIPACE_PERS.f_get_gtvsdax(
            'ONLINE',
            p_operacion,
            'DEV_INT_BRIGTHSPACE'
        );

        -- Validar configuración
        v_posicion := INSTR(v_path_base, ',');

        IF v_path_base IS NULL OR v_posicion = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20001,
                'Configuración inválida para: ' || p_operacion
            );
        END IF;

        -- Separar método y ruta
        p_method := TRIM(SUBSTR(v_path_base, 1, v_posicion - 1));
        p_path   := TRIM(SUBSTR(v_path_base, v_posicion + 1));

    END p_obtener_config_api;


END PKG_INT_BRIPACE_UTIL;