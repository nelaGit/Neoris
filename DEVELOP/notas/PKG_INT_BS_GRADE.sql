create or replace PACKAGE                                                                                     PKG_INT_BS_GRADE AS

 ------------------------------------------------------------------
    PROCEDURE P_VALIDA_GRADE (
        P_PIDM        IN INTEGRACION.ITZEXGR.ITZEXGR_PIDM%TYPE,
        P_TERM_CODE   IN INTEGRACION.ITZEXGR.ITZEXGR_TERM_CODE%TYPE,
        P_NRC         IN INTEGRACION.ITZEXGR.ITZEXGR_NRC%TYPE,
        P_GRADE_CODE  IN INTEGRACION.ITZEXGR.ITZEXGR_GRADE_CODE%TYPE,
        P_GRADE       IN INTEGRACION.ITZEXGR.ITZEXGR_GRADE%TYPE,
        P_GRADE_DATE  IN INTEGRACION.ITZEXGR.ITZEXGR_GRADE_DATE%TYPE,
        P_RESPONSE    OUT CLOB,
        P_ES_VALIDO   OUT BOOLEAN
    );


    ------------------------------------------------------------------
    -- ACTUALIZAR RESULTADO
    ------------------------------------------------------------------
    PROCEDURE P_ACTUALIZA_RESULTADO (
         P_ID        IN INTEGRACION.ITZEXGR.ITZEXGR_ID%TYPE,
         P_STATUS    IN INTEGRACION.ITZEXGR.ITZEXGR_STATUS%TYPE,
         P_RESPONSE  IN CLOB DEFAULT NULL
    );


    ------------------------------------------------------------------
    -- INSERTAR GRADE
    ------------------------------------------------------------------
    PROCEDURE INSERT_GRADE (
        P_ITZEXGR_PIDM        IN INTEGRACION.ITZEXGR.ITZEXGR_PIDM%TYPE,
        P_ITZEXGR_TERM_CODE   IN INTEGRACION.ITZEXGR.ITZEXGR_TERM_CODE%TYPE,
        P_ITZEXGR_NRC         IN INTEGRACION.ITZEXGR.ITZEXGR_NRC%TYPE,
        P_ITZEXGR_GRADE_CODE  IN INTEGRACION.ITZEXGR.ITZEXGR_GRADE_CODE%TYPE,
        P_ITZEXGR_GRADE       IN INTEGRACION.ITZEXGR.ITZEXGR_GRADE%TYPE,
        P_ITZEXGR_GRADE_DATE  IN INTEGRACION.ITZEXGR.ITZEXGR_GRADE_DATE%TYPE,
        P_RESPONSE            OUT CLOB
    );

-- Validaciones por columnas
  FUNCTION f_nrc_exists (
    p_term_code IN SATURN.SSBSECT.SSBSECT_TERM_CODE%TYPE,
    p_crn       IN SATURN.SSBSECT.SSBSECT_CRN%TYPE
) RETURN VARCHAR2;


FUNCTION f_grade_exists (
    p_grade_code IN SATURN.SHRTGRD.SHRTGRD_CODE%TYPE
) RETURN VARCHAR2;


FUNCTION f_student_enrolled (
    p_pidm      IN SATURN.SFRSTCR.SFRSTCR_PIDM%TYPE,
    p_term_code IN SATURN.SFRSTCR.SFRSTCR_TERM_CODE%TYPE,
    p_crn        IN SATURN.SFRSTCR.SFRSTCR_CRN%TYPE
) RETURN VARCHAR2;

FUNCTION f_component_exist (
    p_term_code   IN SHRGCOM.SHRGCOM_TERM_CODE%TYPE,
    p_crn         IN SHRGCOM.SHRGCOM_CRN%TYPE,
    p_grade_code  IN SHRGCOM.SHRGCOM_NAME%TYPE
) RETURN VARCHAR2;

FUNCTION f_valida_escala (
     p_term_code   IN SHRGCOM.SHRGCOM_TERM_CODE%TYPE,
     p_crn         IN SHRGCOM.SHRGCOM_CRN%TYPE,
     p_grade_code  IN SHRGCOM.SHRGCOM_NAME%TYPE,
     p_grade       IN SHRGCOM.SHRGCOM_TOTAL_SCORE%TYPE
    ) RETURN VARCHAR2;

FUNCTION f_get_component_cal(
    p_term_code IN SHRMRKS.SHRMRKS_TERM_CODE%TYPE,
    p_crn       IN SHRMRKS.SHRMRKS_CRN%TYPE,
    p_pidm      IN SHRMRKS.SHRMRKS_PIDM%TYPE,
    p_gcom_name IN SHRGCOM.SHRGCOM_NAME%TYPE
) RETURN SHRMRKS.SHRMRKS_GCOM_ID%TYPE;

PROCEDURE p_procesa_calificaciones;

PROCEDURE p_inserta_itvexgr;

END PKG_INT_BS_GRADE;

create or replace PACKAGE BODY                                                             PKG_INT_BS_GRADE AS

    PROCEDURE P_ACTUALIZA_RESULTADO (
    P_ID        IN INTEGRACION.ITZEXGR.ITZEXGR_ID%TYPE,
    P_STATUS    IN INTEGRACION.ITZEXGR.ITZEXGR_STATUS%TYPE,
    P_RESPONSE  IN CLOB DEFAULT NULL
    )
    AS
    BEGIN
        IF P_RESPONSE IS NULL THEN
            -- Solo actualiza el estado
            UPDATE INTEGRACION.ITZEXGR
               SET ITZEXGR_STATUS = P_STATUS
             WHERE ITZEXGR_ID = P_ID;
        ELSE
            -- Actualiza el estado y la respuesta
            UPDATE INTEGRACION.ITZEXGR
               SET ITZEXGR_STATUS   = P_STATUS,
                   ITZEXGR_RESPONSE = P_RESPONSE
             WHERE ITZEXGR_ID = P_ID;
        END IF;
    
        COMMIT;
    END P_ACTUALIZA_RESULTADO;


    PROCEDURE P_VALIDA_GRADE (
        P_PIDM        IN INTEGRACION.ITZEXGR.ITZEXGR_PIDM%TYPE,
        P_TERM_CODE   IN INTEGRACION.ITZEXGR.ITZEXGR_TERM_CODE%TYPE,
        P_NRC         IN INTEGRACION.ITZEXGR.ITZEXGR_NRC%TYPE,
        P_GRADE_CODE  IN INTEGRACION.ITZEXGR.ITZEXGR_GRADE_CODE%TYPE,
        P_GRADE       IN INTEGRACION.ITZEXGR.ITZEXGR_GRADE%TYPE,
        P_GRADE_DATE  IN INTEGRACION.ITZEXGR.ITZEXGR_GRADE_DATE%TYPE,
        P_RESPONSE    OUT CLOB,
        P_ES_VALIDO   OUT BOOLEAN
    )
    AS
        L_ERRORES       CLOB := '[';
        L_PRIMER_ERROR  BOOLEAN := TRUE;
        v_pidm_exist VARCHAR2(1);
    BEGIN

        P_ES_VALIDO := TRUE;
        
        v_pidm_exist:= gb_common.F_PIDM_EXISTS(P_PIDM);

        IF P_PIDM IS NULL or v_pidm_exist ='N' THEN

            L_ERRORES := L_ERRORES ||
                JSON_OBJECT(
                    'error' VALUE 'pidm invalido'
                    RETURNING VARCHAR2
                );

            L_PRIMER_ERROR := FALSE;
            P_ES_VALIDO := FALSE;

        END IF;


        IF P_TERM_CODE IS NULL OR GB_STVTERM.f_code_exists(P_TERM_CODE) = 'N' THEN

            IF NOT L_PRIMER_ERROR THEN
                L_ERRORES := L_ERRORES || ',';
            END IF;

            L_ERRORES := L_ERRORES ||
                JSON_OBJECT(
                    'error' VALUE 'periodo invalido'
                    RETURNING VARCHAR2
                );

            L_PRIMER_ERROR := FALSE;
            P_ES_VALIDO := FALSE;

        END IF;


        IF P_NRC IS NULL THEN

            IF NOT L_PRIMER_ERROR THEN
                L_ERRORES := L_ERRORES || ',';
            END IF;

            L_ERRORES := L_ERRORES ||
                JSON_OBJECT(
                    'error' VALUE 'nrc invalido'
                    RETURNING VARCHAR2
                );

            L_PRIMER_ERROR := FALSE;
            P_ES_VALIDO := FALSE;
        END IF;

        IF (P_NRC IS NOT  NULL) AND (P_TERM_CODE IS NOT NULL ) THEN
          IF f_nrc_exists(P_TERM_CODE, P_NRC ) = 'N' THEN
                IF NOT L_PRIMER_ERROR THEN
                    L_ERRORES := L_ERRORES || ',';
                END IF;
    
                L_ERRORES := L_ERRORES ||
                    JSON_OBJECT(
                        'error' VALUE 'nrc invalido para este periodo'
                        RETURNING VARCHAR2
                    );
             L_PRIMER_ERROR := FALSE;
             P_ES_VALIDO := FALSE;
            
          END IF;
        END IF;


        IF P_GRADE_CODE IS NULL AND f_grade_exists(P_GRADE_CODE) = 'Y' THEN

            IF NOT L_PRIMER_ERROR THEN
                L_ERRORES := L_ERRORES || ',';
            END IF;

            L_ERRORES := L_ERRORES ||
                JSON_OBJECT(
                    'error' VALUE 'codigo de calificacion invalido'
                    RETURNING VARCHAR2
                );

            L_PRIMER_ERROR := FALSE;
            P_ES_VALIDO := FALSE;

        END IF;

        -- valida la nota llegue con valor y que sea numerica
        IF (P_GRADE IS NULL) OR f_valida_escala (
                                     p_term_code=> P_TERM_CODE,
                                     p_crn => P_NRC  ,
                                     p_grade_code => P_GRADE_CODE ,
                                     p_grade => P_GRADE) = 'N' THEN
        
        --NOT (REGEXP_LIKE(TRIM(P_GRADE), '^[0-9]+([.,][0-9]+)?$')) THEN

            IF NOT L_PRIMER_ERROR THEN
                L_ERRORES := L_ERRORES || ',';
            END IF;

            L_ERRORES := L_ERRORES ||
                JSON_OBJECT(
                    'error' VALUE 'calificacion invalida'
                    RETURNING VARCHAR2
                );

            L_PRIMER_ERROR := FALSE;
            P_ES_VALIDO := FALSE;

        END IF;


        IF P_GRADE_DATE IS NULL THEN

            IF NOT L_PRIMER_ERROR THEN
                L_ERRORES := L_ERRORES || ',';
            END IF;

            L_ERRORES := L_ERRORES ||
                JSON_OBJECT(
                    'error' VALUE 'fecha de calificacion invalida'
                    RETURNING VARCHAR2
                );

            L_PRIMER_ERROR := FALSE;
            P_ES_VALIDO := FALSE;

        END IF;
        
 
        
        IF P_TERM_CODE IS NOT NULL AND P_NRC IS NOT NULL AND P_GRADE_CODE IS NOT NULL THEN
        -- validacion componente calificable
            IF f_component_exist(p_term_code=> P_TERM_CODE, p_crn => P_NRC , p_grade_code=> P_GRADE_CODE ) = 'N' THEN
            
              IF NOT L_PRIMER_ERROR THEN
                L_ERRORES := L_ERRORES || ',';
              END IF;

              L_ERRORES := L_ERRORES ||
                JSON_OBJECT(
                    'error' VALUE 'componente de calificacion invalido'
                    RETURNING VARCHAR2
                );

              L_PRIMER_ERROR := FALSE;
              P_ES_VALIDO := FALSE;
            
            END IF;
        END IF;


        L_ERRORES := L_ERRORES || ']';


        IF P_ES_VALIDO THEN

            P_RESPONSE := '{"result":200,"errors":[]}';

        ELSE

            P_RESPONSE :=
                '{"result":400,"errors":' ||
                L_ERRORES ||
                '}';

        END IF;


    EXCEPTION
        WHEN OTHERS THEN

            P_ES_VALIDO := FALSE;

            P_RESPONSE :=
                '{"result":400,"errors":[' ||
                JSON_OBJECT(
                    'error' VALUE SQLERRM
                    RETURNING VARCHAR2
                ) ||
                ']}';

    END P_VALIDA_GRADE;


    PROCEDURE INSERT_GRADE (
        P_ITZEXGR_PIDM        IN INTEGRACION.ITZEXGR.ITZEXGR_PIDM%TYPE,
        P_ITZEXGR_TERM_CODE   IN INTEGRACION.ITZEXGR.ITZEXGR_TERM_CODE%TYPE,
        P_ITZEXGR_NRC         IN INTEGRACION.ITZEXGR.ITZEXGR_NRC%TYPE,
        P_ITZEXGR_GRADE_CODE  IN INTEGRACION.ITZEXGR.ITZEXGR_GRADE_CODE%TYPE,
        P_ITZEXGR_GRADE       IN INTEGRACION.ITZEXGR.ITZEXGR_GRADE%TYPE,
        P_ITZEXGR_GRADE_DATE  IN INTEGRACION.ITZEXGR.ITZEXGR_GRADE_DATE%TYPE,
        P_RESPONSE            OUT CLOB
    )
    AS
        L_ITZEXGR_ID  INTEGRACION.ITZEXGR.ITZEXGR_ID%TYPE;
        L_ES_VALIDO   BOOLEAN;
    BEGIN

        INSERT INTO INTEGRACION.ITZEXGR
        (
            ITZEXGR_ID,
            ITZEXGR_SOURCE,
            ITZEXGR_TERM_CODE,
            ITZEXGR_NRC,
            ITZEXGR_PIDM,
            ITZEXGR_GRADE_CODE,
            ITZEXGR_GRADE,
            ITZEXGR_GRADE_DATE,
            ITZEXGR_REQUEST_DATE,
            ITZEXGR_RESPONSE,
            ITZEXGR_STATUS
        )
        VALUES
        (
            INTEGRACION.ITZEXGR_SEQ.NEXTVAL,
            'BS',
            P_ITZEXGR_TERM_CODE,
            P_ITZEXGR_NRC,
            P_ITZEXGR_PIDM,
            P_ITZEXGR_GRADE_CODE,
            P_ITZEXGR_GRADE,
            P_ITZEXGR_GRADE_DATE,
            SYSDATE,
            NULL,
            'NEW'
        )
        RETURNING ITZEXGR_ID
        INTO L_ITZEXGR_ID;


        COMMIT;


        P_VALIDA_GRADE(
            P_PIDM        => P_ITZEXGR_PIDM,
            P_TERM_CODE   => P_ITZEXGR_TERM_CODE,
            P_NRC         => P_ITZEXGR_NRC,
            P_GRADE_CODE  => P_ITZEXGR_GRADE_CODE,
            P_GRADE       => P_ITZEXGR_GRADE,
            P_GRADE_DATE  => P_ITZEXGR_GRADE_DATE,
            P_RESPONSE    => P_RESPONSE,
            P_ES_VALIDO   => L_ES_VALIDO
        );


        IF NOT L_ES_VALIDO THEN

            P_ACTUALIZA_RESULTADO(
                P_ID       => L_ITZEXGR_ID,
                P_RESPONSE => P_RESPONSE,
                P_STATUS   => 'INVALID'
            );

            RETURN;

        END IF;


        P_ACTUALIZA_RESULTADO(
            P_ID       => L_ITZEXGR_ID,
            P_RESPONSE => P_RESPONSE,
            P_STATUS   => 'PENDING'
        );


    EXCEPTION
        WHEN OTHERS THEN

            P_RESPONSE :=
                '{"result":400,"errors":[' ||
                JSON_OBJECT(
                    'error' VALUE SQLERRM
                    RETURNING VARCHAR2
                ) ||
                ']}';


            IF L_ITZEXGR_ID IS NOT NULL THEN

                P_ACTUALIZA_RESULTADO(
                    P_ID       => L_ITZEXGR_ID,
                    P_RESPONSE => P_RESPONSE,
                    P_STATUS   => 'INVALID'
                );

            END IF;

    END INSERT_GRADE;
    
   FUNCTION f_nrc_exists (
    p_term_code IN SATURN.SSBSECT.SSBSECT_TERM_CODE%TYPE,
    p_crn       IN SATURN.SSBSECT.SSBSECT_CRN%TYPE
    ) RETURN VARCHAR2
    IS
        v_exists NUMBER;
    BEGIN
    
        SELECT 1
          INTO v_exists
          FROM SATURN.SSBSECT
         WHERE SSBSECT_TERM_CODE = p_term_code
           AND SSBSECT_CRN       = p_crn
           AND ROWNUM = 1;
    
        RETURN 'Y';
    
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'N';
    END f_nrc_exists;
    
    FUNCTION f_grade_exists (
    p_grade_code IN SATURN.SHRTGRD.SHRTGRD_CODE%TYPE
    ) RETURN VARCHAR2
    IS
        v_exists NUMBER;
    BEGIN
    
        SELECT 1
          INTO v_exists
          FROM SATURN.SHRTGRD
         WHERE SHRTGRD_CODE = p_grade_code
           AND ROWNUM = 1;
    
        RETURN 'Y';
    
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'N';
    END f_grade_exists;
    
    FUNCTION f_student_enrolled (
    p_pidm      IN SATURN.SFRSTCR.SFRSTCR_PIDM%TYPE,
    p_term_code IN SATURN.SFRSTCR.SFRSTCR_TERM_CODE%TYPE,
    p_crn        IN SATURN.SFRSTCR.SFRSTCR_CRN%TYPE
    ) RETURN VARCHAR2
    IS
        v_exists NUMBER;
    BEGIN
    
        SELECT 1
          INTO v_exists
          FROM SATURN.SFRSTCR
         WHERE SFRSTCR_PIDM      = p_pidm
           AND SFRSTCR_TERM_CODE = p_term_code
           AND SFRSTCR_CRN       = p_crn
           AND ROWNUM = 1;
    
        RETURN 'Y';
    
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'N';
    END f_student_enrolled;
    
    FUNCTION f_component_exist (
     p_term_code   IN SHRGCOM.SHRGCOM_TERM_CODE%TYPE,
     p_crn         IN SHRGCOM.SHRGCOM_CRN%TYPE,
     p_grade_code  IN SHRGCOM.SHRGCOM_NAME%TYPE
    ) RETURN VARCHAR2
    IS
        v_exists NUMBER;
    BEGIN
    
        SELECT 1
          INTO v_exists
          FROM SHRGCOM
         WHERE SHRGCOM_TERM_CODE = p_term_code
           AND SHRGCOM_CRN       = p_crn
           AND SHRGCOM_NAME = p_grade_code
           AND ROWNUM = 1;
    
        RETURN 'Y';
    
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'N';
    END f_component_exist;
    
    FUNCTION f_valida_escala (
     p_term_code   IN SHRGCOM.SHRGCOM_TERM_CODE%TYPE,
     p_crn         IN SHRGCOM.SHRGCOM_CRN%TYPE,
     p_grade_code  IN SHRGCOM.SHRGCOM_NAME%TYPE,
     p_grade       IN SHRGCOM.SHRGCOM_TOTAL_SCORE%TYPE
    ) RETURN VARCHAR2
    IS
        v_tot_score NUMBER;
    BEGIN
    
        SELECT SHRGCOM_TOTAL_SCORE
          INTO v_tot_score
          FROM SHRGCOM
         WHERE SHRGCOM_TERM_CODE = p_term_code
           AND SHRGCOM_CRN       = p_crn
           AND SHRGCOM_NAME = p_grade_code
           AND ROWNUM = 1;
    
    -- Valida que la nota no sea mayor a la escala de calificacion y que no sea un valor menor a cero
        IF  (p_grade > v_tot_score) OR (p_grade < 0) THEN
          RETURN 'N';
        ELSE
          RETURN 'Y';
        END IF;
    
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'N';
    END f_valida_escala;
    
    ---
    FUNCTION f_get_component_cal(
    p_term_code IN SHRMRKS.SHRMRKS_TERM_CODE%TYPE,
    p_crn       IN SHRMRKS.SHRMRKS_CRN%TYPE,
    p_pidm      IN SHRMRKS.SHRMRKS_PIDM%TYPE,
    p_gcom_name IN SHRGCOM.SHRGCOM_NAME%TYPE
    ) RETURN SHRMRKS.SHRMRKS_GCOM_ID%TYPE
    IS
        l_gcom_id SHRMRKS.SHRMRKS_GCOM_ID%TYPE;
    BEGIN
    
        SELECT m.SHRMRKS_GCOM_ID
          INTO l_gcom_id
          FROM SHRMRKS m
          INNER JOIN SHRGCOM c
             ON c.SHRGCOM_TERM_CODE = m.SHRMRKS_TERM_CODE
            AND c.SHRGCOM_CRN       = m.SHRMRKS_CRN
            AND c.SHRGCOM_ID        = m.SHRMRKS_GCOM_ID
         WHERE m.SHRMRKS_TERM_CODE = p_term_code
           AND m.SHRMRKS_CRN       = p_crn
           AND m.SHRMRKS_PIDM      = p_pidm
           AND c.SHRGCOM_NAME      = p_gcom_name;
    
        RETURN l_gcom_id;
    
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    
        WHEN TOO_MANY_ROWS THEN
            -- Hay más de un componente coincidente
            RETURN NULL;
    
        WHEN OTHERS THEN
            RETURN NULL;
    
    END f_get_component_cal;
    
    ---

  PROCEDURE p_procesa_calificaciones
  IS
  v_shrgcom_id SHRMRKS.SHRMRKS_GCOM_ID%TYPE;
  
    CURSOR c_calificaciones IS
    
       SELECT
            e.ITZEXGR_ID,
            e.ITZEXGR_TERM_CODE term_code,
            e.ITZEXGR_NRC nrc,
            e.ITZEXGR_PIDM pidm,
            e.ITZEXGR_GRADE_CODE grade_code,
            e.ITZEXGR_GRADE grade
        FROM ITZEXGR e
        WHERE e.ITZEXGR_STATUS = 'PENDING';
        
--        SELECT
--            e.ITZEXGR_ID,
--            e.ITZEXGR_TERM_CODE,
--            e.ITZEXGR_NRC,
--            e.ITZEXGR_PIDM,
--            e.ITZEXGR_GRADE_CODE,
--            e.ITZEXGR_GRADE,
--            c.SHRGCOM_ID
--        FROM ITZEXGR e
--        INNER JOIN SHRGCOM c
--            ON c.SHRGCOM_TERM_CODE = e.ITZEXGR_TERM_CODE
--           AND c.SHRGCOM_CRN       = e.ITZEXGR_NRC
--           AND UPPER(TRIM(c.SHRGCOM_NAME)) =
--               UPPER(TRIM(e.ITZEXGR_GRADE_CODE))
--        WHERE e.ITZEXGR_STATUS = 'PENDING';

BEGIN

    FOR r IN c_calificaciones LOOP

        BEGIN
          --Antes de calificar, valida que exista el id del componente calificable
          v_shrgcom_id := f_get_component_cal(
                    p_term_code    => r.term_code,
                    p_crn          => r.nrc,
                    p_pidm         => r.pidm,
                    p_gcom_name         => r.grade_code);
                    
          IF v_shrgcom_id IS NOT NULL THEN   
    
                -- Llamada a la API de Banner
                SHKEGRB.P_CALC_GRADABLE_COMP(
                    r.term_code, -- Term code
                    r.nrc,       -- CRN
                    r.pidm,      -- PIDM
                    v_shrgcom_id,       -- ID del componente
                    r.grade     -- Score
                );
                
                -- Actualizar únicamente el estado
                P_ACTUALIZA_RESULTADO(
                    P_ID     => r.ITZEXGR_ID,
                    P_STATUS => 'PROCESSED_OK'
                );
    
                DBMS_OUTPUT.PUT_LINE(
                    'Procesado correctamente ITZEXGR_ID: '
                    || r.ITZEXGR_ID
                );
          ELSE
            P_ACTUALIZA_RESULTADO(
                    P_ID     => r.ITZEXGR_ID,
                    P_STATUS => 'PROCESSED_KO'
                );
                
              PKG_INT_BRIPACE_UTIL.p_registra_error_log(
                p_business_line => 'ONLINE',
                p_op_type       => 'GRADE',
                p_term_code     => r.term_code,
                p_crn           => r.nrc,
                p_pidm          => r.pidm,
                p_state         => 'ERROR',
                p_data_origin   => 'BS', -- BRIGPACE
                p_error_code    => 'GRADE_NOT_FOUND',
                p_error_message => 'Datos inexistentes en componentes calificables '
            );
        
          END IF;

        EXCEPTION
            WHEN OTHERS THEN

                DBMS_OUTPUT.PUT_LINE(
                    'Error procesando ITZEXGR_ID: '
                    || r.ITZEXGR_ID
                    || ' - '
                    || SQLERRM
                );

        END;

    END LOOP;

END P_PROCESA_CALIFICACIONES;

-- Procesa los datos de ITZEXGR y los registra en ITVEXGR para que sea 
-- visualizado en el visor GKPUNK
PROCEDURE p_inserta_itvexgr
IS
BEGIN
    INSERT INTO ITVEXGR (
        ITZEXGR_ID,
        ITZEXGR_SOURCE,
        ITZEXGR_TERM_CODE,
        ITZEXGR_NRC,
        ITZEXGR_PIDM,
        ITZEXGR_GRADE_CODE,
        ITZEXGR_GRADE,
        ITZEXGR_GRADE_DATE,
        ITZEXGR_REQUEST_DATE,
        ITZEXGR_RESPONSE,
        ITZEXGR_STATUS
    )
    SELECT
        E.ITZEXGR_ID,
        E.ITZEXGR_SOURCE,
        E.ITZEXGR_TERM_CODE,
        E.ITZEXGR_NRC,
        E.ITZEXGR_PIDM,
        E.ITZEXGR_GRADE_CODE,
        E.ITZEXGR_GRADE,
        E.ITZEXGR_GRADE_DATE,
        E.ITZEXGR_REQUEST_DATE,
        E.ITZEXGR_RESPONSE,
        E.ITZEXGR_STATUS
    FROM ITZEXGR E
    WHERE E.ITZEXGR_STATUS != 'PENDING'
      AND NOT EXISTS (
          SELECT 1
          FROM ITVEXGR P 
          WHERE P.ITZEXGR_SOURCE = E.ITZEXGR_SOURCE
            AND P.ITZEXGR_STATUS = E.ITZEXGR_STATUS
            AND P.ITZEXGR_TERM_CODE = E.ITZEXGR_TERM_CODE

            AND (
                P.ITZEXGR_NRC = E.ITZEXGR_NRC
                OR (P.ITZEXGR_NRC IS NULL AND E.ITZEXGR_NRC IS NULL)
            )

            AND (
                P.ITZEXGR_PIDM = E.ITZEXGR_PIDM
                OR (P.ITZEXGR_PIDM IS NULL AND E.ITZEXGR_PIDM IS NULL)
            )

            AND (
                P.ITZEXGR_GRADE_CODE = E.ITZEXGR_GRADE_CODE
                OR (
                    P.ITZEXGR_GRADE_CODE IS NULL
                    AND E.ITZEXGR_GRADE_CODE IS NULL
                )
            )

            AND (
                P.ITZEXGR_GRADE = E.ITZEXGR_GRADE
                OR (
                    P.ITZEXGR_GRADE IS NULL
                    AND E.ITZEXGR_GRADE IS NULL
                )
            )

            AND (
                P.ITZEXGR_GRADE_DATE = E.ITZEXGR_GRADE_DATE
                OR (
                    P.ITZEXGR_GRADE_DATE IS NULL
                    AND E.ITZEXGR_GRADE_DATE IS NULL
                )
            )
      );
EXCEPTION WHEN OTHERS THEN
  NULL;
END p_inserta_itvexgr;

END PKG_INT_BS_GRADE;