create or replace PACKAGE                            PKG_INT_BRIPACE_PERS AS

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





-- Inserta datos adicionales docentes
PROCEDURE p_insert_goradid(p_id_maestro NUMBER);

-- Inserta datos adicionales alumnos
PROCEDURE p_insert_goradid_alu(p_id_maestro NUMBER);


-- Activa, inactiva docentes de SIAINST
 PROCEDURE p_act_inact_pers(
        p_pidm         NUMBER,
        p_term_code    VARCHAR2,
        p_estado_doc   VARCHAR2,
        p_rol_new      VARCHAR2 default null);
        
        
        
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


PROCEDURE p_registra_persona_int;

PROCEDURE p_registra_alumnos;
PROCEDURE p_registra_alumnos_int;

FUNCTION f_existe_inf_ad ( p_pidm IN goradid.goradid_pidm%TYPE) RETURN VARCHAR2;

FUNCTION f_get_inf_ad (  p_pidm IN GORADID.GORADID_PIDM%TYPE) RETURN GORADID.GORADID_ADDITIONAL_ID%TYPE;

FUNCTION f_existe_email ( p_pidm IN number) RETURN VARCHAR2;

PROCEDURE p_inactive_user_alu;

PROCEDURE P_PROCESA_ESTADO_ALU (
    P_OP_TYPE   IN VARCHAR2,
    P_IS_ACTIVE IN VARCHAR2
);

FUNCTION F_VALIDA_RETENCION (
    P_PIDM     IN NUMBER,
    P_OP_TYPE  IN VARCHAR2
) RETURN VARCHAR2;

END PKG_INT_BRIPACE_PERS;
create or replace PACKAGE BODY                              PKG_INT_BRIPACE_PERS AS  

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
                   

                PKG_INT_BRIPACE_UTIL.p_registra_error_log(
                    p_business_line => 'ONLINE',
                    p_op_type       => v_tipo_enroll,
                    p_id_maestro    => v_seq,
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
    v_exist_cein NUMBER;
    v_error_message   VARCHAR2(300);
    
    v_tipo_user        VARCHAR2(15):= 'CREATE_USER_TH';

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
            v_error:= 'No se identifica linea de negocio por duplicidad, ID docente: '|| v_id;
          
           PKG_INT_BRIPACE_UTIL.p_registra_error_log_uk(
                        p_business_line => 'ONLINE',
                        p_op_type       => v_tipo_user, 
                        p_term_code     => p_term_code,
                        p_pidm          => p_pidm,
                        p_error_code    => 'ERR_ID_ROL_DUP',
                        p_error_message => v_error);
          RETURN; -- Si esta duplicado se sale
         END IF;
       
       -- Validacion de datos adicionales
          SELECT COUNT(1) 
                      INTO v_existe_inf_ad 
                      FROM  GORADID
                      WHERE GORADID_PIDM = p_pidm
                        AND GORADID_ADID_CODE= 'LMBO';
                        
         -- VALIDO SI EL DOCENTE  TIENE CORREO CEIN 
            SELECT COUNT(*) INTO v_exist_cein
                  FROM GOREMAL g
                 WHERE g.GOREMAL_PIDM = p_pidm
                   AND g.GOREMAL_EMAL_CODE = 'CEIN'
                   AND g.GOREMAL_PREFERRED_IND = 'Y';
                   
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
                                        p_estado_doc => 'RC' ,
                                        p_rol_new  =>   p_cntr_code);
                 
                 ELSE
                     PKG_INT_BRIPACE_PERS.p_act_inact_pers(
                                        p_pidm   =>   p_pidm    ,
                                        p_term_code =>  p_term_code  ,
                                        p_estado_doc => 'AC' );
                 END IF;
                                    
               -- sin datos adicionales, se CREA                
               ELSE 
                 IF v_exist_cein >= 1 THEN
                      r_docente.SZRPEBP_PIDM:= p_pidm;
                      r_docente.SZRPEBP_TERM_CODE:= p_term_code;
                      r_docente.SZRPEBP_LINE_NEG:= p_fcnt_code;
                      r_docente.SZRPEBP_ROL:= p_cntr_code;
                      r_docente.SZRPEBP_DATA_ORIGIN:= 'SIRINCT';
                    
                   
                      PKG_INT_BRIPACE_PERS.p_intermedia_szrpebp(
                        p_registro      => r_docente,
                        p_business_line => 'ONLINE',
                        p_op_type       => 'CREATE_TERM');
                 ELSE -- no tiene correo LOG
                   v_error_message:= 'El docente no tiene un correo CEIN marcado como preferido ' ||
                                     '(GOREMAL_PREFERRED_IND = Y).';
                   
                   PKG_INT_BRIPACE_UTIL.p_registra_error_log(
                        p_business_line => 'ONLINE',
                        p_op_type       => v_tipo_user, 
                        p_term_code     => p_term_code,
                        p_ptrm_code     => NULL,
                        p_data_origin   => 'SIRICNT',
                        p_crn           => NULL,
                        p_pidm          => p_pidm,
                        p_state         => 'ERROR',
                        p_error_code    => 'EMAIL_NOT_FOUND',
                        p_error_message => v_error_message
                    );
                 END IF;
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
            IF v_existe_inf_ad = 0 THEN
            
              DELETE SZRPEBP WHERE SZRPEBP_PIDM = p_pidm
                AND SZRPEBP_STATE = 'NEW';
            
            ELSE 
               SELECT count(*) INTO v_cant_cntr
               FROM SIRICNT
              WHERE SIRICNT_PIDM = p_pidm
                AND SIRICNT_TERM_CODE_EFF = p_term_code;
                
               IF v_cant_cntr = 0 THEN
                   PKG_INT_BRIPACE_PERS.p_act_inact_pers(
                                        p_pidm   =>   p_pidm    ,
                                        p_term_code =>  p_term_code  ,
                                        p_estado_doc => 'IN' );                            
                END IF;--v_cant_cntr
            END IF;--v_exist_cein
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
        PKG_INT_BRIPACE_UTIL.p_registra_error_log_uk(
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

            PKG_INT_BRIPACE_UTIL.p_registra_error_log(
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
   
   v_tipo_user        VARCHAR2(15):= 'CREATE_USER_TH';
   
   

BEGIN  
    ------------------------------------------------------------------
    -- Configuración
    ------------------------------------------------------------------
    
    PKG_INT_BRIPACE_UTIL.p_obtener_config_api(
        p_operacion => 'CREA_USER', -- funciona para docente y alumno
        p_url       => v_url,
        p_method    => v_method,
        p_path      => v_path
    );
/*
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

*/
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

        PKG_INT_BRIPACE_UTIL.p_registra_error_log_uk(
            p_business_line => 'ONLINE',
            p_op_type       => v_tipo_user, 
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
                    p_op_type       => v_tipo_user, --'CREATE_USER',
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
                        'Docente ' ||
                        r.spriden_id ||
                        ' creado correctamente';

                    PKG_INT_BRIPACE_UTIL.p_registra_error_log(
                        p_business_line => 'ONLINE',
                        p_op_type       => v_tipo_user, --'CREATE_USER',
                        p_id_maestro    => v_seq,
                        p_term_code     => r.term_code,
                        p_ptrm_code     => NULL,
                        p_data_origin   => 'SIRICNT',
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

                PKG_INT_BRIPACE_UTIL.p_registra_error_log(
                    p_business_line => 'ONLINE',
                    p_op_type       => v_tipo_user, --'CREATE_USER',
                    p_term_code     => r.term_code,
                    p_ptrm_code     => NULL,
                    p_data_origin   => 'SIRICNT',
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
                    p_id_generado   => v_seq,
                    p_pidm          => i.pidm,
                    p_id_spriden    => i.spriden_id
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

                PKG_INT_BRIPACE_UTIL.p_registra_error_log(
                    p_business_line => 'ONLINE',
                    p_op_type       => i.action_user,
                    p_id_maestro    => v_seq,
                    p_term_code     => i.term_code,
                    p_ptrm_code     => NULL,
                    p_data_origin   => 'SIRICNT',
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
                    p_id_generado   => v_seq,
                    p_pidm          => i.pidm,
                    p_id_spriden    => i.spriden_id
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

                PKG_INT_BRIPACE_UTIL.p_registra_error_log(
                    p_business_line => 'ONLINE',
                    p_op_type       => i.action_user,
                    p_id_maestro    => v_seq,
                    p_term_code     => i.term_code,
                    p_ptrm_code     => NULL,
                    p_data_origin   => 'SIRICNT',
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

                    PKG_INT_BRIPACE_UTIL.p_registra_error_log(
                        p_business_line => 'ONLINE',
                        p_op_type       => i.action_user,
                        p_term_code     => i.term_code,
                        p_ptrm_code     => NULL,
                        p_data_origin   => 'SIRICNT',
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
        p_estado_doc   VARCHAR2,
        p_rol_new      VARCHAR2 default null
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
                       SZRPEBP_ROL = NVL(p_rol_new, SZRPEBP_ROL),
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

  PROCEDURE p_insert_goradid(p_id_maestro NUMBER) Is
    r_pk_parenttab    gobsdtb.gobsdtb_pk_dynsql%TYPE;
    v_rid              varchar2(18):=null;
    r_gorsdav_rowid   varchar2(18):=null;
    
    v_tipo_user        VARCHAR2(15):= 'CREATE_USER_TH';

  -- mer tmp hay que meter un loop aqui para que vaya insertando en ITZSUPL y luego en datos suplementarios
    Cursor c_supl is
      select SZRPEBP_PIDM PIDM, 
            -- SZRPEBP_LINE_NEG ptrm_code, 
             SZRPEBP_ROL ROL,
             SZRPEBP_ID_MAESTRO id_maestro
        from SZRPEBP B
       WHERE B.SZRPEBP_STATE = 'SEND'
         AND SZRPEBP_ID_MAESTRO = p_id_maestro
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
             AND B.OP_TYPE = v_tipo_user
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

            
           PKG_INT_BRIPACE_UTIL.P_ACTUALIZA_ESTADO_ITZBGSP( i.ID_MAESTRO, v_tipo_user, 'COMPLETED_OK');        
            
           PKG_INT_BRIPACE_UTIL.P_ACTUALIZA_INTERMEDIA_STATE(
                P_TIPO       => v_tipo_user, 
                P_ID_MAESTRO => I.ID_MAESTRO,
                P_STATE_OLD  => 'SEND',
                P_STATE      => 'APPLIED'
            );
              
      End Loop;
      
    END p_insert_goradid;
    
    -- Inserta en datos suplemen los datos del alumno
      PROCEDURE p_insert_goradid_alu(p_id_maestro NUMBER) Is
      r_pk_parenttab    gobsdtb.gobsdtb_pk_dynsql%TYPE;
      v_rid              varchar2(18):=null;
      r_gorsdav_rowid   varchar2(18):=null;
    
      v_tipo_user        VARCHAR2(15):= 'CREATE_USER_ST';

  -- mer tmp hay que meter un loop aqui para que vaya insertando en ITZSUPL y luego en datos suplementarios
    Cursor c_supl is
      select SZRSTBP_PIDM PIDM, 
            -- SZRPEBP_LINE_NEG ptrm_code, 
             SZRSTBP_ROL_ID ROL,
             SZRSTBP_ID_MAESTRO id_maestro
        from szrstbp B
       WHERE B.SZRSTBP_STATE = 'SEND'
         AND SZRSTBP_ID_MAESTRO = p_id_maestro
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
           SELECT     M.SZRSTBP_PIDM,
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
                INNER JOIN SZRSTBP M
                   ON M.SZRSTBP_ID_MAESTRO = B.ID
           WHERE M.SZRSTBP_PIDM = i.pidm
             AND B.STATUS = 'PROCESSED_OK'
             AND B.OP_TYPE = v_tipo_user
             AND B.RESPONSE IS NOT NULL
             AND JSON_VALUE(B.RESPONSE, '$[0].response.code') = '200'
             AND JSON_EXISTS(B.RESPONSE,'$[0].response.body.UserId')
             AND NOT EXISTS
             (
                 SELECT 1
                 FROM GORADID S
                 WHERE S.GORADID_PIDM =  M.SZRSTBP_PIDM
                   AND S.GORADID_ADID_CODE = 'LMBO'
             );

            
           PKG_INT_BRIPACE_UTIL.P_ACTUALIZA_ESTADO_ITZBGSP( i.ID_MAESTRO, v_tipo_user, 'COMPLETED_OK');        
            
           PKG_INT_BRIPACE_UTIL.P_ACTUALIZA_INTERMEDIA_STATE(
                P_TIPO       => v_tipo_user, 
                P_ID_MAESTRO => I.ID_MAESTRO,
                P_STATE_OLD  => 'SEND',
                P_STATE      => 'APPLIED'
            );
              
      End Loop;
      
    END p_insert_goradid_alu;


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
      WHEN OTHERS THEN 
        NULL;
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

-- registra masivamente en tabla intermedia a la creacion de alumnos

PROCEDURE p_registra_alumnos
IS
    v_periodo VARCHAR2(2);
BEGIN
    -- Obtener el periodo ONLINE parametrizado
    v_periodo := PKG_INT_BRIPACE_TERM.F_GET_GTVSDAX(
                     'ONLINE',
                     'PERIODO',
                     'DEV_INT_BRIGTHSPACE'
                 );

    -- Recorrer alumnos inscritos en el periodo ONLINE,
    -- que no exista en SZRSTBP, que solo exista 1 vez porque es creación
    FOR R IN (
        SELECT DISTINCT
               SFRSTCR_PIDM,
               SFRSTCR_TERM_CODE
        FROM SFRSTCR
        WHERE SUBSTR(SFRSTCR_TERM_CODE, 5, 2) = v_periodo
          AND PKG_INT_BRIPACE_PERS.F_EXISTE_INF_AD(
                  SFRSTCR_PIDM
              ) = 'N'
          AND NOT EXISTS (
              SELECT 1
              FROM SZRSTBP T
              WHERE T.SZRSTBP_PIDM = SFRSTCR_PIDM
              --  AND T.SZRSTBP_TERM_CODE = SFRSTCR_TERM_CODE
                AND SZRSTBP_STATE != 'FAIL'
                AND T.SZRSTBP_LINE_NEG = 'ON'
          )
         -- and SFRSTCR_PIDM= 1159406 --mer tmp
    )
    LOOP
      -- antes de insertar en tabla intermedia, valida si tiene email CEIN preferido 
      IF PKG_INT_BRIPACE_PERS.f_existe_email(r.SFRSTCR_PIDM) = 'Y' THEN
      
        INSERT INTO SZRSTBP (
            SZRSTBP_PIDM,
            SZRSTBP_TERM_CODE,
            SZRSTBP_LINE_NEG,
            SZRSTBP_ROL_ID,
            SZRSTBP_USER_ID_BS,
            SZRSTBP_STATE,
            SZRSTBP_STATE_DET,
            SZRSTBP_OPERACION,
            SZRSTBP_ID_MAESTRO,
            SZRSTBP_VERSION,
            SZRSTBP_DATA_ORIGIN,
            SZRSTBP_USER_ID
        )
        VALUES (
            r.SFRSTCR_PIDM,
            r.SFRSTCR_TERM_CODE,
            'ON',
            110,
            NULL,
            'NEW',
            NULL,
            'I',
            NULL,
            1,
            'SFRSTCR',
            USER
        );
      ELSE
      --LOG controlado para que no duplique 
        PKG_INT_BRIPACE_UTIL.p_registra_error_log_uk(
            p_business_line => 'ONLINE',
            p_op_type       => 'CREATE_USER_ST',
            p_term_code     => r.SFRSTCR_TERM_CODE,
            p_pidm          => r.SFRSTCR_PIDM,
            p_error_code    => 'EMAIL_NOT_FOUND',
            p_error_message =>
                'El estudiante no tiene un correo CEIN marcado como preferido ' ||
                '(GOREMAL_PREFERRED_IND = Y).'
        );
        
      END IF;
    END LOOP;

END p_registra_alumnos;


PROCEDURE p_registra_alumnos_int IS

    ------------------------------------------------------------------
    -- Variables
    ------------------------------------------------------------------
    v_url             VARCHAR2(1000);
    v_path            VARCHAR2(500);
    v_method          VARCHAR2(20);
    v_seq             NUMBER;
    v_error           VARCHAR2(4000);
    v_error_message   VARCHAR2(4000);
    l_body            CLOB;
    v_tipo_user        VARCHAR2(15):= 'CREATE_USER_ST';
    

    ------------------------------------------------------------------
    -- Cursor: alumnos pendientes de integración
    -- Que tengan correo CEIN, Con informac adicional de brigspace en intermedia 
    ------------------------------------------------------------------
    CURSOR c_alumnos IS
        SELECT
            a.ROWID AS rid,
            a.SZRSTBP_PIDM AS pidm,
            a.SZRSTBP_TERM_CODE AS term_code,
            a.SZRSTBP_ROL_ID AS rol_id,
            b.SPRIDEN_ID AS spriden_id,
            b.SPRIDEN_FIRST_NAME AS fname,
            b.SPRIDEN_MI AS mname,
            b.SPRIDEN_LAST_NAME AS lname,
            c.GOREMAL_EMAIL_ADDRESS AS email
        FROM SZRSTBP a
        INNER JOIN SPRIDEN b
            ON a.SZRSTBP_PIDM = b.SPRIDEN_PIDM
        INNER JOIN GOREMAL c
            ON c.GOREMAL_PIDM = b.SPRIDEN_PIDM
           AND c.GOREMAL_EMAL_CODE = 'CEIN'
           AND c.GOREMAL_PREFERRED_IND = 'Y'
        WHERE b.SPRIDEN_CHANGE_IND IS NULL
          AND a.SZRSTBP_STATE = 'NEW'
          AND PKG_INT_BRIPACE_PERS.F_EXISTE_INF_AD(
                  a.SZRSTBP_PIDM
              ) = 'N';

BEGIN

    ------------------------------------------------------------------
    -- Obtener configuración del endpoint
    ------------------------------------------------------------------
    -- Inicializar v_url, v_path y v_method con la configuración
    -- existente para la operación CREA_USER de ONLINE.
    -- Mantener aquí el mismo bloque de configuración utilizado
    -- por los demás procedimientos del paquete.
    
     PKG_INT_BRIPACE_UTIL.p_obtener_config_api(
        p_operacion => 'CREA_USER', -- funciona para docente y alumno
        p_url       => v_url,
        p_method    => v_method,
        p_path      => v_path
    );

    FOR r IN c_alumnos LOOP

        BEGIN

            ------------------------------------------------------------------
            -- Generar JSON del alumno
            ------------------------------------------------------------------
            SELECT JSON_OBJECT(
                       'OrgDefinedId'      VALUE TO_CHAR(r.pidm),
                       'FirstName'         VALUE r.fname,
                       'MiddleName'        VALUE r.mname,
                       'LastName'          VALUE r.lname,
                       'ExternalEmail'     VALUE r.email,
                       'UserName'          VALUE r.email,
                       'RoleId'            VALUE r.rol_id,
                       'IsActive'          VALUE 'true' FORMAT JSON,
                       'SendCreationEmail' VALUE 'false' FORMAT JSON
                       RETURNING CLOB
                   )
              INTO l_body
              FROM dual;

            ------------------------------------------------------------------
            -- Generar registro en ITZBGSP
            ------------------------------------------------------------------
            PKG_INT_BRIPACE_UTIL.P_GENERA_INSERTA_ITZBGSP(
                p_business_line => 'ONLINE',
                p_op_type       => v_tipo_user,
                p_endpoint      => v_url || v_path,
                p_method        => v_method,
                p_body          => l_body,
                p_id_generado   => v_seq
            );

            ------------------------------------------------------------------
            -- Actualizar estado de la intermedia
            ------------------------------------------------------------------
            UPDATE SZRSTBP
               SET SZRSTBP_STATE      = 'SEND',
                   SZRSTBP_ID_MAESTRO = v_seq
             WHERE ROWID = r.rid
               AND SZRSTBP_STATE = 'NEW';

            ------------------------------------------------------------------
            -- Registrar resultado correcto
            ------------------------------------------------------------------
            IF SQL%ROWCOUNT = 1 THEN

                v_error_message :=
                    'Alumno ' || r.spriden_id ||
                    ' creado correctamente';

                PKG_INT_BRIPACE_UTIL.P_REGISTRA_ERROR_LOG(
                    p_business_line => 'ONLINE',
                    p_op_type       => v_tipo_user,
                    p_id_maestro    => v_seq,
                    p_term_code     => r.term_code,
                    p_ptrm_code     => NULL,
                    p_data_origin   => 'SFRSTCR',
                    p_crn           => NULL,
                    p_pidm          => r.pidm,
                    p_state         => 'OK',
                    p_error_code    => 'OK',
                    p_error_message => v_error_message
                );

            END IF;

        EXCEPTION
            WHEN OTHERS THEN

                v_error := SQLERRM;

                ------------------------------------------------------------------
                -- Marcar registro como FAIL
                ------------------------------------------------------------------
                UPDATE SZRSTBP
                   SET SZRSTBP_STATE     = 'FAIL',
                       SZRSTBP_STATE_DET = v_error
                 WHERE ROWID = r.rid;

                ------------------------------------------------------------------
                -- Registrar error
                ------------------------------------------------------------------
                PKG_INT_BRIPACE_UTIL.P_REGISTRA_ERROR_LOG(
                    p_business_line => 'ONLINE',
                    p_op_type       => v_tipo_user,
                    p_id_maestro    => v_seq,
                    p_term_code     => r.term_code,
                    p_ptrm_code     => NULL,
                    p_data_origin   => 'SFRSTCR',
                    p_crn           => NULL,
                    p_pidm          => r.pidm,
                    p_state         => 'ERROR_CREATE_USER',
                    p_error_code    => SQLCODE,
                    p_error_message => v_error
                );

        END;

    END LOOP;

END p_registra_alumnos_int;

---
-- valida si existe dato adicional en persona
FUNCTION f_existe_inf_ad (
    p_pidm IN goradid.goradid_pidm%TYPE
) RETURN VARCHAR2
IS
    v_existe NUMBER;
BEGIN
    SELECT COUNT(1)
    INTO v_existe
    FROM goradid
    WHERE goradid_pidm = p_pidm
      AND goradid_adid_code = 'LMBO';

    RETURN CASE
               WHEN v_existe > 0 THEN 'Y'
               ELSE 'N'
           END;
END f_existe_inf_ad;

FUNCTION f_get_inf_ad (
    p_pidm IN GORADID.GORADID_PIDM%TYPE
) RETURN GORADID.GORADID_ADDITIONAL_ID%TYPE
IS
    v_adic_id GORADID.GORADID_ADDITIONAL_ID%TYPE;
BEGIN

    SELECT GORADID_ADDITIONAL_ID
      INTO v_adic_id
      FROM GORADID
     WHERE GORADID_PIDM = p_pidm
       AND GORADID_ADID_CODE = 'LMBO';

    RETURN v_adic_id;

EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END f_get_inf_ad;

-- valida si existe dato adicional en persona
FUNCTION f_existe_email (
    p_pidm IN number
) RETURN VARCHAR2
IS
    v_existe NUMBER;
BEGIN
     SELECT COUNT(*) INTO v_existe
                  FROM GOREMAL g
                 WHERE g.GOREMAL_PIDM = p_pidm
                   AND g.GOREMAL_EMAL_CODE = 'CEIN'
                   AND g.GOREMAL_PREFERRED_IND = 'Y';

    RETURN CASE
               WHEN v_existe > 0 THEN 'Y'
               ELSE 'N'
           END;
END f_existe_email;


PROCEDURE p_inactive_user_alu
-- Query inactivar general
-- var gtvsdax cod de retenciones
-- la retencion fecha ini <= sysdate y fecha fin >= sysdate
-- debe tener ID datos adicionales GORADIT
-- debe tener un registro de CREATE_USER
-- que no tenga inactive user en su ultimo registro entre inactive/active_user

--** PROCESO INACTIVE_USER: Proceso para inactivar usuario si tiene RETENCION
-- selecciona las personas en mora, tabla  sprhold donde la fecha inicial--> SPRHOLD_FROM_DATE sea menor o igual al SYSDATE
--  y fecha final--> SPRHOLD_TO_DATE >= SYSDATE. Que ademas tenga un registro de ITZBGSP.OP_TYPE=CREATE_USER_ST con ITZBGSP.STATUS= PROCESSED_OK y que NO tenga en su ultimo
-- registro ITZBGSP.OP_TYPE=INACTIVE_USER (de la lista de INACTIVE_USER, ACTIVE_USER, CREATE_USER_ST) (Para no volverlo a inactivar); si está INACTIVE_USER no lo debe volver a inactivar, pero
-- si está ACTIVE_USER ó CREATE_USER_ST en su última operación, si lo debe de inactivar.

-- tambien debe tener datos adicionales:  PKG_INT_BRIPACE_PERS.F_EXISTE_INF_AD(PIDM ) = 'S'
--Cuando tenga esta poblacion va a llamar a este procedure que genera el JSON en la tabla de integracion: PKG_INT_BRIPACE_UTIL.p_genera_inserta_itzbgsp
IS
    ------------------------------------------------------------------
    -- Configuración
    ------------------------------------------------------------------
    V_URL_CFG       DESARROLLO.IZTZCFG.IZTZCFG_REQUEST_URL%TYPE;
    V_METHOD        DESARROLLO.IZTZCFG.IZTZCFG_REQUEST_METHOD%TYPE;

    ------------------------------------------------------------------
    -- Datos del usuario
    ------------------------------------------------------------------
    V_ADDIC_ID      VARCHAR2(100);
    V_BODY          CLOB;
    V_SEQ           NUMBER;

BEGIN
  DBMS_OUTPUT.PUT_LINE('INICIO: ');
    ------------------------------------------------------------------
    -- 1. Obtener configuración para inactivar usuario
    ------------------------------------------------------------------
    BEGIN
        SELECT IZTZCFG_REQUEST_URL,
               IZTZCFG_REQUEST_METHOD
          INTO V_URL_CFG,
               V_METHOD
          FROM DESARROLLO.IZTZCFG
         WHERE IZTZCFG_IZTID = 'ONL_ACTIVE_USER';

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            V_URL_CFG := NULL;
            V_METHOD  := NULL;
    END;

DBMS_OUTPUT.PUT_LINE('V_URL_CFG: '||V_URL_CFG);
    ------------------------------------------------------------------
    -- Validar configuración
    ------------------------------------------------------------------
    IF V_URL_CFG IS NULL OR V_METHOD IS NULL THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'No existe configuración ONL_ACTIVE_USER en IZTZCFG'
        );
    END IF;

DBMS_OUTPUT.PUT_LINE('V_METHOD: '||V_METHOD);

    ------------------------------------------------------------------
    -- 2. Construir BODY para inactivar usuario
    ------------------------------------------------------------------
    SELECT JSON_OBJECT(
               'IsActive' VALUE 'false' FORMAT JSON
               RETURNING CLOB
           )
      INTO V_BODY
      FROM DUAL;

DBMS_OUTPUT.PUT_LINE('V_BODY: '||V_BODY);
    ------------------------------------------------------------------
    -- 3. Obtener población de usuarios que deben inactivarse
    ------------------------------------------------------------------
    FOR I IN (
        WITH ULTIMA_OPERACION AS (
            SELECT ID,
                   PIDM,
                   OP_TYPE,
                   STATUS,
                   ROW_NUMBER() OVER (
                       PARTITION BY PIDM
                       ORDER BY ID DESC
                   ) AS RN
              FROM ITZBGSP
             WHERE OP_TYPE IN (
                       'INACTIVE_USER',
                       'ACTIVE_USER',
                       'CREATE_USER_ST'
                   )
        ),
        -- valor de la variable gtvsdax de los codigos para retenciones
        PARAMETRO AS (
            SELECT DBMS_LOB.SUBSTR(
                       INTEGRACION.PKG_INT_BRIPACE_TERM.F_GET_GTVSDAX(
                           'ONLINE',
                           'INACTIVAR',
                           'DEV_INT_BRIGTHSPACE'
               ),
               4000,
               1
           ) AS VALORES
        FROM DUAL
            ),
            -- pone los codigos para que se comporten como columnas y usarlos en un IN
            CODIGOS AS (
                SELECT TRIM(REGEXP_SUBSTR(VALORES, '[^,]+', 1, LEVEL)) AS CODIGO
                  FROM PARAMETRO
                CONNECT BY LEVEL <= REGEXP_COUNT(VALORES, ',') + 1
            )
        SELECT DISTINCT
               S.SPRIDEN_PIDM AS PIDM,
               S.SPRIDEN_ID   AS SPRIDEN_ID,
               PKG_INT_BRIPACE_PERS.F_GET_INF_AD(
                   S.SPRIDEN_PIDM
               ) AS ID_USUARIO_BRIGHTSPACE,
               U.OP_TYPE AS ULTIMA_OPERACION
          FROM SPRIDEN S
          JOIN ULTIMA_OPERACION U
            ON U.PIDM = S.SPRIDEN_PIDM
           AND U.RN = 1
         WHERE S.SPRIDEN_CHANGE_IND IS NULL
          -- AND  S.SPRIDEN_PIDM = 1159662 --OJO ES PARA LA PRUEBA

           -----------------------------------------------------------
           -- Tener retención vigente
           -----------------------------------------------------------
           AND EXISTS (
                   SELECT 1
                     FROM SPRHOLD H
                    WHERE H.SPRHOLD_PIDM = S.SPRIDEN_PIDM
                      AND H.SPRHOLD_FROM_DATE <= SYSDATE
                      AND H.SPRHOLD_TO_DATE > SYSDATE
                      AND H.SPRHOLD_HLDD_CODE IN ( SELECT CODIGO FROM CODIGOS)
                     UNION
                     SELECT 1
                        FROM SORLCUR U, SGRSTHD D
                        where SORLCUR_PIDM = SGRSTHD_PIDM
                          AND SGRSTHD_PIDM = S.SPRIDEN_PIDM
                          AND SORLCUR_LMOD_CODE='LEARNER'
                          AND SORLCUR_CACT_CODE='ACTIVE'
                          AND SORLCUR_TERM_CODE_END is null
                          AND SORLCUR_CURRENT_CDE='Y'
                          AND SORLCUR_LEVL_CODE ='ON'
                          AND SGRSTHD_FROM_DATE <= SYSDATE
                          AND SGRSTHD_TO_DATE > SYSDATE
               )

           -----------------------------------------------------------
           -- Tener información adicional
           -----------------------------------------------------------
           AND PKG_INT_BRIPACE_PERS.F_EXISTE_INF_AD(
                   S.SPRIDEN_PIDM
               ) = 'Y'

           -----------------------------------------------------------
           -- Tener usuario creado correctamente en Brightspace
           -----------------------------------------------------------
           AND EXISTS (
                   SELECT 1
                     FROM ITZBGSP C
                    WHERE C.PIDM = S.SPRIDEN_PIDM
                      AND C.OP_TYPE = 'CREATE_USER_ST'
                      AND C.STATUS = 'PROCESSED_OK'
               )

           -----------------------------------------------------------
           -- No volver a inactivar si su última operación
           -- ya fue INACTIVE_USER
           -----------------------------------------------------------
           AND U.OP_TYPE <> 'INACTIVE_USER'

           -----------------------------------------------------------
           -- Solo inactivar si la última operación fue una
           -- activación o creación de usuario
           -----------------------------------------------------------
           AND U.OP_TYPE IN (
                   'ACTIVE_USER',
                   'CREATE_USER_ST'
               )
    )
    LOOP
      begin
      
      
DBMS_OUTPUT.PUT_LINE('INICIA EL FOR: '||I.PIDM);

        --------------------------------------------------------------
        -- 4. Obtener identificador de usuario en Brightspace
        --------------------------------------------------------------
        V_ADDIC_ID := I.ID_USUARIO_BRIGHTSPACE;

DBMS_OUTPUT.PUT_LINE('PROCESANDO A: '||I.PIDM);

        --------------------------------------------------------------
        -- 5. Generar solicitud INACTIVE_USER
        --------------------------------------------------------------
        PKG_INT_BRIPACE_UTIL.P_GENERA_INSERTA_ITZBGSP(
            P_BUSINESS_LINE => 'ONLINE',
            P_OP_TYPE       => 'INACTIVE_USER',

            P_ENDPOINT      =>
                REPLACE(
                    V_URL_CFG,
                    '{ID_USUARIO_BRIGHTSPACE}',
                    TO_CHAR(V_ADDIC_ID)
                ),

            P_METHOD        => V_METHOD,
            P_BODY          => V_BODY,
            P_ID_GENERADO   => V_SEQ,
            P_PIDM          => I.PIDM,
            P_ID_SPRIDEN    => I.SPRIDEN_ID
        );
  COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
        
        
DBMS_OUTPUT.PUT_LINE('ERROR: '||I.PIDM);

           PKG_INT_BRIPACE_UTIL.p_registra_error_log_uk(
                p_business_line => 'ONLINE',
                p_op_type       => 'CREATE_USER_ST',
                p_term_code     => null,
                p_pidm          => i.PIDM,
                p_error_code    => 'ERR_USER_ST',
                p_error_message =>
                    'Error en el proceso de inactivacion del estudiante'
            );
      end;
    END LOOP;

END p_inactive_user_alu;


PROCEDURE P_PROCESA_ESTADO_ALU (
    P_OP_TYPE   IN VARCHAR2,
    P_IS_ACTIVE IN VARCHAR2
)
-- Query inactivar 
-- var gtvsdax cod de retenciones
-- la retencion fecha ini <= sysdate y fecha fin >= sysdate
-- debe tener ID datos adicionales GORADIT
-- debe tener un registro de CREATE_USER
-- que no tenga inactive user en su ultimo registro entre inactive/active_user

--** PROCESO INACTIVE_USER: Proceso para inactivar usuario si tiene RETENCION
-- selecciona las personas en mora, tabla  sprhold donde la fecha inicial--> SPRHOLD_FROM_DATE sea menor o igual al SYSDATE
--  y fecha final--> SPRHOLD_TO_DATE >= SYSDATE. Que ademas tenga un registro de ITZBGSP.OP_TYPE=CREATE_USER_ST con ITZBGSP.STATUS= PROCESSED_OK y que NO tenga en su ultimo
-- registro ITZBGSP.OP_TYPE=INACTIVE_USER (de la lista de INACTIVE_USER, ACTIVE_USER, CREATE_USER_ST) (Para no volverlo a inactivar); si está INACTIVE_USER no lo debe volver a inactivar, pero
-- si está ACTIVE_USER ó CREATE_USER_ST en su última operación, si lo debe de inactivar.

-- tambien debe tener datos adicionales:  PKG_INT_BRIPACE_PERS.F_EXISTE_INF_AD(PIDM ) = 'S'
--Cuando tenga esta poblacion va a llamar a este procedure que genera el JSON en la tabla de integracion: PKG_INT_BRIPACE_UTIL.p_genera_inserta_itzbgsp
--** PROCESO ACTIVE_USER: igual que el anterior pero la SPRHOLD_TO_DATE < SYSDATE y el ultimo evento del usuario sea INACTIVE_USER

IS
    V_URL_CFG       DESARROLLO.IZTZCFG.IZTZCFG_REQUEST_URL%TYPE;
    V_METHOD        DESARROLLO.IZTZCFG.IZTZCFG_REQUEST_METHOD%TYPE;
    V_ADDIC_ID      VARCHAR2(100);
    V_BODY          CLOB;
    V_SEQ           NUMBER;
BEGIN

    ------------------------------------------------------------
    -- 1. Obtener configuración
    ------------------------------------------------------------
    SELECT IZTZCFG_REQUEST_URL,
           IZTZCFG_REQUEST_METHOD
      INTO V_URL_CFG,
           V_METHOD
      FROM DESARROLLO.IZTZCFG
     WHERE IZTZCFG_IZTID = 'ONL_ACTIVE_USER';

    ------------------------------------------------------------
    -- 2. Construir BODY según la operación
    ------------------------------------------------------------
    SELECT JSON_OBJECT(
               'IsActive' VALUE P_IS_ACTIVE FORMAT JSON
               RETURNING CLOB
           )
      INTO V_BODY
      FROM DUAL;

    ------------------------------------------------------------
    -- 3. Obtener población que debe procesarse
    ------------------------------------------------------------
    FOR I IN (
        WITH ULTIMA_OPERACION AS (
            SELECT ID,
                   PIDM,
                   OP_TYPE,
                   STATUS,
                   ROW_NUMBER() OVER (
                       PARTITION BY PIDM
                       ORDER BY ID DESC
                   ) AS RN
              FROM ITZBGSP
             WHERE OP_TYPE IN (
                       'INACTIVE_USER',
                       'ACTIVE_USER',
                       'CREATE_USER_ST'
                   )
        )
        SELECT DISTINCT
               S.SPRIDEN_PIDM AS PIDM,
               S.SPRIDEN_ID AS SPRIDEN_ID,
               PKG_INT_BRIPACE_PERS.F_GET_INF_AD(
                   S.SPRIDEN_PIDM
               ) AS ID_USUARIO_BRIGHTSPACE,
               U.OP_TYPE AS ULTIMA_OPERACION
          FROM SPRIDEN S
          JOIN ULTIMA_OPERACION U
            ON U.PIDM = S.SPRIDEN_PIDM
           AND U.RN = 1
         WHERE S.SPRIDEN_CHANGE_IND IS NULL

           -------------------------------------------------------
           -- Tener datos adicionales
           -------------------------------------------------------
           AND PKG_INT_BRIPACE_PERS.F_EXISTE_INF_AD(
                   S.SPRIDEN_PIDM
               ) = 'Y'

           -------------------------------------------------------
           -- Tener usuario creado correctamente
           -------------------------------------------------------
           AND EXISTS (
                   SELECT 1
                     FROM ITZBGSP C
                    WHERE C.PIDM = S.SPRIDEN_PIDM
                      AND C.OP_TYPE = 'CREATE_USER_ST'
                      AND C.STATUS = 'PROCESSED_OK'
               )

           -------------------------------------------------------
           -- Condiciones según la operación
           -------------------------------------------------------
         AND (
                (-- PARA INACTIVAR, su retencion debe estar activa Y
                    P_OP_TYPE = 'INACTIVE_USER'
                    AND U.OP_TYPE IN ('ACTIVE_USER', 'CREATE_USER_ST')
                    AND F_VALIDA_RETENCION(
                            S.SPRIDEN_PIDM,
                            P_OP_TYPE
                        ) = 'Y'
                )
                OR
                (-- PARA ACTIVAR, su  retencion esta vencida Y
                    P_OP_TYPE = 'ACTIVE_USER'
                    AND U.OP_TYPE = 'INACTIVE_USER'
                    AND F_VALIDA_RETENCION(
                            S.SPRIDEN_PIDM,
                            P_OP_TYPE
                        ) = 'Y'
                )
            )
    )
    LOOP

        ------------------------------------------------------------
        -- 4. Obtener identificador de Brightspace
        ------------------------------------------------------------
        V_ADDIC_ID := I.ID_USUARIO_BRIGHTSPACE;

        ------------------------------------------------------------
        -- 5. Generar solicitud de activación / inactivación
        ------------------------------------------------------------
        PKG_INT_BRIPACE_UTIL.P_GENERA_INSERTA_ITZBGSP(
            P_BUSINESS_LINE => 'ONLINE',
            P_OP_TYPE       => P_OP_TYPE,

            P_ENDPOINT      =>
                REPLACE(
                    V_URL_CFG,
                    '{ID_USUARIO_BRIGHTSPACE}',
                    TO_CHAR(V_ADDIC_ID)
                ),

            P_METHOD        => V_METHOD,
            P_BODY          => V_BODY,
            P_ID_GENERADO   => V_SEQ,
            P_PIDM          => I.PIDM,
            P_ID_SPRIDEN    => I.SPRIDEN_ID
        );

    END LOOP;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;

END P_PROCESA_ESTADO_ALU;


FUNCTION F_VALIDA_RETENCION (
    P_PIDM     IN NUMBER,
    P_OP_TYPE  IN VARCHAR2
) RETURN VARCHAR2
IS
    V_RESULTADO VARCHAR2(1);
BEGIN

    IF P_OP_TYPE NOT IN ('INACTIVE_USER', 'ACTIVE_USER') THEN
        RETURN 'N';
    END IF;
-- valor de la variable gtvsdax de los codigos para retenciones
    WITH PARAMETRO AS (
        SELECT DBMS_LOB.SUBSTR(
                   INTEGRACION.PKG_INT_BRIPACE_TERM.F_GET_GTVSDAX(
                       'ONLINE',
                       'INACTIVAR',
                       'DEV_INT_BRIGTHSPACE'
                   ),
                   4000,
                   1
               ) AS VALORES
          FROM DUAL
    ),
    -- pone los codigos para que se comporten como columnas y usarlos en un IN
    CODIGOS AS (
        SELECT TRIM(
                   REGEXP_SUBSTR(VALORES, '[^,]+', 1, LEVEL)
               ) AS CODIGO
          FROM PARAMETRO
        CONNECT BY LEVEL <= REGEXP_COUNT(VALORES, ',') + 1
    )
    SELECT CASE
        ------------------------------------------------------------
        -- INACTIVAR: existe retención vigente
        ------------------------------------------------------------
        WHEN P_OP_TYPE = 'INACTIVE_USER'
         AND (
                EXISTS (
                    SELECT 1
                      FROM SPRHOLD H
                     WHERE H.SPRHOLD_PIDM = P_PIDM
                       AND H.SPRHOLD_FROM_DATE <= SYSDATE
                       AND H.SPRHOLD_TO_DATE > SYSDATE
                       AND H.SPRHOLD_HLDD_CODE IN (
                               SELECT CODIGO FROM CODIGOS
                           )
                )
                OR
                EXISTS (
                    SELECT 1
                      FROM SORLCUR U
                      JOIN SGRSTHD D
                        ON U.SORLCUR_PIDM = D.SGRSTHD_PIDM
                     WHERE D.SGRSTHD_PIDM = P_PIDM
                       AND U.SORLCUR_LMOD_CODE = 'LEARNER'
                       AND U.SORLCUR_CACT_CODE = 'ACTIVE'
                       AND U.SORLCUR_TERM_CODE_END IS NULL
                       AND U.SORLCUR_CURRENT_CDE = 'Y'
                       AND U.SORLCUR_LEVL_CODE = 'ON'
                       AND D.SGRSTHD_FROM_DATE <= SYSDATE
                       AND D.SGRSTHD_TO_DATE > SYSDATE
                )
             )
        THEN 'Y'

        ------------------------------------------------------------
        -- ACTIVAR: existe retención vencida
        ------------------------------------------------------------
        WHEN P_OP_TYPE = 'ACTIVE_USER'
         AND (
                EXISTS (
                    SELECT 1
                      FROM SPRHOLD H
                     WHERE H.SPRHOLD_PIDM = P_PIDM
                       AND H.SPRHOLD_TO_DATE < SYSDATE
                       AND H.SPRHOLD_HLDD_CODE IN (
                               SELECT CODIGO FROM CODIGOS
                           )
                )
                OR
                EXISTS (
                    SELECT 1
                      FROM SORLCUR U
                      JOIN SGRSTHD D
                        ON U.SORLCUR_PIDM = D.SGRSTHD_PIDM
                     WHERE D.SGRSTHD_PIDM = P_PIDM
                       AND U.SORLCUR_LMOD_CODE = 'LEARNER'
                       AND U.SORLCUR_CACT_CODE = 'ACTIVE'
                       AND U.SORLCUR_TERM_CODE_END IS NULL
                       AND U.SORLCUR_CURRENT_CDE = 'Y'
                       AND U.SORLCUR_LEVL_CODE = 'ON'
                       AND D.SGRSTHD_TO_DATE < SYSDATE
                )
             )
        THEN 'Y'

        ELSE 'N'
    END
    INTO V_RESULTADO
    FROM DUAL;

    RETURN V_RESULTADO;

END F_VALIDA_RETENCION;


END PKG_INT_BRIPACE_PERS;
