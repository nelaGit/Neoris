create or replace PACKAGE BODY                    PKG_INT_BRIPACE_ENROLL AS
    

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
      -- id_per, se extrae de SPAIDEN datos adicionales 
      BEGIN
         SELECT MAX(GORADID_ADDITIONAL_ID)
          INTO v_addic_id
          FROM  GORADID
          WHERE GORADID_PIDM = p_pidm
            AND GORADID_ADID_CODE= 'LMBO'; 
      EXCEPTION When NO_DATA_FOUND Then
        v_addic_id := NULL;
      END;
      
      -- id NRC, se extrae de la tabla intermedia de datos suplementarios
      BEGIN
          SELECT ITZSUPL_VALOR 
            INTO v_id_nrc
            FROM ITZSUPL 
           WHERE ITZSUPL_TERM_CODE = p_term_code
             AND ITZSUPL_CRN = p_crn;
      EXCEPTION When NO_DATA_FOUND Then
        v_id_nrc := NULL;
      END;
  
      IF v_role_id IS NOT NULL and v_addic_id IS NOT NULL AND v_id_nrc IS NOT NULL THEN

        IF p_action = 'INSERT' THEN
        
        -- validamos si esta el enrollment en tabla intermedia
            select count (*) into v_existe_enrl_doc
              from SZREDBP
              where SZREDBP_TERM_CODE = p_term_code
                and SZREDBP_CRN = p_crn
                and SZREDBP_PIDM = p_pidm
                and SZREDBP_CATEGORY = p_cat
                and SZREDBP_LINE_NEG = p_line;
                
           IF v_existe_enrl_doc = 0 THEN
           
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
                    'I',
                    1,
                    'SIRASGN',
                    USER,
                    v_role_id,
                    v_addic_id,
                    v_id_nrc
                );
           END IF;
/*
    ELSIF p_action = 'UPDATE' THEN

        UPDATE integracion.SZREDBP
           SET SZREDBP_DESC          = p_desc,
               SZREDBP_START_DATE    = p_start_date,
               SZREDBP_END_DATE      = p_end_date,
               SZREDBP_STATE         = 'NEW',
               SZREDBP_OPERACION      = 'U',
               SZREDBP_VERSION       = NVL(SZREDBP_VERSION,0) + 1,
               SZREDBP_USER_ID       = USER,
               SZREDBP_ACTIVITY_DATE = SYSDATE
         WHERE SZREDBP_TERM_CODE = p_term_code
           AND SZREDBP_PTRM_CODE = p_ptrm_code;
*/
        ELSIF p_action = 'DELETE' THEN
        
            UPDATE integracion.SZREDBP
               SET SZREDBP_OPERACION      = 'D',
                   SZREDBP_STATE = 'DEL', -- ESTADO DELETE
                   SZREDBP_VERSION       = NVL(SZREDBP_VERSION,0) + 1,
                   SZREDBP_USER_ID       = USER,
                   SZREDBP_ACTIVITY_DATE = SYSDATE
             WHERE SZREDBP_TERM_CODE = p_term_code
               AND SZREDBP_CRN= p_crn
               AND SZREDBP_PIDM = p_pidm
               AND SZREDBP_CATEGORY = p_cat
               AND SZREDBP_LINE_NEG = p_line;
        END IF;
        
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

        v_error           VARCHAR2(200);

    BEGIN
        ------------------------------------------------------------------
        -- Configuración
        ------------------------------------------------------------------
        v_url :=
            PKG_INT_BRIPACE_TERM.f_get_gtvsdax(
                'ONLINE',
                'INSTANAME',
                'DEV_INT_BRIGTHSPACE'
            );

        v_path_base :=
            PKG_INT_BRIPACE_TERM.f_get_gtvsdax(
                'ONLINE',
                'ENROL_DOC',
                'DEV_INT_BRIGTHSPACE'
            );

 -- como en el path esta incluido el metodo, lo separamos para luego usarlo adecuadamente 
 -- en los valores del JSON

         v_method:= SUBSTR(v_path_base,1, INSTR(v_path_base, ',') -1);

         v_path:= SUBSTR(v_path_base, INSTR(v_path_base, ',') + 1);

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
                   SZREDBP_ROLE_ID,
                   SZREDBP_ADDIC_ID,
                   SZREDBP_NRC_ID
              FROM SZREDBP A
             WHERE SZREDBP_state IN ('NEW', 'DEL') -- Nuevos y borrados
        )
        LOOP

            BEGIN
    dbms_output.put_line('mensaje 2');
                ------------------------------------------------------------------
                -- Generar JSON
                ------------------------------------------------------------------
         -- La secuencia es para el state NEW porque el DEL ya tiene seq
        IF r.SZREDBP_STATE = 'NEW' THEN
           v_seq := INTEGRACION.SEQ_ITZBGSP.NEXTVAL;
           
           SELECT JSON_ARRAYAGG(
                   JSON_OBJECT(
                       'request' VALUE JSON_OBJECT(
                           'id' VALUE v_seq, 
                           'endpoint' VALUE v_url || v_path,
                           'method' VALUE v_method,
                           'body' VALUE JSON_OBJECT(
                               'OrgUnitId' VALUE TO_NUMBER(r.SZREDBP_NRC_ID), --id_nrc
                               'UserId' VALUE TO_NUMBER(r.SZREDBP_ADDIC_ID), --id user
                               'RoleId' VALUE TO_NUMBER(r.SZREDBP_ROLE_ID), --id rol
                               'SendEnrollmentEmail' VALUE 'false' FORMAT JSON
                           RETURNING CLOB)
                       RETURNING CLOB),
                            
                            'response' VALUE NULL
                            
                   RETURNING CLOB)
               )
        INTO l_json
        FROM dual;
           
        ELSE
            v_seq := r.SZREDBP_ID_MAESTRO;
            v_method:= 'DELETE';
            
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
                    'ENROLLMENT_TEACHER',
                    'PENDING'
                );
    dbms_output.put_line('mensaje 4');
                ------------------------------------------------------------------
                -- Actualizar estado en SZREDBP
                ------------------------------------------------------------------
                UPDATE SZREDBP
                   SET SZREDBP_state = 'SEND',
                       SZREDBP_ID_MAESTRO= v_seq
                 WHERE ROWID = r.rid;

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

-- Inserta datos supl en tabla intermedia de Periodo



END PKG_INT_BRIPACE_ENROLL;