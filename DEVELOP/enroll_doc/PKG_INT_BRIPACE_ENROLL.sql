create or replace PACKAGE                                                                             PKG_INT_BRIPACE_ENROLL AS

-- Registra en tabla intermedia SZREDBP datos del periodo capturados desde el trigger de SOBPTRM
    PROCEDURE p_registra_enroll_doc(
         p_action            VARCHAR2,
		p_term_code  VARCHAR2,
        p_crn         VARCHAR2,
        p_pidm         NUMBER,
        p_cat              VARCHAR2,
        p_line        VARCHAR2,
        p_prim_ind    VARCHAR2 -- ind que define el rol
    );

-- Registra desde la tabla intermedia a la tabla de integracion
PROCEDURE p_registra_enroll_doc_int ;

PROCEDURE P_REPROCESA_ENROLLMENT;

FUNCTION f_get_id_nrc (
    p_term_code IN ITZSUPL.ITZSUPL_TERM_CODE%TYPE,
    p_crn       IN ITZSUPL.ITZSUPL_CRN%TYPE
) RETURN ITZSUPL.ITZSUPL_VALOR%TYPE;

-- inserta dato suplementario en SFRSTCR
PROCEDURE p_ins_dato_supl_enroll(p_id number);

-- Obtener el ROL del estudiante
FUNCTION f_get_rol_estudiante (
    p_term_code IN SFRSTCR.SFRSTCR_TERM_CODE%TYPE,
    p_crn       IN SFRSTCR.SFRSTCR_CRN%TYPE
) RETURN VARCHAR2;

PROCEDURE P_INSERT_ITZERST (
    P_ID             IN INTEGRACION.ITZERST.ID%TYPE,
    P_TERM_CODE      IN INTEGRACION.ITZERST.TERM_CODE%TYPE,
    P_PIDM           IN INTEGRACION.ITZERST.PIDM%TYPE,
    P_CRN            IN INTEGRACION.ITZERST.CRN%TYPE,
    P_BUSINESS_LINE  IN INTEGRACION.ITZERST.BUSINESS_LINE%TYPE,
    P_REQUEST        IN INTEGRACION.ITZERST.REQUEST%TYPE,
    P_OP_TYPE        IN INTEGRACION.ITZERST.OP_TYPE%TYPE,
    P_RETRIES        IN INTEGRACION.ITZERST.RETRIES%TYPE DEFAULT 0
);

PROCEDURE p_registra_enroll_est_int;

-- copia los datos de la tabla de enrollment a la tabla visor
PROCEDURE P_COPIA_ITZERST_ITVERST;

-- Elimina enrollment de los alumnos
PROCEDURE p_elimina_enrollment_st;

-- procesa los enrollments de estudiantes, enrollment_int, delete, reprocesa y copia tabla visor
PROCEDURE P_PROCESA_ENROLLMENT_INT;

END PKG_INT_BRIPACE_ENROLL;
/
create or replace PACKAGE BODY                                                                            PKG_INT_BRIPACE_ENROLL AS
    

    PROCEDURE p_registra_enroll_doc(
        p_action            VARCHAR2,
		p_term_code  VARCHAR2,
        p_crn         VARCHAR2,
        p_pidm         NUMBER,
        p_cat              VARCHAR2,
        p_line        VARCHAR2,
        p_prim_ind    VARCHAR2 -- ind que define el rol
    ) IS
    
     v_role_id GTVSDAX.GTVSDAX_COMMENTS%TYPE := NULL;
     v_addic_id  VARCHAR2(50);
     v_id_nrc VARCHAR2(10);
     v_existe_enrl_doc number;
     v_operacion VARCHAR2(1);
    
    BEGIN
    
    -- Se valida que ya tenga un rol_id, id-pers e id_nrc para que pueda hacer el enrollment
    -- Si tiene el check  Y de ind ppal es ONLINE sino es Asistente 
      -- Rol, se extrae de la variable GTVSDAX
      IF p_prim_ind IS NOT NULL THEN
      
        v_role_id :=
            PKG_INT_BRIPACE_PERS.f_get_gtvsdax(
                'ONLINE',
                'ROL_DOC_ON',
                'DEV_INT_BRIGTHSPACE'
            );
            
      ELSE
            v_role_id :=
                PKG_INT_BRIPACE_PERS.f_get_gtvsdax(
                    'ONLINE',
                    'ROL_DOC_AS',
                    'DEV_INT_BRIGTHSPACE'
                );
      END IF;
      -- id_per, se extrae de SPAIDEN datos adicionales LMO
      
      v_addic_id := PKG_INT_BRIPACE_PERS.f_get_inf_ad(p_pidm);
      
--      -- id NRC, se extrae de la tabla intermedia de datos suplementarios
--      BEGIN
--          SELECT ITZSUPL_VALOR 
--            INTO v_id_nrc
--            FROM ITZSUPL 
--           WHERE ITZSUPL_TERM_CODE = p_term_code
--             AND ITZSUPL_CRN = p_crn;
--      EXCEPTION When NO_DATA_FOUND Then
--        v_id_nrc := NULL;
--      END;
      
      v_id_nrc:= PKG_INT_BRIPACE_ENROLL.f_get_id_nrc(p_term_code, p_crn );
  
      dbms_output.put_line('mensaje: v_role_id: '||v_role_id||' v_addic_id: '||v_addic_id||'- v_id_nrc: '||v_id_nrc||'-p_prim_ind:'||p_prim_ind||'-p_action: '||p_action);
  
      IF v_role_id IS NOT NULL and v_addic_id IS NOT NULL AND v_id_nrc IS NOT NULL THEN
        v_operacion:= SUBSTR(p_action,1,1);

       -- IF p_action = 'INSERT' OR p_action = 'UPDATE' THEN
        
        -- validamos si esta el enrollment en tabla intermedia
--            select count (*) into v_existe_enrl_doc
--              from SZREDBP
--              where SZREDBP_TERM_CODE = p_term_code
--                and SZREDBP_CRN = p_crn
--                and SZREDBP_PIDM = p_pidm
--                and SZREDBP_CATEGORY = p_cat
--                and SZREDBP_LINE_NEG = p_line;
                
--           IF v_existe_enrl_doc = 0 THEN
           
                INSERT INTO SZREDBP(
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
                    --
                    SZREDBP_ROLE_ID,
                    SZREDBP_ADDIC_ID,
                    SZREDBP_NRC_ID
                    --
                )
                VALUES (
                    p_term_code,
                    p_crn,
                    p_pidm,
                    p_cat,
                    p_line,
                    'NEW',
                    v_operacion,--'I',
                    1,
                    'SIRASGN',
                    USER,
                    v_role_id,
                    v_addic_id,
                    v_id_nrc
                );
--           END IF;

--    ELSIF p_action = 'UPDATE' THEN
--
--        UPDATE integracion.SZREDBP
--           SET SZREDBP_OPERACION      = 'U',
--               SZREDBP_STATE         = 'NEW',
--               SZREDBP_VERSION       = NVL(SZREDBP_VERSION,0) + 1,
--               SZREDBP_USER_ID       = USER,
--               SZREDBP_ACTIVITY_DATE = SYSDATE
--         WHERE SZREDBP_TERM_CODE = p_term_code
--               AND SZREDBP_CRN= p_crn
--               AND SZREDBP_PIDM = p_pidm
--               AND SZREDBP_CATEGORY = p_cat
--               AND SZREDBP_LINE_NEG = p_line;

        ELSIF p_action = 'DELETE' THEN
          NULL;
--            UPDATE integracion.SZREDBP
--               SET SZREDBP_OPERACION      = v_operacion, --D(delete)
--                   SZREDBP_STATE = 'NEW', -- ESTADO DELETE
--                   SZREDBP_VERSION       = NVL(SZREDBP_VERSION,0) + 1,
--                   SZREDBP_USER_ID       = USER,
--                   SZREDBP_ACTIVITY_DATE = SYSDATE
--             WHERE SZREDBP_TERM_CODE = p_term_code
--               AND SZREDBP_CRN= p_crn
--               AND SZREDBP_PIDM = p_pidm
--               AND SZREDBP_CATEGORY = p_cat
--               AND SZREDBP_LINE_NEG = p_line;
   --     END IF;
        
      END IF;

    -- llama el procedure de integracion. Pobla los datos a la tabla principal itzbgsp
   -- p_registra_enroll_doc_int; 

   END p_registra_enroll_doc;

-- -- Registra desde la tabla intermedia a la tabla de integracion 
    PROCEDURE p_registra_enroll_doc_int IS

        l_json        CLOB;

        -- Configuración Brightspace
        v_url              GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_path_base        GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_path             GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_method           GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_org_type         GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_org_parent       GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_seq              number;
        
        v_tipo_enroll      VARCHAR2(30);

        v_error           VARCHAR2(200);
        v_error_message   VARCHAR2(300);

    BEGIN
        ------------------------------------------------------------------
        -- Configuración
        ------------------------------------------------------------------
--        v_url :=
--            PKG_INT_BRIPACE_TERM.f_get_gtvsdax(
--                'ONLINE',
--                'INSTANAME',
--                'DEV_INT_BRIGTHSPACE'
--            );
--
--        v_path_base :=
--            PKG_INT_BRIPACE_TERM.f_get_gtvsdax(
--                'ONLINE',
--                'ENROL_DOC',
--                'DEV_INT_BRIGTHSPACE'
--            );
--
-- -- como en el path esta incluido el metodo, lo separamos para luego usarlo adecuadamente 
-- -- en los valores del JSON
--
--         v_method:= SUBSTR(v_path_base,1, INSTR(v_path_base, ',') -1);
--
--         v_path:= SUBSTR(v_path_base, INSTR(v_path_base, ',') + 1);
         
        PKG_INT_BRIPACE_UTIL.p_obtener_config_api(
        p_operacion => 'ENROL_DOC', -- Conf variable gtvsdax
        p_url       => v_url,
        p_method    => v_method,
        p_path      => v_path
    );

        ------------------------------------------------------------------
        -- Procesar todos los registros NEW
        ------------------------------------------------------------------
        FOR r IN (
            SELECT ROWID rid,
                   SZREDBP_TERM_CODE,
                   SZREDBP_CRN,
				   SZREDBP_PIDM,
				   SZREDBP_CATEGORY,
				   SZREDBP_LINE_NEG,
                   SZREDBP_STATE,
                   SZREDBP_ID_MAESTRO,
                   TO_NUMBER(SZREDBP_ROLE_ID) SZREDBP_ROLE_ID,
                   TO_NUMBER(SZREDBP_ADDIC_ID) SZREDBP_ADDIC_ID,
                   TO_NUMBER(SZREDBP_NRC_ID) SZREDBP_NRC_ID,
                   SZREDBP_OPERACION --I, U, D = Insert, delete, update
              FROM SZREDBP A
             WHERE SZREDBP_state = 'NEW'--IN ('NEW', 'DEL') -- Nuevos y borrados
        )
        LOOP

            BEGIN
    dbms_output.put_line('mensaje 2');
                ------------------------------------------------------------------
                -- Generar JSON
                ------------------------------------------------------------------
         -- La secuencia es para el state NEW porque el DEL ya tiene seq
        IF r.SZREDBP_STATE = 'NEW' AND r.SZREDBP_OPERACION !='D' THEN
           v_seq := INTEGRACION.SEQ_ITZBGSP.NEXTVAL;
           v_tipo_enroll:= 'ENROLLMENT_TEACHER';
           
           SELECT JSON_ARRAYAGG(
                   JSON_OBJECT(
                       'request' VALUE JSON_OBJECT(
                           'id' VALUE v_seq, 
                           'endpoint' VALUE v_url || v_path,
                           'method' VALUE v_method,
                           'body' VALUE JSON_OBJECT(
                               'OrgUnitId' VALUE r.SZREDBP_NRC_ID, --id_nrc
                               'UserId' VALUE r.SZREDBP_ADDIC_ID, --id user
                               'RoleId' VALUE r.SZREDBP_ROLE_ID, --id rol
                               'SendEnrollmentEmail' VALUE 'false' FORMAT JSON
                           RETURNING CLOB)
                       RETURNING CLOB),
                            
                            'response' VALUE NULL
                            
                   RETURNING CLOB)
               )
        INTO l_json
        FROM dual;
           
        ELSIF r.SZREDBP_STATE = 'NEW' AND r.SZREDBP_OPERACION ='D' THEN
          --  v_seq := r.SZREDBP_ID_MAESTRO;
            v_seq := INTEGRACION.SEQ_ITZBGSP.NEXTVAL;
            v_method:= 'DELETE';
            
            v_tipo_enroll:= 'DELETE_ENROLLMENT_TEACHER'; 
            
            v_path:= v_path || 'users/' || r.SZREDBP_ADDIC_ID || '/orgUnits/' || r.SZREDBP_NRC_ID;
            
             SELECT JSON_ARRAYAGG(
                   JSON_OBJECT(
                       'request' VALUE JSON_OBJECT(
                           'id' VALUE v_seq, 
                           'endpoint' VALUE v_url || v_path,
                           'method' VALUE v_method,
                           'body' VALUE  NULL 
                       RETURNING CLOB),
                            
                            'response' VALUE NULL
                            
                   RETURNING CLOB)
               )
        INTO l_json
        FROM dual;
            
            
        END IF;


                ------------------------------------------------------------------
                -- Registrar solicitud
                ------------------------------------------------------------------
                INSERT INTO integracion.itzbgsp (
                    id,
                    business_line,
                    request,
                    response,
                    create_date,
                    request_date,
                    response_date,
                    op_type,
                    status
                )
                VALUES (
                    v_seq,
                    'ONLINE',
                    l_json,
                    NULL,
                    SYSDATE,
                    SYSDATE,
                    NULL,
                    v_tipo_enroll,
                    'PENDING'
                );
    dbms_output.put_line('mensaje 4');
                ------------------------------------------------------------------
                -- Actualizar estado en SZREDBP o borra si la operacion es DELETE
                ------------------------------------------------------------------
                 v_error_message :=
                    'El docente ' ||
                    GB_COMMON.F_GET_ID(r.SZREDBP_PIDM)  ||
                    ' ejecutó ' ||
                    v_tipo_enroll ||
                    ' correctamente';
                
           IF r.SZREDBP_STATE = 'NEW' AND r.SZREDBP_OPERACION !='D' THEN
                UPDATE SZREDBP
                   SET SZREDBP_state = 'SEND',
                       SZREDBP_ID_MAESTRO= v_seq
                 WHERE ROWID = r.rid;
                 
          ELSIF r.SZREDBP_STATE = 'NEW' AND r.SZREDBP_OPERACION ='D' THEN-- Operacion DEL
--            DELETE SZREDBP
--             WHERE ROWID = r.rid;
            UPDATE SZREDBP
                   SET SZREDBP_state = 'SEND',
                       SZREDBP_STATE_DET = r.SZREDBP_STATE||' operac: '||r.SZREDBP_OPERACION,
                       SZREDBP_ID_MAESTRO= v_seq
                 WHERE ROWID = r.rid;
             
             
          END IF;
          
          PKG_INT_BRIPACE_UTIL.p_registra_error_log(
                    p_business_line => 'ONLINE',
                    p_op_type       => v_tipo_enroll,
                    p_id_maestro    => v_seq,
                    p_term_code     => r.SZREDBP_TERM_CODE,
                    p_ptrm_code     => NULL,
                    p_crn            => r.SZREDBP_CRN,
                    p_pidm          => r.SZREDBP_PIDM,
                    p_state         => v_tipo_enroll||' OK',
                    p_error_code    => 'OK',
                    p_error_message => v_error_message
                );

            EXCEPTION
                WHEN OTHERS THEN
                   v_error := sqlerrm;

                    UPDATE SZREDBP
                       SET SZREDBP_state = 'FAIL',
                         SZREDBP_STATE_DET = v_error
                     WHERE ROWID = r.rid;

 END;

        END LOOP;


    END p_registra_enroll_doc_int;
    
-- PROC REGISTRA ENROLL ESTUDIANTE
PROCEDURE p_registra_enroll_est_int --(   p_periodo IN VARCHAR2)
IS

    v_id_itzerst   INTEGRACION.ITZERST.ID%TYPE;
    v_adic_id      GORADID.GORADID_ADDITIONAL_ID%TYPE;
    v_id_nrc       ITZSUPL.ITZSUPL_VALOR%TYPE;
    v_request      CLOB;
    v_periodo          VARCHAR2(2);
    v_url              GTVSDAX.GTVSDAX_COMMENTS%TYPE;
    v_path_base        GTVSDAX.GTVSDAX_COMMENTS%TYPE;
    v_path             GTVSDAX.GTVSDAX_COMMENTS%TYPE;
    v_method           GTVSDAX.GTVSDAX_COMMENTS%TYPE;
    v_tipo_enroll      VARCHAR2(30):= 'CREATE_ENRROLLMENT';
    v_error_message   VARCHAR2(300);

BEGIN
  -- Periodo ONLINE
   v_periodo := PKG_INT_BRIPACE_TERM.F_GET_GTVSDAX(
                     'ONLINE',
                     'PERIODO',
                     'DEV_INT_BRIGTHSPACE'
                 );
    
                 
     PKG_INT_BRIPACE_UTIL.p_obtener_config_api(
        p_operacion => 'ENROL_DOC', -- Conf variable gtvsdax, URL enrollment igual que el del docente
        p_url       => v_url,
        p_method    => v_method,
        p_path      => v_path
    );

    FOR r IN (
        SELECT DISTINCT
               s.SFRSTCR_TERM_CODE,
               s.SFRSTCR_PIDM,
               s.SFRSTCR_CRN,
               PKG_INT_BRIPACE_ENROLL.f_get_rol_estudiante(SFRSTCR_TERM_CODE,SFRSTCR_CRN ) rol,
               s.SFRSTCR_ACTIVITY_DATE
          FROM SFRSTCR s, STVRSTS v
         WHERE SUBSTR(s.SFRSTCR_TERM_CODE, 5, 2) = v_periodo
           AND s.SFRSTCR_RSTS_CODE = v.STVRSTS_CODE
           AND STVRSTS_VOICE_TYPE = 'R'

           -- Tiene información adicional
           AND PKG_INT_BRIPACE_PERS.F_EXISTE_INF_AD(
                   s.SFRSTCR_PIDM
               ) = 'Y'
           -- Tiene ID NRC
           AND PKG_INT_BRIPACE_ENROLL.f_get_id_nrc(
                   s.SFRSTCR_TERM_CODE,
                   s.SFRSTCR_CRN
               ) IS NOT NULL
           -- que no exista en la tabla de integración.
            -- OJO: Validar el status si se deja asi o incluir los FAILED
           AND NOT EXISTS(
            SELECT 1 FROM INTEGRACION.ITZERST x 
             WHERE x.TERM_CODE = s.SFRSTCR_TERM_CODE
               AND x.PIDM = s.SFRSTCR_PIDM
               AND x.CRN = s.SFRSTCR_CRN
            ) 
        ORDER BY s.SFRSTCR_ACTIVITY_DATE
    )
    LOOP

        ------------------------------------------------------------
        -- Obtener ID NRC
        ------------------------------------------------------------
        v_id_nrc :=
            PKG_INT_BRIPACE_ENROLL.f_get_id_nrc(
                p_term_code => r.SFRSTCR_TERM_CODE,
                p_crn       => r.SFRSTCR_CRN
            );

        ------------------------------------------------------------
        -- Obtener ID adicional del alumno
        ------------------------------------------------------------
        v_adic_id :=
            PKG_INT_BRIPACE_PERS.f_get_inf_ad(
                p_pidm => r.SFRSTCR_PIDM
            );

        ------------------------------------------------------------
        -- Generar ID de ITZERST
        ------------------------------------------------------------
        v_id_itzerst :=
            INTEGRACION.SEQ_ITZERST.NEXTVAL;

        ------------------------------------------------------------
        -- Construir REQUEST
        ------------------------------------------------------------
        SELECT JSON_ARRAY(
                   JSON_OBJECT(
                       'request' VALUE JSON_OBJECT(
                           'id' VALUE v_id_itzerst,
                           'endpoint' VALUE  v_url || v_path,
                           'method' VALUE v_method,
                           'body' VALUE JSON_OBJECT(
                               'OrgUnitId' VALUE TO_NUMBER(v_id_nrc),
                               'UserId' VALUE TO_NUMBER(v_adic_id),
                               'RoleId' VALUE TO_NUMBER(r.rol),
                               'SendEnrollmentEmail' VALUE 'false' FORMAT JSON
                           )
                       ),
                       'response' VALUE NULL
                   )
                   RETURNING CLOB
               )
          INTO v_request
          FROM DUAL;

        ------------------------------------------------------------
        -- Insertar en ITZERST
        ------------------------------------------------------------
--        INSERT INTO INTEGRACION.ITZERST (
--            ID,
--            TERM_CODE,
--            PIDM,
--            CRN,
--            BUSINESS_LINE,
--            REQUEST,
--            RESPONSE,
--            CREATE_DATE,
--            REQUEST_DATE,
--            RESPONSE_DATE,
--            OP_TYPE,
--            STATUS,
--            STATUS_RESPONSE
--        )
--        VALUES (
--            v_id_itzerst,
--            r.SFRSTCR_TERM_CODE,
--            r.SFRSTCR_PIDM,
--            r.SFRSTCR_CRN,
--            'ONLINE',
--            v_request,
--            NULL,
--            SYSTIMESTAMP,
--            NULL,
--            NULL,
--            v_tipo_enroll,
--            'PENDING',
--            NULL
--        );
--        
              P_INSERT_ITZERST(
                P_ID            => V_ID_ITZERST,
                P_TERM_CODE     => R.SFRSTCR_TERM_CODE,
                P_PIDM          => R.SFRSTCR_PIDM,
                P_CRN           => R.SFRSTCR_CRN,
                P_BUSINESS_LINE => 'ONLINE',
                P_REQUEST       => V_REQUEST,
                P_OP_TYPE       => V_TIPO_ENROLL
            );

        

    END LOOP;
    
    EXCEPTION WHEN OTHERS THEN
       v_error_message:= sqlerrm;
      PKG_INT_BRIPACE_UTIL.p_registra_error_log(
                    p_business_line => 'ONLINE',
                    p_op_type       => v_tipo_enroll,
                    p_id_maestro    => v_id_itzerst,
                    p_term_code     => null,
                    p_ptrm_code     => NULL,
                    p_crn            => null,
                    p_pidm          => null,
                    p_state         => v_tipo_enroll||' ER',
                    p_error_code    => 'ER',
                    p_error_message => v_error_message
                );

END p_registra_enroll_est_int;

PROCEDURE p_elimina_enrollment_st
IS
    ------------------------------------------------------------------
    -- Variables
    ------------------------------------------------------------------
    v_id_itzerst  INTEGRACION.ITZERST.ID%TYPE;
    v_url         VARCHAR2(1000);
    v_method      VARCHAR2(20);
    v_path        VARCHAR2(2000);
    v_tipo_enroll INTEGRACION.ITZERST.OP_TYPE%TYPE;
    v_request     CLOB;
    v_periodo          VARCHAR2(2);

BEGIN
   -- Periodo ONLINE
   v_periodo := PKG_INT_BRIPACE_TERM.F_GET_GTVSDAX(
                     'ONLINE',
                     'PERIODO',
                     'DEV_INT_BRIGTHSPACE'
                 );
    ------------------------------------------------------------------
    -- 1. Consultar matrículas que deben eliminarse de Brightspace
    ------------------------------------------------------------------
    FOR r IN (
        SELECT DISTINCT
               s.SFRSTCR_TERM_CODE AS TERM_CODE,
               s.SFRSTCR_PIDM      AS PIDM,
               s.SFRSTCR_CRN       AS CRN,
            --   s.SFRSTCR_ACTIVITY_DATE AS ACTIVITY_DATE,
            --   v.STVRSTS_VOICE_TYPE AS VOICE_TYPE,

               PKG_INT_BRIPACE_PERS.f_get_inf_ad(
                   s.SFRSTCR_PIDM
               ) AS ADIC_ID,

               PKG_INT_BRIPACE_ENROLL.f_get_id_nrc(
                   s.SFRSTCR_TERM_CODE,
                   s.SFRSTCR_CRN
               ) AS NRC_ID

          FROM SFRSTCR s
          JOIN STVRSTS v
            ON v.STVRSTS_CODE = s.SFRSTCR_RSTS_CODE

          JOIN INTEGRACION.ITZERST z
            ON z.TERM_CODE = s.SFRSTCR_TERM_CODE
           AND z.PIDM      = s.SFRSTCR_PIDM
           AND z.CRN       = s.SFRSTCR_CRN
           AND z.STATUS_RESPONSE    = 'COMPLETED_OK'
           AND NOT EXISTS (SELECT 1 FROM   ITZERST x 
                            where x.TERM_CODE = s.SFRSTCR_TERM_CODE
                              and x.PIDM = s.SFRSTCR_PIDM
                              and x.CRN = s.SFRSTCR_CRN
                              and x.OP_TYPE ='DELETE_ENROLLMENT_ST' )

         WHERE SUBSTR(s.SFRSTCR_TERM_CODE, 5, 2) = v_periodo
           AND v.STVRSTS_VOICE_TYPE = 'D'
        UNION
        --Eliminacion fisica
        SELECT SZRSFBP_TERM_CODE, SZRSFBP_PIDM, SZRSFBP_CRN,
        PKG_INT_BRIPACE_PERS.f_get_inf_ad(
                   a.SZRSFBP_PIDM
               ) AS ADIC_ID,

               PKG_INT_BRIPACE_ENROLL.f_get_id_nrc(
                   a.SZRSFBP_TERM_CODE,
                   a.SZRSFBP_CRN
               ) AS NRC_ID
        FROM INTEGRACION.SZRSFBP a
        WHERE NOT EXISTS (SELECT 1 FROM   ITZERST x 
                            where x.TERM_CODE = a.SZRSFBP_TERM_CODE
                              and x.PIDM = a.SZRSFBP_PIDM
                              and x.CRN = a.SZRSFBP_CRN
                              and x.OP_TYPE ='DELETE_ENROLLMENT_ST' )
    )
    LOOP

        ------------------------------------------------------------------
        -- 2. Validar identificadores necesarios para el endpoint
        ------------------------------------------------------------------
        IF r.ADIC_ID IS NOT NULL
           AND r.NRC_ID IS NOT NULL
        THEN

            ------------------------------------------------------------------
            -- 3. Obtener configuración de la API
            ------------------------------------------------------------------
            PKG_INT_BRIPACE_UTIL.p_obtener_config_api(
                p_operacion => 'ENROL_DOC',
                p_url       => v_url,
                p_method    => v_method,
                p_path      => v_path
            );

            ------------------------------------------------------------------
            -- 4. Preparar operación DELETE
            ------------------------------------------------------------------
            v_id_itzerst := INTEGRACION.SEQ_ITZERST.NEXTVAL;

            v_method      := 'DELETE';
            v_tipo_enroll := 'DELETE_ENROLLMENT_ST';

            v_path := v_path
                      || 'users/'
                      || r.ADIC_ID
                      || '/orgUnits/'
                      || r.NRC_ID;

            ------------------------------------------------------------------
            -- 5. Generar JSON de la solicitud
            ------------------------------------------------------------------
        
             SELECT JSON_ARRAYAGG(
                   JSON_OBJECT(
                       'request' VALUE JSON_OBJECT(
                           'id' VALUE v_id_itzerst, 
                           'endpoint' VALUE v_url || v_path,
                           'method' VALUE v_method,
                           'body' VALUE  NULL 
                       RETURNING CLOB),
                            'response' VALUE NULL     
                           RETURNING CLOB)
                       )
                INTO V_REQUEST
                FROM dual;

            ------------------------------------------------------------------
            -- 6. Insertar solicitud en la tabla de integración
            ------------------------------------------------------------------
            P_INSERT_ITZERST(
                P_ID            => V_ID_ITZERST,
                P_TERM_CODE     => R.TERM_CODE,
                P_PIDM          => R.PIDM,
                P_CRN           => R.CRN,
                P_BUSINESS_LINE => 'ONLINE',
                P_REQUEST       => V_REQUEST,
                P_OP_TYPE       => V_TIPO_ENROLL
            );
            
            COMMIT;

        END IF;

    END LOOP;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;

END p_elimina_enrollment_st;

PROCEDURE p_ins_dato_supl_enroll(p_id number)
IS
    -- ROWID del registro de GORSDAV.
    -- NULL porque solo procesamos inscripciones sin dato suplementario.
    r_gorsdav_rowid ROWID := NULL;

    v_total_procesados NUMBER := 0;
    
    v_periodo varchar2(2);
    
    

BEGIN
     v_periodo := PKG_INT_BRIPACE_TERM.F_GET_GTVSDAX(
                     'ONLINE',
                     'PERIODO',
                     'DEV_INT_BRIGTHSPACE'
                 );

    FOR i IN (
        SELECT DISTINCT
               z.id AS valor_id,
               z.OP_TYPE,
               GP_GOKSDIF.F_GET_PK(
                   'SFRSTCR',
                   s.ROWID
               ) AS r_pk_parenttab
          FROM SFRSTCR s
          JOIN STVRSTS v
            ON v.STVRSTS_CODE = s.SFRSTCR_RSTS_CODE
          JOIN ITZERST z
            ON z.TERM_CODE = s.SFRSTCR_TERM_CODE
           AND z.PIDM      = s.SFRSTCR_PIDM
           AND z.CRN       = s.SFRSTCR_CRN
         WHERE SUBSTR(s.SFRSTCR_TERM_CODE, 5, 2) = v_periodo
           AND v.STVRSTS_VOICE_TYPE = 'R'
           AND z.STATUS = 'PROCESSED_OK'
           AND z.OP_TYPE = 'CREATE_ENRROLLMENT'
           AND Z.ID = p_id

           -- Solo inscripciones sin el dato suplementario
           AND NOT EXISTS (
                   SELECT 1
                     FROM GORSDAV a
                    WHERE a.GORSDAV_TABLE_NAME = 'SFRSTCR'
                      AND a.GORSDAV_ATTR_NAME = 'ID_ENRROLMENT'
                      AND a.GORSDAV_DISC = '1'
                      AND a.GORSDAV_PK_PARENTTAB =
                          GP_GOKSDIF.F_GET_PK(
                              'SFRSTCR',
                              s.ROWID
                          )
               )
    )
    LOOP

        -- No existe un registro previo en GORSDAV.
        r_gorsdav_rowid := NULL;

        -- Inserta el dato suplementario original de Banner.
        GP_GOKSDIF.P_SET_ATTRIBUTE(
            'SFRSTCR',
            'ID_ENRROLMENT',
            '1',
            i.r_pk_parenttab,
            r_gorsdav_rowid,
            'VARCHAR2',
            i.valor_id
        );

    PKG_INT_BRIPACE_UTIL.P_ACTUALIZA_ESTADO_ITZERST( p_id, i.OP_TYPE, 'COMPLETED_OK');
    
    END LOOP;
    
   
    
    commit;

EXCEPTION
    WHEN OTHERS THEN
        NULL;
END p_ins_dato_supl_enroll;

-- reprocesa los registros con estado fallido
PROCEDURE P_REPROCESA_ENROLLMENT
IS
    ------------------------------------------------------------------
    -- Configuración
    ------------------------------------------------------------------
    V_MAX_RETRIES       NUMBER;

    ------------------------------------------------------------------
    -- Datos de la matrícula
    ------------------------------------------------------------------
    V_ID_ITZERST        ITZERST.ID%TYPE;
    V_NEW_ID_ITZERST    ITZERST.ID%TYPE;

    V_ID_NRC            VARCHAR2(100);
    V_ADIC_ID           VARCHAR2(100);

    V_ID_NRC_ANT        VARCHAR2(100);
    V_ADIC_ID_ANT       VARCHAR2(100);

    V_ENDPOINT          VARCHAR2(1000);
    V_METHOD            VARCHAR2(20);
    V_REQUEST           CLOB;

    V_PK                VARCHAR2(4000);
    V_ROWID             ROWID;
    V_RETRIES           NUMBER;
    V_ROL               NUMBER;

    V_TIPO_ENROLL       VARCHAR2(50) := 'CREATE_ENRROLLMENT';

    ------------------------------------------------------------------
    -- Último registro por matrícula:
    -- se selecciona primero el más reciente y después se valida
    -- si su resultado fue PROCESSING_KO.
    ------------------------------------------------------------------
    CURSOR C_ENROLLMENT IS
        SELECT ID,
               TERM_CODE,
               PIDM,
               CRN,
               BUSINESS_LINE,
               OP_TYPE,
               REQUEST,RESPONSE,
               RETRIES
          FROM (
                SELECT I.ID,
                       I.TERM_CODE,
                       I.PIDM,
                       I.CRN,
                       I.BUSINESS_LINE,
                       I.OP_TYPE,
                       I.REQUEST,I.RESPONSE,
                       I.RETRIES,
                       I.STATUS,
                       ROW_NUMBER() OVER (
                           PARTITION BY I.TERM_CODE, I.PIDM, I.CRN
                           ORDER BY I.ID DESC
                       ) AS RN
                  FROM ITZERST I
                 WHERE I.OP_TYPE = 'CREATE_ENRROLLMENT'
               )
         WHERE RN = 1
            AND STATUS = 'PROCESSED_KO';--MER TMP URGENTE

BEGIN
    ------------------------------------------------------------------
    -- Obtener el máximo de reintentos configurado en GTVSDAX
    ------------------------------------------------------------------
    V_MAX_RETRIES :=
        TO_NUMBER(
            PKG_INT_BRIPACE_PERS.F_GET_GTVSDAX(
                'ONLINE',
                'N_MAX_REI',
                'DEV_INT_BRIGTHSPACE'
            )
        );

    ------------------------------------------------------------------
    -- Procesar matrículas fallidas
    ------------------------------------------------------------------
    FOR R IN C_ENROLLMENT LOOP

        V_ID_ITZERST := R.ID;
        V_RETRIES    := NVL(R.RETRIES, 0)+1;

        --------------------------------------------------------------
        -- Obtener los identificadores actuales del NRC en Banner
        --------------------------------------------------------------
        BEGIN
            SELECT ROWID
              INTO V_ROWID
              FROM SSBSECT
             WHERE SSBSECT_TERM_CODE = R.TERM_CODE
               AND SSBSECT_CRN       = R.CRN;

            V_PK := GP_GOKSDIF.F_GET_PK(
                        'SSBSECT',
                        V_ROWID
                    );

            V_ID_NRC := GP_GOKSDIF.F_GET_SD_TEXT(
                            p_table_name => 'SSBSECT',
                            p_attr_name  => 'ID_LMS_BRIGHTSPACE',
                            p_pk         => V_PK,
                            p_disc       => '1',
                            p_default    => NULL
                        );

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                V_ID_NRC := NULL;
        END;

        --------------------------------------------------------------
        -- Obtener el identificador actual del usuario en Brightspace
        --------------------------------------------------------------
        V_ADIC_ID :=
            PKG_INT_BRIPACE_PERS.F_GET_INF_AD(R.PIDM);

        --------------------------------------------------------------
        -- Obtener los identificadores de la solicitud anterior
        --------------------------------------------------------------
        V_ID_NRC_ANT :=
		JSON_VALUE(
			R.RESPONSE,
			'$[0].response.body.OrgUnitId'
			RETURNING VARCHAR2(100)
			NULL ON ERROR
		);


        V_ADIC_ID_ANT :=
			JSON_VALUE(
				R.RESPONSE,
				'$[0].response.body.UserId'
				RETURNING VARCHAR2(100)
				NULL ON ERROR
			);
			
		V_ROL :=
			JSON_VALUE(
				R.RESPONSE,
				'$[0].response.body.RoleId'
				RETURNING NUMBER
				NULL ON ERROR
			);
       

            ----------------------------------------------------------
            -- Los identificadores no cambiaron:
            -- reintentar si aún quedan intentos disponibles.
            ----------------------------------------------------------
    IF V_RETRIES <= V_MAX_RETRIES THEN
      -- Comparar identificadores anteriores y actuales
      IF V_ID_NRC_ANT = NVL(V_ID_NRC,'0') AND V_ADIC_ID_ANT = NVL(V_ADIC_ID,'0') THEN
            
                UPDATE ITZERST
                   SET STATUS = 'PENDING',
                       retries= V_RETRIES
                 WHERE ID = R.ID;
                 
                IF V_ID_NRC IS NULL OR V_ADIC_ID IS NULL THEN

                    PKG_INT_BRIPACE_UTIL.P_REGISTRA_ERROR_LOG(
                        p_business_line => R.BUSINESS_LINE,
                        p_op_type       => R.OP_TYPE,
                        p_term_code     => R.TERM_CODE,
                        p_ptrm_code     => NULL,
                        p_error_code    => 'ENROLLMENT_IDS_NOT_FOUND',
                        p_error_message => 'No se reprocesa la matrícula: ' ||
                                           'no se encontraron los identificadores ' ||
                                           'actuales de Brightspace. PIDM: ' ||
                                           R.PIDM || ', NRC: ' || R.CRN
                    );
                END IF;

      ELSE
      ----------------------------------------------------------
            -- Cambió el OrgUnitId o el UserId:
            -- generar una nueva solicitud de integración.
            ----------------------------------------------------------

            ----------------------------------------------------------
            -- Recuperar endpoint y método de la solicitud anterior
            ----------------------------------------------------------
            V_ENDPOINT :=
                JSON_VALUE(
                    R.REQUEST,
                    '$[0].request.endpoint'
                    RETURNING VARCHAR2(1000)
                    NULL ON ERROR
                );

            V_METHOD :=
                JSON_VALUE(
                    R.REQUEST,
                    '$[0].request.method'
                    RETURNING VARCHAR2(20)
                    NULL ON ERROR
                );


            ----------------------------------------------------------
            -- Generar el ID de la nueva solicitud
            ----------------------------------------------------------
            V_NEW_ID_ITZERST := INTEGRACION.SEQ_ITZERST.NEXTVAL;

            ----------------------------------------------------------
            -- Construir REQUEST con el formato utilizado actualmente
            ----------------------------------------------------------
            SELECT JSON_ARRAY(
                       JSON_OBJECT(
                           'request' VALUE JSON_OBJECT(
                               'id' VALUE V_NEW_ID_ITZERST,
                               'endpoint' VALUE V_ENDPOINT,
                               'method' VALUE V_METHOD,
                               'body' VALUE JSON_OBJECT(
                                   'OrgUnitId' VALUE TO_NUMBER(V_ID_NRC),
                                   'UserId' VALUE TO_NUMBER(V_ADIC_ID),
                                   'RoleId' VALUE V_ROL,
                                   'SendEnrollmentEmail' VALUE
                                       'false' FORMAT JSON
                               )
                           ),
                           'response' VALUE NULL
                       )
                       RETURNING CLOB
                   )
              INTO V_REQUEST
              FROM DUAL;

            ----------------------------------------------------------
            -- Insertar nueva solicitud mediante el proc
            ----------------------------------------------------------
            P_INSERT_ITZERST(
                P_ID            => V_NEW_ID_ITZERST,
                P_TERM_CODE     => R.TERM_CODE,
                P_PIDM          => R.PIDM,
                P_CRN           => R.CRN,
                P_BUSINESS_LINE => R.BUSINESS_LINE,
                P_REQUEST       => V_REQUEST,
                P_OP_TYPE       => V_TIPO_ENROLL,
                P_RETRIES       => V_RETRIES
            );

        END IF;


    ELSE
      
                ------------------------------------------------------
                -- Se alcanzó el máximo de reintentos.
                ------------------------------------------------------
                PKG_INT_BRIPACE_UTIL.P_REGISTRA_ERROR_LOG_UK(
                    p_business_line => R.BUSINESS_LINE,
                    p_op_type       => R.OP_TYPE,
                    p_term_code     => R.TERM_CODE,
                    p_crn           => R.CRN,
                    p_pidm          => R.PIDM,
                    p_error_code    => 'MAX_RETRIES_EXCEEDED',
                    p_error_message => 'No se reprocesa la matrícula ' ||
                                       'por alcanzar el máximo de reintentos. ' ||
                                       'PIDM: ' || R.PIDM ||
                                       ', NRC: ' || R.CRN ||
                                       ', Reintentos: ' || V_RETRIES ||
                                       ', Máximo permitido: ' ||
                                       V_MAX_RETRIES
                );

    END IF;

 

    END LOOP;

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
         PKG_INT_BRIPACE_UTIL.P_REGISTRA_ERROR_LOG(
                    p_business_line => 'ON',
                    p_op_type       => NULL, --OJO MER TMP
                    p_term_code     => NULL,
                    p_ptrm_code     => NULL,
                    p_error_code    => 'ERR_REPROCESAMIENTO',
                    p_error_message => 'No se reprocesa la matrícula ' 
                );

END P_REPROCESA_ENROLLMENT;


-- me da el ID del NRC de acuerdo al periodo
FUNCTION f_get_id_nrc (
    p_term_code IN ITZSUPL.ITZSUPL_TERM_CODE%TYPE,
    p_crn       IN ITZSUPL.ITZSUPL_CRN%TYPE
) RETURN ITZSUPL.ITZSUPL_VALOR%TYPE
IS
    v_id_nrc ITZSUPL.ITZSUPL_VALOR%TYPE;
BEGIN

    SELECT ITZSUPL_VALOR
      INTO v_id_nrc
      FROM ITZSUPL
     WHERE ITZSUPL_TERM_CODE = p_term_code
       AND ITZSUPL_CRN       = p_crn;

    RETURN v_id_nrc;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
END f_get_id_nrc;


-- Obtener el ROL del estudiante

FUNCTION f_get_rol_estudiante (
     p_term_code IN SFRSTCR.SFRSTCR_TERM_CODE%TYPE,
     p_crn       IN SFRSTCR.SFRSTCR_CRN%TYPE
) RETURN VARCHAR2
IS
    v_existe_y NUMBER;
    v_existe_n NUMBER;
    v_role_id_est      GTVSDAX.GTVSDAX_COMMENTS%TYPE;
    v_role_id_lect     GTVSDAX.GTVSDAX_COMMENTS%TYPE;
BEGIN
      -- rol de estudiante         
     v_role_id_est :=
            PKG_INT_BRIPACE_PERS.f_get_gtvsdax(
                'ONLINE',
                'ROL_EST_ON',
                'DEV_INT_BRIGTHSPACE'
            );
            
    -- rol de lectura del estudiante
     v_role_id_lect :=
            PKG_INT_BRIPACE_PERS.f_get_gtvsdax(
                'ONLINE',
                'ROL_EST_LT',
                'DEV_INT_BRIGTHSPACE'
            );
            
       
     SELECT DECODE(SSRBLCK_OPT_IND, 'Y',COUNT(*)) EXISTE_Y,
          DECODE(SSRBLCK_OPT_IND, 'N',COUNT(*)) EXISTE_N
      INTO v_existe_y, v_existe_n
      FROM SSRBLCK
     WHERE SSRBLCK_TERM_CODE = p_term_code
       AND SSRBLCK_CRN       = p_crn
       GROUP BY SSRBLCK_OPT_IND;

    IF v_existe_y > 0 THEN
        RETURN v_role_id_est; -- ROL ESTUDIANTE
        
    ELSIF v_existe_n > 0 THEN
        RETURN v_role_id_lect; -- ROL LECTOR
    END IF;
    
    EXCEPTION WHEN OTHERS THEN
        RETURN v_role_id_est; -- SINO TIENE BLOQUE, ROL ESTUDIANTE
    
END f_get_rol_estudiante;



 PROCEDURE P_INSERT_ITZERST (
    P_ID             IN INTEGRACION.ITZERST.ID%TYPE,
    P_TERM_CODE      IN INTEGRACION.ITZERST.TERM_CODE%TYPE,
    P_PIDM           IN INTEGRACION.ITZERST.PIDM%TYPE,
    P_CRN            IN INTEGRACION.ITZERST.CRN%TYPE,
    P_BUSINESS_LINE  IN INTEGRACION.ITZERST.BUSINESS_LINE%TYPE,
    P_REQUEST        IN INTEGRACION.ITZERST.REQUEST%TYPE,
    P_OP_TYPE        IN INTEGRACION.ITZERST.OP_TYPE%TYPE,
    P_RETRIES        IN INTEGRACION.ITZERST.RETRIES%TYPE DEFAULT 0
)
IS
BEGIN
    MERGE INTO INTEGRACION.ITZERST T
    USING (
        SELECT
            P_ID            AS ID,
            P_TERM_CODE     AS TERM_CODE,
            P_PIDM          AS PIDM,
            P_CRN           AS CRN,
            P_BUSINESS_LINE AS BUSINESS_LINE,
            P_REQUEST       AS REQUEST,
            P_OP_TYPE       AS OP_TYPE,
            P_RETRIES       AS RETRIES
            
        FROM DUAL
    ) S
    ON (T.ID = S.ID)

    WHEN MATCHED THEN
        UPDATE SET
            T.TERM_CODE       = S.TERM_CODE,
            T.PIDM            = S.PIDM,
            T.CRN             = S.CRN,
            T.BUSINESS_LINE   = S.BUSINESS_LINE,
            T.REQUEST         = S.REQUEST,
            T.OP_TYPE         = S.OP_TYPE,
            T.STATUS          = 'PENDING',
            T.STATUS_RESPONSE = NULL,
            T.RETRIES         = RETRIES
            
    WHEN NOT MATCHED THEN
        INSERT (
            ID,
            TERM_CODE,
            PIDM,
            CRN,
            BUSINESS_LINE,
            REQUEST,
            RESPONSE,
            CREATE_DATE,
            REQUEST_DATE,
            RESPONSE_DATE,
            OP_TYPE,
            STATUS,
            STATUS_RESPONSE,
            RETRIES
            
        )
        VALUES (
            S.ID,
            S.TERM_CODE,
            S.PIDM,
            S.CRN,
            S.BUSINESS_LINE,
            S.REQUEST,
            NULL,
            SYSTIMESTAMP,
            NULL,
            NULL,
            S.OP_TYPE,
            'PENDING',
            NULL,
            S.RETRIES
        );
END P_INSERT_ITZERST;

PROCEDURE P_COPIA_ITZERST_ITVERST
IS
BEGIN

    MERGE INTO PRGNREP.ITVERST b
    USING (
        SELECT
            a.ID,
            a.TERM_CODE,
            a.PIDM,
            GB_COMMON.F_GET_ID(a.PIDM) AS ID_STUDENT,
            a.CRN,
            a.BUSINESS_LINE,
            a.REQUEST,
            a.RESPONSE,
            a.CREATE_DATE,
            a.REQUEST_DATE,
            a.RESPONSE_DATE,
            a.OP_TYPE,
            a.STATUS,
            a.STATUS_RESPONSE,
            a.RETRIES
        FROM ITZERST a
    ) a
    ON (b.ID = a.ID)

    WHEN MATCHED THEN
        UPDATE SET
            b.TERM_CODE      = a.TERM_CODE,
            b.PIDM           = a.PIDM,
            b.ID_STUDENT     = a.ID_STUDENT,
            b.CRN            = a.CRN,
            b.BUSINESS_LINE  = a.BUSINESS_LINE,
            b.REQUEST        = a.REQUEST,
            b.RESPONSE       = a.RESPONSE,
            b.CREATE_DATE    = a.CREATE_DATE,
            b.REQUEST_DATE   = a.REQUEST_DATE,
            b.RESPONSE_DATE  = a.RESPONSE_DATE,
            b.OP_TYPE        = a.OP_TYPE,
            b.STATUS         = a.STATUS,
            b.STATUS_RESPONSE = a.STATUS_RESPONSE,
            b.RETRIES        = a.RETRIES

    WHEN NOT MATCHED THEN
        INSERT (
            ID,
            TERM_CODE,
            PIDM,
            ID_STUDENT,
            CRN,
            BUSINESS_LINE,
            REQUEST,
            RESPONSE,
            CREATE_DATE,
            REQUEST_DATE,
            RESPONSE_DATE,
            OP_TYPE,
            STATUS,
            STATUS_RESPONSE,
            RETRIES
        )
        VALUES (
            a.ID,
            a.TERM_CODE,
            a.PIDM,
            a.ID_STUDENT,
            a.CRN,
            a.BUSINESS_LINE,
            a.REQUEST,
            a.RESPONSE,
            a.CREATE_DATE,
            a.REQUEST_DATE,
            a.RESPONSE_DATE,
            a.OP_TYPE,
            a.STATUS,
            a.STATUS_RESPONSE,
            a.RETRIES
        );

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;

END P_COPIA_ITZERST_ITVERST;

PROCEDURE P_PROCESA_ENROLLMENT_INT
IS
BEGIN
    ------------------------------------------------------------
    -- 1. Registrar matrículas para integración
    ------------------------------------------------------------
    BEGIN
        P_REGISTRA_ENROLL_EST_INT;
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END;

    ------------------------------------------------------------
    -- 2. Eliminar matrículas
    ------------------------------------------------------------
    BEGIN
        P_ELIMINA_ENROLLMENT_ST;
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END;

    ------------------------------------------------------------
    -- 3. Reprocesar matrículas fallidas
    ------------------------------------------------------------
    BEGIN
        P_REPROCESA_ENROLLMENT;
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END;

    ------------------------------------------------------------
    -- 4. Copiar registros de ITZERST a ITVERST
    ------------------------------------------------------------
    BEGIN
        P_COPIA_ITZERST_ITVERST;
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END;

END P_PROCESA_ENROLLMENT_INT;



END PKG_INT_BRIPACE_ENROLL;
/