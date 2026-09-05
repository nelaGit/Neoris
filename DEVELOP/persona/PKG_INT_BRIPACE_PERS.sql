create or replace PACKAGE                                           PKG_INT_BRIPACE_PERS AS

-- Registra en tabla intermedia SZRPEBP datos del periodo capturados desde el trigger de DOCENTES******
     PROCEDURE p_registra_docente(
        p_pidm         NUMBER,
        p_term_code    VARCHAR2,
        p_fcnt_code    VARCHAR2,
        p_cntr_code    VARCHAR2,
        p_operacion    VARCHAR2
    );

  ----------------------------------------------------------------------
    -- TABLA INTERMEDIA: SZRPEBP - PERSONAS
    ----------------------------------------------------------------------
    PROCEDURE p_intermedia_szrpebp (
        p_registro       IN SZRPEBP%ROWTYPE,
        p_business_line  IN SZRLGBP.SZRLGBP_BUSINESS_LINE%TYPE,
        p_op_type        IN SZRLGBP.SZRLGBP_OP_TYPE%TYPE
    );





-- Inserta datos suplementarios en tabla intermedia ITZSUPL
PROCEDURE p_insert_itzsupl;


-- Activa, inactiva docentes de SIAINST
 PROCEDURE p_act_inact_pers(
        p_pidm         NUMBER,
        p_term_code    VARCHAR2,
        p_estado_doc   VARCHAR2);
        
        
        
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

PROCEDURE p_audit_siricnt
(
    p_pidm              IN SIRICNT.SIRICNT_PIDM%TYPE,
    p_term_code_eff     IN SIRICNT.SIRICNT_TERM_CODE_EFF%TYPE,
    p_fcnt_code         IN SIRICNT.SIRICNT_FCNT_CODE%TYPE,
    p_cntr_code         IN SIRICNT.SIRICNT_CNTR_CODE%TYPE,
    p_def_ind           IN SIRICNT.SIRICNT_DEF_IND%TYPE,
    p_activity_date     IN SIRICNT.SIRICNT_ACTIVITY_DATE%TYPE,
    p_version           IN SIRICNT.SIRICNT_VERSION%TYPE,
    p_user_id           IN SIRICNT.SIRICNT_USER_ID%TYPE,
    p_data_origin       IN SIRICNT.SIRICNT_DATA_ORIGIN%TYPE,
    p_vpdi_code         IN SIRICNT.SIRICNT_VPDI_CODE%TYPE,
    p_operation         IN VARCHAR2
);

-- se va a eliminar
PROCEDURE p_registra_persona(
        p_pidm         NUMBER,
        p_term_code    VARCHAR2
    );
    
PROCEDURE p_registra_persona_int;

-- se va a eliminar 
-- Registra desde la tabla intermedia a la tabla de integracion
PROCEDURE p_registra_persona_int_OLD ;

END PKG_INT_BRIPACE_PERS;
/
create or replace PACKAGE BODY                                                                          PKG_INT_BRIPACE_PERS AS  

    PROCEDURE p_cambio_rol(
        p_pidm         NUMBER,
        p_id_ma        NUMBER,
        p_term_code    VARCHAR2,
        p_rol          VARCHAR2
    ) IS
    
      l_body        CLOB;

        -- Configuración Brightspace
        v_url              GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_path_base        GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_path             GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_method           GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_org_type         GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_org_parent       GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_seq              number;
        
        v_tipo_enroll      VARCHAR2(30);
        v_adic_id          GORADID.GORADID_ADDITIONAL_ID%TYPE;
        v_role_id          GTVSDAX.GTVSDAX_COMMENTS%TYPE;

        v_error           VARCHAR2(200);
        v_error_message   VARCHAR2(300);
    
    BEGIN
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
            
         v_org_parent :=
            pkg_int_bripace_term.f_get_gtvsdax(
                'ONLINE',
                'ORG_PARENT',
                'DEV_INT_BRIGTHSPACE'
            );
        IF p_rol = 'ON' THEN
           
           v_role_id :=
            PKG_INT_BRIPACE_PERS.f_get_gtvsdax(
                'ONLINE',
                'ROL_DOC_ON',
                'DEV_INT_BRIGTHSPACE'
            );
            
        ELSIF p_rol = 'AS' THEN
    
            v_role_id :=
                PKG_INT_BRIPACE_PERS.f_get_gtvsdax(
                    'ONLINE',
                    'ROL_DOC_AS',
                    'DEV_INT_BRIGTHSPACE'
                );
        END IF;    
        
    -- como en el path esta incluido el metodo, lo separamos para luego usarlo adecuadamente 
 -- en los valores del JSON

         v_method:= SUBSTR(v_path_base,1, INSTR(v_path_base, ',') -1);

         v_path:= SUBSTR(v_path_base, INSTR(v_path_base, ',') + 1);
         
         
         -- selec el dato adicional
          Begin
              SELECT GORADID_ADDITIONAL_ID
                INTO v_adic_id
               FROM  GORADID
               WHERE GORADID_PIDM = p_pidm
                 AND GORADID_ADID_CODE= 'LMBO'; 
         Exception When OTHERS THEN
           NULL;
         End;
         
          IF v_adic_id IS NOT NULL THEN
              v_tipo_enroll:= 'CHANGE_ROLE';
               
             SELECT JSON_OBJECT(
               'OrgUnitId'           VALUE TO_NUMBER(v_org_parent),
               'UserId'              VALUE TO_NUMBER(v_adic_id),
               'RoleId'              VALUE TO_NUMBER(v_role_id),
               'SendEnrollmentEmail' VALUE 'false' FORMAT JSON
               RETURNING CLOB )
                INTO l_body
                FROM dual;
          
              ------------------------------------------------------------------
                -- Generar JSON + insertar ITZBGSP
                ------------------------------------------------------------------
              PKG_INT_BRIPACE_UTIL.p_genera_inserta_itzbgsp(
                    p_business_line => 'ONLINE',
                    p_op_type       => v_tipo_enroll,
                    p_endpoint      => v_url || v_path,
                    p_method        => v_method,
                    p_body          => l_body,
                    p_id_generado   => v_seq
                );
                    
              UPDATE SZRPEBP
                   SET SZRPEBP_ROL = p_rol,
                       SZRPEBP_STATE_DET = v_tipo_enroll
                 WHERE  SZRPEBP_PIDM= p_pidm;
                 
                
                v_error_message := v_tipo_enroll ||
                    ' para el docente ' ||
                    GB_COMMON.F_GET_ID(p_pidm);
                   

                PKG_INT_BRIPACE_TERM.p_registra_error_log(
                    p_business_line => 'ONLINE',
                    p_op_type       => v_tipo_enroll,
                    p_term_code     => p_term_code,
                    p_ptrm_code     => NULL,
                    p_crn            => NULL,
                    p_pidm          => p_pidm,
                    p_state         => 'OK',
                    p_error_code    => v_tipo_enroll||'_OK',
                    p_error_message => v_error_message
                );

                 
       END IF;
        EXCEPTION WHEN OTHERS THEN
         NULL; -- INCLUIR LOG ERRORES
    END p_cambio_rol;
    
    /* ********************************************************************* */
    PROCEDURE p_registra_docente(
        p_pidm         NUMBER,
        p_term_code    VARCHAR2,
        p_fcnt_code    VARCHAR2, --Linea de negocios SO: smart online, CP: , SF:
        p_cntr_code    VARCHAR2, --rol ON, AS
        p_operacion    VARCHAR2
    ) IS
	
	v_rol	   VARCHAR2(20);
    r_pk_parenttab    gobsdtb.gobsdtb_pk_dynsql%TYPE;
    v_rid              varchar2(18):=null;
    v_error     VARCHAR2(500);
    
    v_per_doc    VARCHAR2(6);
    v_per_online VARCHAR2(6);
    v_existe_doc NUMBER;
    v_existe_inf_ad number;
    v_id VARCHAR2(9);
    v_rol_int VARCHAR2(20);
    v_id_maestro NUMBER;
    
    r_docente SZRPEBP%rowtype;
    v_op_type VARCHAR2(30);
    v_cant_cntr NUMBER;
    v_fcnt_config VARCHAR2(4000);

    BEGIN
    -- Valida que el periodo registrado sea el de la variable GTVSDAX
    -- indica el periodo donde los docentes(SIAINST) tienen los datos suplementarios SMART_ONLINE, SMART_FLEX_SMART_CYP
      v_per_doc:= pkg_int_bripace_term.f_get_gtvsdax(
                'ONLINE',
                'PER_DOC',
                'DEV_INT_BRIGTHSPACE'
            );
     
      v_id := GB_COMMON.F_GET_ID(p_pidm);
            
      -- se capturan las lineas de negocio permitidas en GTVSDAX
      -- las identificamos por medio de los ID ROLES
       -- OJO: CONFIGURAR LAS VARIABLES DAX para que tomr FCNT Y CNTR configurados
       
    
       dbms_output.put_line('registra_per. v_per_doc: '||v_per_doc);
    
	   IF v_per_doc = p_term_code THEN -- si el periodo de gtvsdax es el periodo del docente de sianst entonces se va en la integracion
       -- Se validan las diferentes operaciones
       -- INSERT: Si no hay datos adic --> creacion de docente. Si hay datos adic --> Activar docente.
       -- UPDATE: Identifica cambio de ROL
       -- DELETE: Inactiva el docente
       
       ------------------------------------------------------------------
       -- Obtener configuración de líneas de negocio
       ------------------------------------------------------------------
        v_fcnt_config := pkg_int_bripace_term.f_get_gtvsdax(
                         'ONLINE',
                         'T_CONTRATO',
                         'DEV_INT_BRIGTHSPACE'
                     );
       
        ------------------------------------------------------------------
        -- Validar que p_fcnt_code esté dentro de la configuración
        ------------------------------------------------------------------
       IF INSTR(
           ',' || REPLACE(v_fcnt_config, ' ', '') || ',',
           ',' || TRIM(p_fcnt_code) || ','       ) > 0   THEN


        ------------------------------------------------------------------
        -- Si llegó aquí, p_fcnt_code está configurado
        ------------------------------------------------------------------
       
         -- Se valida que el registro del rol no se repita
         SELECT count(*) INTO v_cant_cntr
           FROM SIRICNT
          WHERE SIRICNT_PIDM = p_pidm
            AND SIRICNT_TERM_CODE_EFF = p_term_code
            AND SIRICNT_FCNT_CODE = p_fcnt_code;
            
         IF v_cant_cntr > 1 THEN
            v_error:= 'No se identifica linea de negocio por duplicidad, ID DOCENTE: '|| v_id;
          
           PKG_INT_BRIPACE_TERM.p_registra_error_log(
                        p_business_line => 'ONLINE',
                        p_op_type       => 'CREATE_USER',
                        p_term_code     => p_term_code,
                        p_pidm          => p_pidm,
                        p_error_code    => 'ERR_ID_ROL_DUP',
                        p_error_message => v_error);
          RETURN; -- Si esta duplicado se sale
         END IF;
       
          SELECT COUNT(1) 
                      INTO v_existe_inf_ad 
                      FROM  GORADID
                      WHERE GORADID_PIDM = p_pidm
                        AND GORADID_ADID_CODE= 'LMBO';
           Begin
               SELECT SZRPEBP_ROL, SZRPEBP_ID_MAESTRO into v_rol_int, v_id_maestro
                 FROM SZRPEBP WHERE SZRPEBP_PIDM = p_pidm;
             Exception When Others Then
               NULL;
           End;
         
         IF p_operacion = 'INSERT' THEN
           -- hay datos adic, se activa
               IF v_existe_inf_ad >= 1 THEN 
                 -- Se valida que rol tiene, si trae el mismo se activa directamente, 
                 -- sino se tiene que generar el JSON compuesto--> RC. Rol compuesto
                 IF v_rol_int != p_cntr_code THEN
                    PKG_INT_BRIPACE_PERS.p_act_inact_pers(
                                        p_pidm   =>   p_pidm    ,
                                        p_term_code =>  p_term_code  ,
                                        p_estado_doc => 'RC' );
                 
                 ELSE
                     PKG_INT_BRIPACE_PERS.p_act_inact_pers(
                                        p_pidm   =>   p_pidm    ,
                                        p_term_code =>  p_term_code  ,
                                        p_estado_doc => 'AC' );
                 END IF;
                                    
               -- sin datos adicionales, se CREA                
               ELSE 
                  r_docente.SZRPEBP_PIDM:= p_pidm;
                  r_docente.SZRPEBP_TERM_CODE:= p_term_code;
                  r_docente.SZRPEBP_LINE_NEG:= p_fcnt_code;
                  r_docente.SZRPEBP_ROL:= p_cntr_code;
                  r_docente.SZRPEBP_DATA_ORIGIN:= 'SIRINCT';
                
               
                  PKG_INT_BRIPACE_PERS.p_intermedia_szrpebp(
                    p_registro      => r_docente,
                    p_business_line => 'ONLINE',
                    p_op_type       => 'CREATE_TERM');
               END IF;
       
          -- cambio de rol
         ELSIF p_operacion = 'UPDATE' THEN
           -- validacion del cambio de ROL
             -- Se valida que rol tiene en la tabla intermedia.
             -- Si el ROL es diferente debe realizar el proceso de cambio de ROL
             Begin
               SELECT SZRPEBP_ROL, SZRPEBP_ID_MAESTRO into v_rol_int, v_id_maestro
                 FROM SZRPEBP WHERE SZRPEBP_PIDM = p_pidm;
             Exception When Others Then
               NULL;
             End;
             
             IF v_rol_int != p_cntr_code THEN
                  p_cambio_rol( p_pidm        => p_pidm,  
                                p_id_ma       => v_id_maestro,
                                p_term_code   => p_term_code,   
                                p_rol         => p_cntr_code); -- LLAMA PROC DE CAMBIO DE ROL
                                
                 
             END IF;
         
         ELSE -- DELETE, se inactiva cuando no quedan registros en SIRINCT para ese periodo
           SELECT count(*) INTO v_cant_cntr
           FROM SIRICNT
          WHERE SIRICNT_PIDM = p_pidm
            AND SIRICNT_TERM_CODE_EFF = p_term_code;
            
           IF v_cant_cntr = 0 THEN
               PKG_INT_BRIPACE_PERS.p_act_inact_pers(
                                    p_pidm   =>   p_pidm    ,
                                    p_term_code =>  p_term_code  ,
                                    p_estado_doc => 'IN' );
            END IF;
         END IF; -- p_operacion
        
       END IF; --v_fcnt_config         
    END IF; -- v_per_doc = p_term_code
    
    
    dbms_output.put_line(' ENTRA FIN.'||LENGTH(v_rol));
  END p_registra_docente;
  
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
/*
        PKG_INT_BRIPACE_TERM.p_registra_error_log(
            p_business_line => p_business_line,
            p_op_type       => p_op_type,
            p_term_code     => p_registro.SZRPEBP_TERM_CODE,
            p_pidm          => p_registro.SZRPEBP_PIDM,
            p_error_code    => 'INTERMEDIA_OK',
            p_error_message => 'Registro de persona procesado correctamente',
            p_state         => 'OK',
            p_data_origin   => p_registro.SZRPEBP_DATA_ORIGIN
        );
*/

    EXCEPTION
        WHEN OTHERS THEN

            PKG_INT_BRIPACE_TERM.p_registra_error_log(
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


-- -- Registra desde la tabla intermedia a la tabla de integracion 
    PROCEDURE p_registra_persona_int 
    IS

    ------------------------------------------------------------------
    -- Configuración Brightspace
    ------------------------------------------------------------------
    v_url              GTVSDAX.GTVSDAX_COMMENTS%TYPE;
    v_url_cfg          GTVSDAX.GTVSDAX_COMMENTS%TYPE;
    v_path_base        GTVSDAX.GTVSDAX_COMMENTS%TYPE;
    v_path             GTVSDAX.GTVSDAX_COMMENTS%TYPE;
    v_method           GTVSDAX.GTVSDAX_COMMENTS%TYPE;
    
    v_path_base2        GTVSDAX.GTVSDAX_COMMENTS%TYPE;
    v_path2             GTVSDAX.GTVSDAX_COMMENTS%TYPE;
    v_method2           GTVSDAX.GTVSDAX_COMMENTS%TYPE;

    v_role_id_on       GTVSDAX.GTVSDAX_COMMENTS%TYPE;
    v_role_id_as       GTVSDAX.GTVSDAX_COMMENTS%TYPE;
    
    v_org_parent       GTVSDAX.GTVSDAX_COMMENTS%TYPE;

    ------------------------------------------------------------------
    -- Variables de proceso
    ------------------------------------------------------------------
    v_seq              INTEGRACION.ITZBGSP.ID%TYPE;
    v_existe_inf_ad    NUMBER;

    v_error            VARCHAR2(4000);
    v_error_message    VARCHAR2(1000);

    ------------------------------------------------------------------
    -- JSON del BODY
    ------------------------------------------------------------------
   l_body CLOB;
   l_body_activation CLOB;
   l_body_enrollment CLOB;
  
   
   l_registros PKG_INT_BRIPACE_UTIL.t_itzbgsp_tab;
   

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

    v_method :=
        SUBSTR(
            v_path_base,
            1,
            INSTR(v_path_base, ',') - 1
        );


    v_path :=
        SUBSTR(
            v_path_base,
            INSTR(v_path_base, ',') + 1
        );


    ------------------------------------------------------------------
    -- Roles de Brightspace
    ------------------------------------------------------------------

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

  -- config para cambio rol docengte
   v_org_parent :=
            pkg_int_bripace_term.f_get_gtvsdax(
                'ONLINE',
                'ORG_PARENT',
                'DEV_INT_BRIGTHSPACE'
            );
            
 
        v_path_base2 :=
            PKG_INT_BRIPACE_TERM.f_get_gtvsdax(
                'ONLINE',
                'ENROL_DOC',
                'DEV_INT_BRIGTHSPACE'
            );
            
      v_method2:= SUBSTR(v_path_base2,1, INSTR(v_path_base2, ',') -1);

      v_path2:= SUBSTR(v_path_base2, INSTR(v_path_base2, ',') + 1);
    ------------------------------------------------------------------
    -- VALIDACIÓN:
    -- El docente debe tener correo CEIN preferido
    ------------------------------------------------------------------

    FOR e IN (
        SELECT a.SZRPEBP_PIDM       pidm,
               a.SZRPEBP_TERM_CODE  term_code
          FROM SZRPEBP a
         WHERE a.SZRPEBP_STATE = 'NEW'
           AND NOT EXISTS (
                SELECT 1
                  FROM GOREMAL g
                 WHERE g.GOREMAL_PIDM = a.SZRPEBP_PIDM
                   AND g.GOREMAL_EMAL_CODE = 'CEIN'
                   AND g.GOREMAL_PREFERRED_IND = 'Y'
           )
    )
    LOOP

        PKG_INT_BRIPACE_TERM.p_registra_error_log(
            p_business_line => 'ONLINE',
            p_op_type       => 'CREATE_USER',
            p_term_code     => e.term_code,
            p_pidm          => e.pidm,
            p_error_code    => 'EMAIL_NOT_FOUND',
            p_error_message =>
                'El docente no tiene un correo CEIN marcado como preferido ' ||
                '(GOREMAL_PREFERRED_IND = Y).'
        );

    END LOOP;


    ------------------------------------------------------------------
    -- PROCESAR DOCENTES NUEVOS
    ------------------------------------------------------------------

    FOR r IN (
        SELECT a.ROWID                    rid,
               a.SZRPEBP_PIDM             pidm,
               NULL                       mname,
               b.SPRIDEN_FIRST_NAME       fname,
               b.SPRIDEN_LAST_NAME        lname,
               c.GOREMAL_EMAIL_ADDRESS     email,
               b.SPRIDEN_ID               spriden_id,

               DECODE(
                   a.SZRPEBP_ROL,
                   'AS', TO_NUMBER(v_role_id_as),
                   'ON', TO_NUMBER(v_role_id_on)
               )                          rol_doc,

               a.SZRPEBP_TERM_CODE        term_code

          FROM SZRPEBP a

         INNER JOIN SPRIDEN b
            ON a.SZRPEBP_PIDM = b.SPRIDEN_PIDM

         INNER JOIN GOREMAL c
            ON c.GOREMAL_PIDM = b.SPRIDEN_PIDM
           AND c.GOREMAL_EMAL_CODE = 'CEIN'
           AND c.GOREMAL_PREFERRED_IND = 'Y'

         WHERE b.SPRIDEN_CHANGE_IND IS NULL
           AND a.SZRPEBP_STATE = 'NEW'
    )
    LOOP

        BEGIN

            ------------------------------------------------------------------
            -- Validar si el docente ya tiene información adicional LMBO
            ------------------------------------------------------------------

            SELECT COUNT(1)
              INTO v_existe_inf_ad
              FROM GORADID
             WHERE GORADID_PIDM = r.pidm
               AND GORADID_ADID_CODE = 'LMBO';


            ------------------------------------------------------------------
            -- Si ya existe LMBO NO se crea el usuario
            ------------------------------------------------------------------

            IF v_existe_inf_ad = 0 THEN

              SELECT JSON_OBJECT(
               'OrgDefinedId'      VALUE TO_CHAR(r.pidm),
               'FirstName'         VALUE r.fname,
               'MiddleName'        VALUE r.mname,
               'LastName'          VALUE r.lname,
               'ExternalEmail'     VALUE r.email,
               'UserName'          VALUE r.email,
               'RoleId'            VALUE r.rol_doc,
               'IsActive'          VALUE 'true'  FORMAT JSON,
               'SendCreationEmail' VALUE 'false' FORMAT JSON
               RETURNING CLOB
                       )
                INTO l_body
                FROM dual;

                ------------------------------------------------------------------
                -- Generar JSON + insertar ITZBGSP
                ------------------------------------------------------------------
              PKG_INT_BRIPACE_UTIL.p_genera_inserta_itzbgsp(
                    p_business_line => 'ONLINE',
                    p_op_type       => 'CREATE_USER',
                    p_endpoint      => v_url || v_path,
                    p_method        => v_method,
                    p_body          => l_body,
                    p_id_generado   => v_seq
                );
                ------------------------------------------------------------------
                -- Actualizar tabla intermedia
                ------------------------------------------------------------------
                UPDATE SZRPEBP
                   SET SZRPEBP_STATE       = 'SEND',
                       SZRPEBP_ID_MAESTRO  = v_seq
                 WHERE ROWID = r.rid;

                ------------------------------------------------------------------
                -- Registrar OK
                ------------------------------------------------------------------
                IF SQL%ROWCOUNT = 1 THEN
                    v_error_message :=
                        'DOCENTE ' ||
                        r.spriden_id ||
                        ' creado correctamente';

                    PKG_INT_BRIPACE_TERM.p_registra_error_log(
                        p_business_line => 'ONLINE',
                        p_op_type       => 'CREATE_USER',
                        p_term_code     => r.term_code,
                        p_ptrm_code     => NULL,
                        p_crn           => NULL,
                        p_pidm          => r.pidm,
                        p_state         => 'OK',
                        p_error_code    => 'OK',
                        p_error_message => v_error_message
                    );

                END IF;

            END IF;


        EXCEPTION
            WHEN OTHERS THEN
                v_error := SQLERRM;
                ------------------------------------------------------------------
                -- Marcar registro como FAIL
                ------------------------------------------------------------------

                UPDATE SZRPEBP
                   SET SZRPEBP_STATE     = 'FAIL',
                       SZRPEBP_STATE_DET  = v_error
                 WHERE ROWID = r.rid;

                ------------------------------------------------------------------
                -- Registrar error
                ------------------------------------------------------------------

                PKG_INT_BRIPACE_TERM.p_registra_error_log(
                    p_business_line => 'ONLINE',
                    p_op_type       => 'CREATE_USER',
                    p_term_code     => r.term_code,
                    p_ptrm_code     => NULL,
                    p_crn           => NULL,
                    p_pidm          => r.pidm,
                    p_state         => 'ERROR_CREATE_USER',
                    p_error_code    => SQLCODE,
                    p_error_message => v_error
                );

        END;

    END LOOP;


    ------------------------------------------------------------------
    -- CONFIGURACIÓN PARA ACTIVAR / INACTIVAR USUARIO
    ------------------------------------------------------------------

    BEGIN

        SELECT IZTZCFG_REQUEST_URL,
               IZTZCFG_REQUEST_METHOD
          INTO v_url_cfg,
               v_method
          FROM DESARROLLO.IZTZCFG
         WHERE IZTZCFG_IZTID = 'ONL_ACTIVE_USER';

    EXCEPTION
        WHEN NO_DATA_FOUND THEN

            v_url_cfg := NULL;
            v_method := NULL;

    END;


    ------------------------------------------------------------------
    -- Procesar activación / inactivación
    ------------------------------------------------------------------

    IF v_url_cfg IS NOT NULL
       AND v_method IS NOT NULL
    THEN

        FOR i IN (
            SELECT a.ROWID                    rid,
                   a.SZRPEBP_ID_MAESTRO       id_maestro,
                   b.GORADID_ADDITIONAL_ID    id_usuario_brightspace,
                   a.SZRPEBP_STATE            state,
                   a.SZRPEBP_PIDM             pidm,
                   c.SPRIDEN_ID               spriden_id,
                   a.SZRPEBP_TERM_CODE        term_code,
                   a.SZRPEBP_ROL              rol_docente,
                   DECODE(
                   a.SZRPEBP_ROL,
                   'AS', TO_NUMBER(v_role_id_as),
                   'ON', TO_NUMBER(v_role_id_on) )  id_rol_doc,

                   CASE
                       WHEN a.SZRPEBP_STATE = 'IN' THEN 'INACTIVE_USER'
                       WHEN a.SZRPEBP_STATE = 'AC' THEN 'ACTIVE_USER'
                       ELSE 'ACTIVE_ROLE_USER'
                   END                        action_user,

                   CASE
                       WHEN a.SZRPEBP_STATE = 'IN' THEN 'inactivó'
                       WHEN a.SZRPEBP_STATE = 'AC' THEN 'activó'
                       ELSE 'activó con cambio de rol'
                   END                        action_label_user

              FROM SZRPEBP a

              INNER JOIN GORADID b
                 ON a.SZRPEBP_PIDM = b.GORADID_PIDM

              INNER JOIN SPRIDEN c
                 ON a.SZRPEBP_PIDM = c.SPRIDEN_PIDM

             WHERE b.GORADID_ADID_CODE = 'LMBO'
               AND a.SZRPEBP_STATE IN ('AC', 'IN', 'RC') -- ACTIVO, INACTIVO, ROL COMPUESTO
               AND c.SPRIDEN_CHANGE_IND IS NULL
        )
        LOOP

            BEGIN

                ------------------------------------------------------------------
                -- Construir BODY
                ------------------------------------------------------------------
            IF i.state = 'RC' THEN -- rol compuesto
              
              -- BODY CAMBIO ROL
              
              
              -- BODY ACTIVACION
              SELECT JSON_OBJECT(
               'IsActive' VALUE 'true'
                  FORMAT JSON
               RETURNING CLOB
                       )
                INTO l_body_activation
                FROM dual;
                
                --ENROLLMENT
                SELECT JSON_OBJECT(
               'OrgUnitId'           VALUE TO_NUMBER(v_org_parent),
               'UserId'              VALUE TO_NUMBER(i.id_usuario_brightspace),
               'RoleId'              VALUE TO_NUMBER(i.id_rol_doc),
               'SendEnrollmentEmail' VALUE 'false' FORMAT JSON
               RETURNING CLOB )
                INTO l_body_enrollment
                FROM dual;
              
               -- l_registros(1).request_id := 2;
                l_registros(1).endpoint := v_url || v_path2;
                l_registros(1).method := v_method2;
                l_registros(1).body := l_body_enrollment;
                
               -- l_registros(2).request_id := 2;
                l_registros(2).endpoint :=  REPLACE( v_url_cfg, '{ID_USUARIO_BRIGHTSPACE}', TO_CHAR(i.id_usuario_brightspace)); --OK
                l_registros(2).method := v_method;
                l_registros(2).body := l_body_activation; --OK
                
                PKG_INT_BRIPACE_UTIL.p_genera_inserta_itzbgsp_multi(
                    p_business_line => 'ONLINE',
                    p_op_type       => i.action_user,
                    p_registros     => l_registros,
                    p_id_generado   => v_seq
                );
                
                 UPDATE SZRPEBP
                   SET SZRPEBP_ROL = i.rol_docente,
                       SZRPEBP_STATE       = 'SEND',
                       SZRPEBP_STATE_DET = i.action_user
                 WHERE  SZRPEBP_PIDM= i.pidm;
                 
                 
                 v_error_message :=
                    'El docente ' ||
                    i.spriden_id ||
                    ' se ' ||
                    i.action_label_user ||
                    ' correctamente';

                PKG_INT_BRIPACE_TERM.p_registra_error_log(
                    p_business_line => 'ONLINE',
                    p_op_type       => i.action_user,
                    p_term_code     => i.term_code,
                    p_ptrm_code     => NULL,
                    p_crn            => NULL,
                    p_pidm          => i.pidm,
                    p_state         => 'OK',
                    p_error_code    => 'OK',
                    p_error_message => v_error_message
                );
                 
                 
            
            ELSE -- AC, IN
               SELECT JSON_OBJECT(
               'IsActive' VALUE
                   CASE
                       WHEN i.state = 'AC'
                       THEN 'true'
                       ELSE 'false'
                   END FORMAT JSON
               RETURNING CLOB
                       )
                INTO l_body
                FROM dual;
                
             ------------------------------------------------------------------
                -- Generar JSON + insertar ITZBGSP
                ------------------------------------------------------------------

              PKG_INT_BRIPACE_UTIL.p_genera_inserta_itzbgsp(
                    p_business_line => 'ONLINE',
                    p_op_type       => i.action_user,
                    p_endpoint      =>
                        REPLACE(
                            v_url_cfg,
                            '{ID_USUARIO_BRIGHTSPACE}',
                            TO_CHAR(i.id_usuario_brightspace)
                        ),
                    p_method        => v_method,
                    p_body          => l_body,
                    p_id_generado   => v_seq
                );
                
                  ------------------------------------------------------------------
                -- Actualizar tabla intermedia
                ------------------------------------------------------------------

                UPDATE SZRPEBP
                   SET SZRPEBP_STATE       = 'SEND',
                       SZRPEBP_ID_MAESTRO  = v_seq
                 WHERE ROWID = i.rid;
                 
                 
            
            END IF;
 
                ------------------------------------------------------------------
                -- Registrar OK
                ------------------------------------------------------------------

                v_error_message :=
                    'El docente ' ||
                    i.spriden_id ||
                    ' se ' ||
                    i.action_label_user ||
                    ' correctamente';

                PKG_INT_BRIPACE_TERM.p_registra_error_log(
                    p_business_line => 'ONLINE',
                    p_op_type       => i.action_user,
                    p_term_code     => i.term_code,
                    p_ptrm_code     => NULL,
                    p_crn            => NULL,
                    p_pidm          => i.pidm,
                    p_state         => 'OK',
                    p_error_code    => 'OK',
                    p_error_message => v_error_message
                );


            EXCEPTION
                WHEN OTHERS THEN
                    v_error_message := SQLERRM;

                    ------------------------------------------------------------------
                    -- Registrar error
                    ------------------------------------------------------------------

                    PKG_INT_BRIPACE_TERM.p_registra_error_log(
                        p_business_line => 'ONLINE',
                        p_op_type       => i.action_user,
                        p_term_code     => i.term_code,
                        p_ptrm_code     => NULL,
                        p_crn            => NULL,
                        p_pidm          => i.pidm,
                        p_state         => 'ERROR',
                        p_error_code    => SQLCODE,
                        p_error_message => v_error_message
                    );

            END;

        END LOOP;

    END IF; -- v_url_cfg IS NOT NULL

EXCEPTION
    WHEN OTHERS THEN

        ------------------------------------------------------------------
        -- Error general del proceso
        ------------------------------------------------------------------

        DBMS_OUTPUT.PUT_LINE(
            'ERROR p_registra_persona_int: ' || SQLERRM
        );

        RAISE;

END p_registra_persona_int;

    
-- ACTIVA INACTIVA EL DOCENTE desde el trigger de SIBINST
--
      PROCEDURE p_act_inact_pers(
        p_pidm         NUMBER,
        p_term_code    VARCHAR2,
        p_estado_doc   VARCHAR2
    ) IS
	
	v_rol	   VARCHAR2(20);
    r_pk_parenttab    gobsdtb.gobsdtb_pk_dynsql%TYPE;
    v_rid              varchar2(18):=null;
    v_error     VARCHAR2(500);
    
    v_per_doc    VARCHAR2(6);
    v_per_online VARCHAR2(6);
    v_id_maestro NUMBER;
    
    v_operacion VARCHAR2(1); -- 
 

    BEGIN
     -- validamos si el docente ya existe en la tabla intermedia y si tiene dato adicional LMBO
     DBMS_OUTPUT.PUT_LINE('ENTRA A p_act_inact_pers. PERIODO: '||p_term_code );
        Begin
          select SZRPEBP_ID_MAESTRO
            into v_id_maestro
            from SZRPEBP a
           where SZRPEBP_PIDM = p_pidm;
           
           -- si es activo Actualiza si es inactivo es Delete
           SELECT DECODE(p_estado_doc, 'AC', 'U', 'RC', 'U', 'I')
            INTO v_operacion
            FROM dual;
           
         Exception WHEN OTHERS THEN
           v_id_maestro:= NULL;
           DBMS_OUTPUT.PUT_LINE('ENTRA A p_act_inact_pers. Exception' );
        End;
        
          DBMS_OUTPUT.PUT_LINE('ENTRA A v_id_maestro. '||v_id_maestro );
               -- lo reprocece con el p_estado_doc=  AC para activar e IN para INACTIVAR
              IF v_id_maestro IS NOT NULL  THEN 
                   BEGIN
                     UPDATE SZRPEBP
                       SET SZRPEBP_STATE = p_estado_doc,
                       SZRPEBP_USER_ID = USER,
                       SZRPEBP_ACTIVITY_DATE = SYSDATE,
                       SZRPEBP_OPERACION = v_operacion
                     WHERE SZRPEBP_PIDM = p_pidm
                       AND SZRPEBP_TERM_CODE = p_term_code;
                  --     AND SZRPEBP_LINE_NEG = v_per_online;
                     
                EXCEPTION WHEN OTHERS THEN
                --  NULL; -- MER TMP INCLUIR QUE HACER
                  v_error := SQLERRM;
                     DBMS_OUTPUT.PUT_LINE('ENTRA A ERROR p_act_inact_pers. '||v_error );
                  
                END;
              END IF; -- v_existe_doc
  END p_act_inact_pers;

--

-- Inserta datos supl en tabla intermedia de Periodo

  PROCEDURE p_insert_itzsupl Is
    r_pk_parenttab    gobsdtb.gobsdtb_pk_dynsql%TYPE;
    v_rid              varchar2(18):=null;
    r_gorsdav_rowid   varchar2(18):=null;

  -- mer tmp hay que meter un loop aqui para que vaya insertando en ITZSUPL y luego en datos suplementarios
    Cursor c_supl is
      select SZRPEBP_PIDM PIDM, 
            -- SZRPEBP_LINE_NEG ptrm_code, 
             SZRPEBP_ROL ROL,
             SZRPEBP_ID_MAESTRO id_maestro
        from SZRPEBP B
       WHERE B.SZRPEBP_STATE = 'SEND'
         --AND B.SZRPEBP_LINE_NEG = 'ON'
         ;

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
PROCEDURE p_audit_siricnt
(
    p_pidm              IN SIRICNT.SIRICNT_PIDM%TYPE,
    p_term_code_eff     IN SIRICNT.SIRICNT_TERM_CODE_EFF%TYPE,
    p_fcnt_code         IN SIRICNT.SIRICNT_FCNT_CODE%TYPE,
    p_cntr_code         IN SIRICNT.SIRICNT_CNTR_CODE%TYPE,
    p_def_ind           IN SIRICNT.SIRICNT_DEF_IND%TYPE,
    p_activity_date     IN SIRICNT.SIRICNT_ACTIVITY_DATE%TYPE,
    p_version           IN SIRICNT.SIRICNT_VERSION%TYPE,
    p_user_id           IN SIRICNT.SIRICNT_USER_ID%TYPE,
    p_data_origin       IN SIRICNT.SIRICNT_DATA_ORIGIN%TYPE,
    p_vpdi_code         IN SIRICNT.SIRICNT_VPDI_CODE%TYPE,
    p_operation         IN VARCHAR2
)
IS
BEGIN

    INSERT INTO PRGNREP.SZASIRI
    (
        SZASIRI_PIDM,
        SZASIRI_TERM_CODE_EFF,
        SZASIRI_FCNT_CODE,
        SZASIRI_CNTR_CODE,
        SZASIRI_DEF_IND,
        SZASIRI_ACTIVITY_DATE,
        SZASIRI_VERSION,
        SZASIRI_USER_ID,
        SZASIRI_DATA_ORIGIN,
        SZASIRI_VPDI_CODE,
        SZASIRI_OPERATION
    )
    VALUES
    (
        p_pidm,
        p_term_code_eff,
        p_fcnt_code,
        p_cntr_code,
        p_def_ind,
        p_activity_date,
        p_version,
        p_user_id,
        p_data_origin,
        p_vpdi_code,
        p_operation
    );

END p_audit_siricnt;

-- proc para ELIMINAR
PROCEDURE p_registra_persona(
        p_pidm         NUMBER,
        p_term_code    VARCHAR2
    ) IS
	
	v_rol	   VARCHAR2(20);
    r_pk_parenttab    gobsdtb.gobsdtb_pk_dynsql%TYPE;
    v_rid              varchar2(18):=null;
    v_error     VARCHAR2(500);
    
    v_per_doc    VARCHAR2(6);
    v_per_online VARCHAR2(6);
    v_existe_doc NUMBER;
    v_existe_inf_ad number;
    v_id VARCHAR2(9);
    v_rol_int VARCHAR2(20);

    BEGIN
    -- Valida que el periodo registrado sea el de la variable GTVSDAX
    -- indica el periodo donde los docentes(SIAINST) tienen los datos suplementarios SMART_ONLINE, SMART_FLEX_SMART_CYP
     v_per_doc:= pkg_int_bripace_term.f_get_gtvsdax(
                'ONLINE',
                'PER_DOC',
                'DEV_INT_BRIGTHSPACE'
            );
    
    dbms_output.put_line('registra_per. v_per_doc: '||v_per_doc);
    
	   IF v_per_doc = p_term_code THEN -- si el periodo de gtvsdax es el periodo del docente de sianst entonces se va en la integracion
        
            SELECT ROWID into v_rid  
              FROM SIBINST 
             WHERE SIBINST_PIDM = p_pidm AND SIBINST_TERM_CODE_EFF = p_term_code;
             
              r_pk_parenttab:=gp_goksdif.f_get_pk('SIBINST',v_rid);
             
              v_rol:=   UPPER(TRIM(PKG_INT_BRIPACE_PERS.fn_get_gorsdav_value(
                                        'SIBINST', 'SMART_ONLINE', 
                                        r_pk_parenttab)));
             
              v_id := GB_COMMON.F_GET_ID(p_pidm);
                                        
             -- validacion del cambio de ROL
             -- Se valida que rol tiene en la tabla intermedia.
             -- Si el ROL es diferente debe realizar el proceso de cambio de ROL y no otro
             Begin
               SELECT SZRPEBP_ROL into v_rol_int
                 FROM SZRPEBP WHERE SZRPEBP_PIDM = p_pidm;
             Exception When Others Then
               NULL;
             End;
             
            IF v_rol_int != v_rol THEN
              p_cambio_rol( p_pidm        => p_pidm,    
                            p_term_code   => p_term_code,
                            p_id_ma       => NULL,
                            p_rol         => v_rol); -- LLAMA PROC DE CAMBIO DE ROL
            ELSE
            -- Sino, continúa con el proceso de creacion, activacion o inactivacion de acuerdo al caso
                           
                
                -- Valida si tiene informacion adicional en spaiden
                 SELECT COUNT(1) 
                      INTO v_existe_inf_ad 
                      FROM  GORADID
                      WHERE GORADID_PIDM = p_pidm
                        AND GORADID_ADID_CODE= 'LMBO';
                        
            
    dbms_output.put_line('registra_per. v_rol: '||v_rol||' v_existe_inf_ad '||v_existe_inf_ad);
               
               -- Si el rol es ON, AS y no tiene informacion adicional, se debe crear en la integracion
               IF v_rol IN ('ON', 'AS') AND v_existe_inf_ad = 0 THEN
                -- IF v_existe_doc = 0   THEN -- SI NO existe y tiene DATO SUPLEMENTARIO ON o AS, debe insertar en tabla intermedia
                
                           -- validamos si el docente ya existe en la tabla intermedia
               select count(*) into v_existe_doc
                 from SZRPEBP 
                where SZRPEBP_PIDM = p_pidm;
                
                IF v_existe_doc >= 1 THEN
                  v_error := 'El docente '|| v_id ||' ya existe en la integración';
                
                   PKG_INT_BRIPACE_TERM.p_registra_error_log(
                        p_business_line => 'ONLINE',
                        p_op_type       => 'CREATE_USER',
                        p_term_code     => p_term_code,
                        p_pidm          => p_pidm,
                        p_error_code    => 'CREATE_USER_ERR',
                        p_error_message => v_error);
                  RETURN; -- SI EXISTE EL DOCENTE SE SALE
                END IF;
               
               
    dbms_output.put_line(' ENTRA PRIMER IF');
    
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
                            0, -- Sin linea de neg
                            v_rol,
                            'NEW',
                            'I',
                            1,
                            'SIBINST',
                            USER,
                            SYSDATE
                        );
                EXCEPTION WHEN OTHERS THEN            
                  v_error := SQLERRM;
                  
                    PKG_INT_BRIPACE_TERM.p_registra_error_log(
                        p_business_line => 'ONLINE',
                        p_op_type       => 'CREATE_USER',
                        p_term_code     => p_term_code,
                        p_pidm          => p_pidm,
                        p_error_code    => 'ORACLE_ERR',
                        p_error_message => v_error);
                   END;
                
               ELSIF (v_rol NOT IN ('ON', 'AS') OR (v_rol IS NULL)) AND v_existe_inf_ad >=1 THEN
               -- INACTIVAR usuario MER TMP
               
    dbms_output.put_line('registra_per.INACTIVA');
    
                 PKG_INT_BRIPACE_PERS.p_act_inact_pers(
                                p_pidm   =>   p_pidm    ,
                                p_term_code =>  p_term_code  ,
                                p_estado_doc => 'IN' );
                 
                 
                ELSIF v_rol IN ('ON', 'AS') AND v_existe_inf_ad >=1 THEN
               -- ACTIVAR usuario MER TMP
                BEGIN
               
               
    dbms_output.put_line('registra_per. ACTIVA');
    
                  PKG_INT_BRIPACE_PERS.p_act_inact_pers(
                                p_pidm   =>   p_pidm    ,
                                p_term_code =>  p_term_code  ,
                                p_estado_doc => 'AC' );
                END;
               
               ELSE 
                 
    dbms_output.put_line(' ENTRA SEG IF');
                
                 v_error:= 'No se identifica linea de negocio o ID_ROL no permitido.'|| v_id;
               
                 PKG_INT_BRIPACE_TERM.p_registra_error_log(
                        p_business_line => 'ONLINE',
                        p_op_type       => 'CREATE_USER',
                        p_term_code     => p_term_code,
                        p_pidm          => p_pidm,
                        p_error_code    => 'ERR_ID_ROL',
                        p_error_message => v_error);
               
               END IF;
        END IF; -- rol
    END IF; -- v_per_doc = p_term_code
    
    
    dbms_output.put_line(' ENTRA FIN.'||LENGTH(v_rol));
  END p_registra_persona;
  
      PROCEDURE p_registra_persona_int_OLD IS

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
        
        v_error             VARCHAR2(200);
        v_error_message     VARCHAR2(1000);
      

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
    
    -- validacion de registros CEIN Y PREFERIDO
    
      FOR e IN (
        SELECT a.SZRPEBP_PIDM pidm, SZRPEBP_TERM_CODE term_code
          FROM SZRPEBP a
         WHERE a.SZRPEBP_STATE = 'NEW'
           AND NOT EXISTS (
                SELECT 1
                  FROM GOREMAL g
                 WHERE g.GOREMAL_PIDM = a.SZRPEBP_PIDM
                   AND g.GOREMAL_EMAL_CODE = 'CEIN'
                   AND g.GOREMAL_PREFERRED_IND = 'Y'
           )
    )
    LOOP
    
        PKG_INT_BRIPACE_TERM.p_registra_error_log(
            p_business_line => 'ONLINE',
            p_op_type       => 'CREATE_USER',
            p_term_code     => e.term_code,
            p_pidm          => e.pidm,
            p_error_code    => 'EMAIL_NOT_FOUND',
            p_error_message => 'El docente no tiene un correo CEIN marcado como preferido (GOREMAL_PREFERRED_IND = Y).'
        );
    
    END LOOP;
    
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
                   
                   DECODE(SZRPEBP_ROL,'AS', TO_NUMBER(v_role_id_as), 'ON', TO_NUMBER(v_role_id_on) ) rol_doc,--TO_NUMBER(v_role_id_on) rol_doc,
                   
                   c.GOREMAL_EMAL_CODE emal_code,
                   c.GOREMAL_PREFERRED_IND pref_ind,
                   a.SZRPEBP_TERM_CODE term_code
              FROM SZRPEBP a
              INNER JOIN SPRIDEN b ON a.SZRPEBP_PIDM = b.SPRIDEN_PIDM
              INNER JOIN GOREMAL c ON c.GOREMAL_PIDM = b.SPRIDEN_PIDM AND c.GOREMAL_EMAL_CODE = 'CEIN' AND GOREMAL_PREFERRED_IND = 'Y'
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
                 
                IF SQL%ROWCOUNT = 1 THEN   
                  v_error_message:= 'DOCENTE '||r.spriden_id||' creado correctamente';
             
                   PKG_INT_BRIPACE_TERM.p_registra_error_log(
                        p_business_line => 'ONLINE',
                        p_op_type       => 'CREATE_USER',
                        p_term_code     => r.term_code,
                        p_ptrm_code     => NULL,
                        p_crn           => NULL,
                        p_pidm          => r.pidm,
                        p_state           => 'OK',
                        p_error_code    => 'OK',
                        p_error_message => v_error_message);
                END IF;  
                 
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
        
 -- Procesa los registros que se van a activar/ inactivar que vienen de la tabla intermedia
        BEGIN
           SELECT IZTZCFG_REQUEST_URL, IZTZCFG_REQUEST_METHOD
             INTO v_url, v_method
          from desarrollo.IZTZCFG
          WHERE IZTZCFG_IZTID = 'ONL_ACTIVE_USER';
        EXCEPTION
         WHEN NO_DATA_FOUND THEN
           v_url    := NULL;
           v_method := NULL;
        END; 
  
        IF v_url IS NOT NULL   AND v_method IS NOT NULL THEN
          v_seq:= null;
        
           dbms_output.put_line('mensaje URL: '||v_url||' '||v_method);
           
            FOR i in (
             select a.ROWID rid,
                    INTEGRACION.SEQ_ITZBGSP.NEXTVAL v_seq,
                    SZRPEBP_ID_MAESTRO id_maestro, 
                    b.GORADID_ADDITIONAL_ID id_usuario_brightspace,
                    SZRPEBP_STATE,
                    SZRPEBP_PIDM pidm,
                    SPRIDEN_ID,
                    SZRPEBP_TERM_CODE term_code,
                    CASE 
                      WHEN SZRPEBP_STATE = 'AC' THEN 'ACTIVE_USER'
                      ELSE 'INACTIVE_USER' END action_user,
                    CASE 
                      WHEN SZRPEBP_STATE = 'AC' THEN 'activó'
                      ELSE 'inactivó' END action_label_user
                     from SZRPEBP a, GORADID b, SPRIDEN C
                    where a.SZRPEBP_PIDM = b.GORADID_PIDM
                      and a.SZRPEBP_PIDM = c.SPRIDEN_PIDM
                      and b.GORADID_ADID_CODE = 'LMBO'
                      and a.SZRPEBP_STATE IN ('AC', 'IN')
                      and SPRIDEN_CHANGE_IND is null
            ) 
            LOOP
              BEGIN
                SELECT JSON_ARRAY( JSON_OBJECT(
                 'request' VALUE JSON_OBJECT(
                 'id' VALUE i.v_seq,
                 'endpoint' VALUE REPLACE( v_url, '{ID_USUARIO_BRIGHTSPACE}',TO_CHAR(i.id_usuario_brightspace) ),
                 'method' VALUE v_method,
                 'body' VALUE JSON_OBJECT(
                     'IsActive' VALUE
                         CASE
                             WHEN i.SZRPEBP_STATE = 'AC'
                             THEN 'true'
                             ELSE 'false'
                         END FORMAT JSON )),
                'response' VALUE NULL    RETURNING CLOB ) RETURNING CLOB )
                INTO l_json
                FROM dual;
                
                -- Se inserta en la tabla de integracion
                
                
           dbms_output.put_line('mensaje VA A INSERTAR itzbgsp. id_maestro'||i.id_maestro);
           
                BEGIN
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
                    i.v_seq,
                    'ONLINE',
                    l_json,
                    NULL,
                    SYSDATE,
                    SYSDATE,
                    NULL,
                    i.action_user,
                    'PENDING'
                );
                EXCEPTION WHEN OTHERS THEN
                  v_error_message:=sqlerrm;
                
                  dbms_output.put_line('error: '||sqlerrm);
                   PKG_INT_BRIPACE_TERM.p_registra_error_log(
                        p_business_line => 'ONLINE',
                        p_op_type       => i.action_user,
                        p_term_code     => i.term_code,
                        p_ptrm_code     => NULL,
                        p_crn            => NULL,
                        p_pidm          => i.pidm,
                        p_state         => 'ERROR',
                        p_error_code    => SQLCODE,
                        p_error_message => v_error_message
                    );

                    ------------------------------------------------------------------
                    -- NO CONTINUAR CON ESTE DOCENTE
                    ------------------------------------------------------------------
                    CONTINUE;
                  
                END;
                ------------------------------------------------------------------
                -- Actualizar estado en SZRTMBP
                ------------------------------------------------------------------
                UPDATE SZRPEBP
                   SET SZRPEBP_STATE = 'SEND',
                       SZRPEBP_ID_MAESTRO= i.id_maestro
                 WHERE ROWID = i.rid;
                 
                 v_error_message:= 'El docente '||i.SPRIDEN_ID||' se '||i.action_label_user|| ' correctamente';
             
                   PKG_INT_BRIPACE_TERM.p_registra_error_log(
                        p_business_line => 'ONLINE',
                        p_op_type       => i.action_user,
                        p_term_code     => i.term_code,
                        p_ptrm_code     => NULL,
                        p_crn           => NULL,
                        p_pidm          => i.pidm,
                        p_state           => 'OK',
                        p_error_code    => 'OK',
                        p_error_message => v_error_message);

               EXCEPTION WHEN OTHERS THEN
                  v_error_message:=sqlerrm;
                
                  dbms_output.put_line('error 2: '||sqlerrm);
                  
                  PKG_INT_BRIPACE_TERM.p_registra_error_log(
                        p_business_line => 'ONLINE',
                        p_op_type       => i.action_user,
                        p_term_code     => i.term_code,
                        p_ptrm_code     => NULL,
                        p_crn           => NULL,
                        p_pidm          => i.pidm,
                        p_state           => 'OK',
                        p_error_code    => 'OK',
                        p_error_message => v_error_message);
              
              END;
           
            END LOOP;
        END IF;

    END p_registra_persona_int_OLD;

END PKG_INT_BRIPACE_PERS;