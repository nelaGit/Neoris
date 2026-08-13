
create or replace PACKAGE                   PKG_INT_BRIPACE_PERS AS

-- Registra en tabla intermedia SZRPEBP datos del periodo capturados desde el trigger de DOCENTES******
    PROCEDURE p_registra_persona(
        p_pidm         NUMBER,
        p_term_code    VARCHAR2
    );

-- Registra desde la tabla intermedia a la tabla de integracion
PROCEDURE p_registra_persona_int ;


-- Inserta datos suplementarios en tabla intermedia ITZSUPL
PROCEDURE p_insert_itzsupl;

-- Funcion que retorna el valor de comments de la tabla GTVSDAX
FUNCTION f_get_gtvsdax (
    p_external_code       IN GTVSDAX.GTVSDAX_EXTERNAL_CODE%TYPE,
    p_internal_code       IN GTVSDAX.GTVSDAX_INTERNAL_CODE%TYPE,
    p_internal_code_group IN GTVSDAX.GTVSDAX_INTERNAL_CODE_GROUP%TYPE
)
RETURN GTVSDAX.GTVSDAX_COMMENTS%TYPE;

-- Retorna el valor de datos suplementarios 
FUNCTION fn_get_gorsdav_value (
    p_table_name   IN gorsdav.gorsdav_table_name%TYPE,
    p_attr_name    IN gorsdav.gorsdav_attr_name%TYPE,
    p_pk_parenttab IN VARCHAR2
)
RETURN VARCHAR2;

END PKG_INT_BRIPACE_PERS;
/

create or replace PACKAGE BODY              PKG_INT_BRIPACE_PERS AS  

    PROCEDURE p_registra_persona(
        p_pidm         NUMBER,
        p_term_code    VARCHAR2
    ) IS
	
	v_line_neg VARCHAR2(20);
	v_rol	   VARCHAR2(20);
    r_pk_parenttab    gobsdtb.gobsdtb_pk_dynsql%TYPE;
    v_rid              varchar2(18):=null;
    v_error     VARCHAR2(500);
    
    v_per_doc    VARCHAR2(6);
    v_per_online VARCHAR2(6);
    v_existe_doc NUMBER;

    BEGIN
    -- Valida que el periodo registrado sea el de la variable GTVSDAX
    -- indica el periodo donde los docentes(SIAINST) tienen los datos suplementarios SMART_ONLINE, SMART_FLEX_SMART_CYP
     v_per_doc:= pkg_int_bripace_term.f_get_gtvsdax(
                'ONLINE',
                'PER_DOC',
                'DEV_INT_BRIGTHSPACE'
            );
    
	   IF v_per_doc = p_term_code THEN -- si el periodo de gtvsdax es el periodo del docente de sianst entonces se va en la integracion
        
        -- 
        -- Validacion del periodo que sea ONLINE
         v_per_online:= pkg_int_bripace_term.f_get_gtvsdax(
                    'ONLINE',
                    'PERIODO',
                    'DEV_INT_BRIGTHSPACE'
                );
        
        -- Se valida que las 2 ultimas posiciones sea igual al periodo parametrizado en GTVSDAX
        IF v_per_online = SUBSTR(p_term_code,5,2) Then
          v_line_neg:= 'ON'; -- Por ahora se trabajará en solo la linea ONLINE
        
            SELECT ROWID into v_rid  
              FROM SIBINST 
             WHERE SIBINST_PIDM = p_pidm AND SIBINST_TERM_CODE_EFF = p_term_code;
             
              r_pk_parenttab:=gp_goksdif.f_get_pk('SIBINST',v_rid);
             
              v_rol:=   PKG_INT_BRIPACE_PERS.fn_get_gorsdav_value(
                                        'SIBINST', 'SMART_ONLINE', 
                                        r_pk_parenttab);
            
              
               -- validamos si el docente ya existe en la tabla intermedia
               select count(*) into v_existe_doc
                 from SZRPEBP 
                where SZRPEBP_PIDM = p_pidm;
               
               IF v_existe_doc = 0 AND v_rol IS NOT NULL THEN -- SI NO existe y tiene DATO SUPLEMENTARIO ONLINE, debe insertar en tabla intermedia
               
                   BEGIN
                        INSERT INTO SZRPEBP(
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
                            p_pidm,
                            p_term_code,
                            v_line_neg,
                            v_rol,
                            'NEW',
                            'I',
                            1,
                            'SIBINST',
                            USER,
                            SYSDATE
                        );
                EXCEPTION WHEN OTHERS THEN
                --  NULL; -- MER TMP INCLUIR QUE HACER
                  
                  v_error := SQLERRM;
                  
                  RAISE_APPLICATION_ERROR(
                     -20001,
                     'ERROR: ' || v_error
                  );
                END;
          END IF; -- v_existe_doc
        END IF; --v_per_online
    END IF; --v_per_doc = p_term_code
  END p_registra_persona;

-- -- Registra desde la tabla intermedia a la tabla de integracion 
    PROCEDURE p_registra_persona_int IS

        l_json        CLOB;

        -- Configuración Brightspace
        v_url              GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_path_base        GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_path             GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_method           GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_org_type         GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_org_parent       GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_seq              number;
        
        v_role_id_on GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_role_id_as GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_existe_inf_ad number;
        
        v_error           VARCHAR2(200);

    BEGIN

        ------------------------------------------------------------------
        -- Configuración
        ------------------------------------------------------------------
        v_url :=
            PKG_INT_BRIPACE_PERS.f_get_gtvsdax(
                'ONLINE',
                'INSTANAME',
                'DEV_INT_BRIGTHSPACE'
            );

        v_path_base :=
            PKG_INT_BRIPACE_PERS.f_get_gtvsdax(
                'ONLINE',
                'CREA_USER',
                'DEV_INT_BRIGTHSPACE'
            );

 -- como en el path esta incluido el metodo, lo separamos para luego usarlo adecuadamente 
 -- en los valores del JSON

         v_method:= SUBSTR(v_path_base,1, INSTR(v_path_base, ',') -1);

         v_path:= SUBSTR(v_path_base, INSTR(v_path_base, ',') + 1);

        v_role_id_on :=
            PKG_INT_BRIPACE_PERS.f_get_gtvsdax(
                'ONLINE',
                'ROL_DOC_ON',
                'DEV_INT_BRIGTHSPACE'
            );

        v_role_id_as :=
            PKG_INT_BRIPACE_PERS.f_get_gtvsdax(
                'ONLINE',
                'ROL_DOC_AS',
                'DEV_INT_BRIGTHSPACE'
            );
    dbms_output.put_line('mensaje 1');
        ------------------------------------------------------------------
        -- Procesar todos los registros NEW
        ------------------------------------------------------------------
        FOR r IN (
            SELECT a.ROWID rid,
                   a.SZRPEBP_PIDM pidm,
                   NULL mname,
                   b.SPRIDEN_FIRST_NAME fname, 
                   b.SPRIDEN_LAST_NAME lname,
                   c.GOREMAL_EMAIL_ADDRESS email,
                   SPRIDEN_id,
                   TO_NUMBER(v_role_id_on) rol_doc
              FROM SZRPEBP a
              INNER JOIN SPRIDEN b ON a.SZRPEBP_PIDM = b.SPRIDEN_PIDM
              LEFT JOIN GOREMAL c ON c.GOREMAL_PIDM = b.SPRIDEN_PIDM AND c.GOREMAL_EMAL_CODE = 'CEIN' AND GOREMAL_PREFERRED_IND = 'Y'
              WHERE b.SPRIDEN_CHANGE_IND IS NULL AND a.SZRPEBP_STATE = 'NEW'
        )
        LOOP
          BEGIN
                ------------------------------------------------------------------
                -- Generar JSON
                ------------------------------------------------------------------

           v_seq := INTEGRACION.SEQ_ITZBGSP.NEXTVAL;
        
       SELECT JSON_ARRAY(
         JSON_OBJECT(
             'request' VALUE JSON_OBJECT(
                 'id' VALUE v_seq,
                 'endpoint' VALUE v_url || v_path,
                 'method' VALUE v_method,
                 'body' VALUE JSON_OBJECT(
                     'OrgDefinedId'      VALUE TO_CHAR(r.pidm),
                     'FirstName'         VALUE r.fname,
                     'MiddleName'        VALUE r.mname,
                     'LastName'          VALUE r.lname,
                     'ExternalEmail'     VALUE r.email,
                     'UserName'          VALUE r.email,
                     'RoleId'            VALUE r.rol_doc,
                     'IsActive'          VALUE 'true'  FORMAT JSON,
                     'SendCreationEmail' VALUE 'false' FORMAT JSON
                 )
             ),
             'response' VALUE NULL
             RETURNING CLOB
         )
         RETURNING CLOB
       )
    INTO l_json
    FROM dual;
            

    dbms_output.put_line('mensaje 3');
                ------------------------------------------------------------------
                -- Registrar solicitud
                ------------------------------------------------------------------
    -- Se valida si el docente ya tiene INFORMACION ADICIONAL
    
      SELECT COUNT(1) 
      INTO v_existe_inf_ad 
      FROM  GORADID
      WHERE GORADID_PIDM = r.pidm
        AND GORADID_ADID_CODE= 'LMBO'; -- Inf adicional de docente online
        
      
      -- Si el docente existe (Dato LMBO) no se debe crear
          IF v_existe_inf_ad = 0 THEN
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
                    'CREATE_USER',
                    'PENDING'
                );
                ------------------------------------------------------------------
                -- Actualizar estado en SZRTMBP
                ------------------------------------------------------------------
                UPDATE SZRPEBP
                   SET SZRPEBP_STATE = 'SEND',
                       SZRPEBP_ID_MAESTRO= v_seq
                 WHERE ROWID = r.rid;
           END IF;
       
            EXCEPTION
                WHEN OTHERS THEN
                   v_error := sqlerrm;

                    UPDATE SZRPEBP
                       SET SZRPEBP_STATE = 'FAIL',
                        SZRPEBP_STATE_DET = v_error
                     WHERE ROWID = r.rid;

          END;
        END LOOP;
        
 --END IF;

    END p_registra_persona_int;

-- Inserta datos supl en tabla intermedia de Periodo

  PROCEDURE p_insert_itzsupl Is
    r_pk_parenttab    gobsdtb.gobsdtb_pk_dynsql%TYPE;
    v_rid              varchar2(18):=null;
    r_gorsdav_rowid   varchar2(18):=null;

  -- mer tmp hay que meter un loop aqui para que vaya insertando en ITZSUPL y luego en datos suplementarios
    Cursor c_supl is
      select SZRPEBP_PIDM PIDM, 
             SZRPEBP_LINE_NEG ptrm_code, 
             SZRPEBP_ROL ROL,
             SZRPEBP_ID_MAESTRO id_maestro
        from SZRPEBP B
       WHERE B.SZRPEBP_LINE_NEG = 'ON'
         AND B.SZRPEBP_STATE = 'SEND';

    BEGIN
    -- SE INserta en datos adicionales si el RESPONSE es 200
      
       For i in c_supl LOOP
       
           INSERT INTO GORADID
           (
              GORADID_PIDM,
              GORADID_ADDITIONAL_ID,
              GORADID_ADID_CODE,
              GORADID_USER_ID,
              GORADID_ACTIVITY_DATE,
              GORADID_DATA_ORIGIN,
              GORADID_SURROGATE_ID,
              GORADID_VERSION,
              GORADID_VPDI_CODE
           )
           SELECT     M.SZRPEBP_PIDM,
               JSON_VALUE(B.RESPONSE,
                         '$[0].response.body.UserId'
                         RETURNING VARCHAR2(20))      AS GORADID_ADDITIONAL_ID,
               'LMBO', -- meter en GTVSDAX
                 USER,
                SYSDATE,
                'BRIGTHSPACE',
                NULL,
                1,
                NULL
           FROM ITZBGSP B
                INNER JOIN SZRPEBP M
                   ON M.SZRPEBP_ID_MAESTRO = B.ID
           WHERE M.SZRPEBP_PIDM = i.pidm
             AND B.STATUS = 'PROCESSED_OK'
             AND B.OP_TYPE = 'CREATE_USER'
             AND B.RESPONSE IS NOT NULL
             AND JSON_VALUE(B.RESPONSE, '$[0].response.code') = '200'
             AND JSON_EXISTS(B.RESPONSE,'$[0].response.body.UserId')
             AND NOT EXISTS
             (
                 SELECT 1
                 FROM GORADID S
                 WHERE S.GORADID_PIDM =  M.SZRPEBP_PIDM
                   AND S.GORADID_ADID_CODE = 'LMBO'
             );


          UPDATE  ITZBGSP 
            SET STATUS = 'COMPLETED'
          where STATUS='PROCESSED_OK'
            and OP_TYPE = 'CREATE_USER'
            and ID= I.id_maestro;
            
         UPDATE SZRPEBP
            SET SZRPEBP_STATE = 'APPLIED'
            WHERE SZRPEBP_STATE = 'SEND'
              AND SZRPEBP_PIDM = i.pidm
              AND SZRPEBP_ID_MAESTRO = i.id_maestro;
              
      End Loop;
      
    END p_insert_itzsupl;


    -- Funcion que retorna el valor de comments de la tabla GTVSDAX
    FUNCTION f_get_gtvsdax (
        p_external_code       IN GTVSDAX.GTVSDAX_EXTERNAL_CODE%TYPE,
        p_internal_code       IN GTVSDAX.GTVSDAX_INTERNAL_CODE%TYPE,
        p_internal_code_group IN GTVSDAX.GTVSDAX_INTERNAL_CODE_GROUP%TYPE
    )
    RETURN GTVSDAX.GTVSDAX_COMMENTS%TYPE
    IS
        l_value GTVSDAX.GTVSDAX_COMMENTS%TYPE;
    BEGIN
        SELECT gtvsdax_comments
          INTO l_value
          FROM gtvsdax
         WHERE gtvsdax_external_code      = p_external_code
           AND gtvsdax_internal_code      = p_internal_code
           AND gtvsdax_internal_code_group = p_internal_code_group;

        RETURN l_value;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(
                -20001,
                'No existe configuración en GTVSDAX. ' ||
                'EXTERNAL_CODE=' || p_external_code ||
                ', INTERNAL_CODE=' || p_internal_code ||
                ', GROUP=' || p_internal_code_group
            );

        WHEN TOO_MANY_ROWS THEN
            RAISE_APPLICATION_ERROR(
                -20002,
                'Existen múltiples configuraciones en GTVSDAX. ' ||
                'EXTERNAL_CODE=' || p_external_code ||
                ', INTERNAL_CODE=' || p_internal_code ||
                ', GROUP=' || p_internal_code_group
            );
    END f_get_gtvsdax;

 FUNCTION fn_get_gorsdav_value (
    p_table_name   IN gorsdav.gorsdav_table_name%TYPE,
    p_attr_name    IN gorsdav.gorsdav_attr_name%TYPE,
    p_pk_parenttab IN VARCHAR2
)
RETURN VARCHAR2
IS
    l_value VARCHAR2(4000);
BEGIN

    BEGIN
        SELECT DECODE(x.gorsdav_value.getTypeName(),
                      'SYS.VARCHAR2', x.gorsdav_value.accessVARCHAR2(),
                      'SYS.DATE', TO_CHAR(x.gorsdav_value.accessDATE(),
                                          'YYYY-MM-DD HH24:MI:SS'),
                      'SYS.NUMBER', TO_CHAR(x.gorsdav_value.accessNUMBER()),
                      '*ERROR* Unknown SYS.ANYDATA data type ***')
          INTO l_value
          FROM gorsdav x
         WHERE x.gorsdav_table_name = p_table_name
           AND x.gorsdav_attr_name = p_attr_name
           AND x.gorsdav_pk_parenttab = p_pk_parenttab;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
          NULL;

    END;

    RETURN l_value;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
END;

END PKG_INT_BRIPACE_PERS;