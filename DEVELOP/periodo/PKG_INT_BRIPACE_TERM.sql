create or replace PACKAGE                                                                                     PKG_INT_BRIPACE_TERM AS

-- Registra en tabla intermedia SZRTMBP datos del periodo capturados desde el trigger de SOBPTRM
    PROCEDURE p_registra_periodo(
        p_action            VARCHAR2,
        p_term_code         VARCHAR2,
        p_ptrm_code         VARCHAR2,
        p_desc              VARCHAR2,
        p_start_date        DATE,
        p_end_date          DATE
    );
    
-- Registra desde la tabla intermedia a la tabla de integracion
PROCEDURE p_registra_periodo_int ;
    

-- Inserta datos suplementarios en tabla intermedia ITZSUPL
PROCEDURE p_insert_itzsupl(p_id_maestro NUMBER);

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


END PKG_INT_BRIPACE_TERM;

create or replace PACKAGE BODY                                                           PKG_INT_BRIPACE_TERM AS
    

    PROCEDURE p_registra_periodo(
        p_action            VARCHAR2,
        p_term_code         VARCHAR2,
        p_ptrm_code         VARCHAR2,
        p_desc              VARCHAR2,
        p_start_date        DATE,
        p_end_date          DATE
    ) IS
    
     r_periodo SZRTMBP%ROWTYPE;
    
     v_org_type         GTVSDAX.GTVSDAX_COMMENTS%TYPE;
     v_org_parent       GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        
    BEGIN
    

       IF p_action = 'INSERT' THEN
       
    ----------------------------------------------------------------------
    -- Construimos el registro de la tabla intermedia
    ----------------------------------------------------------------------

            r_periodo.SZRTMBP_TERM_CODE   := p_term_code;
            r_periodo.SZRTMBP_PTRM_CODE   := p_ptrm_code;
            r_periodo.SZRTMBP_DESC        := p_desc;
            r_periodo.SZRTMBP_START_DATE  := p_start_date;
            r_periodo.SZRTMBP_END_DATE    := p_end_date;
            r_periodo.SZRTMBP_DATA_ORIGIN := 'SOBPTRM';
         
       
       -- Se validan las variables de configuracion. Si no estan va al LOG de errores
       -- y no llegan a tablas intermedias
       
            v_org_type :=
                pkg_int_bripace_term.f_get_gtvsdax(
                    'ONLINE',
                    'TYPE',
                    'DEV_INT_BRIGTHSPACE'
                );
        
            v_org_parent :=
                pkg_int_bripace_term.f_get_gtvsdax(
                    'ONLINE',
                    'ORG_PARENT',
                    'DEV_INT_BRIGTHSPACE'
                );
           
         IF (v_org_type IS NOT NULL) AND (v_org_parent IS NOT NULL) THEN
       
             INTEGRACION.PKG_INT_BRIPACE_UTIL.p_intermedia_szrtmbp(
                    p_registro      => r_periodo,
                    p_business_line => 'ONLINE',
                    p_op_type       => 'CREATE_TERM'
                );
                
         ELSE
               -- log de errores
               PKG_INT_BRIPACE_UTIL.p_registra_error_log(
                p_business_line => 'ONLINE',
                p_op_type       => 'CREATE_TERM',
                p_term_code     => p_term_code,
                p_ptrm_code     => p_ptrm_code,
                p_error_code    => 'GTVSDAX_NOT_FOUND',
                p_error_message => 'Datos inexistentes en GTVSDAX para TYPE y ORG_PARENT '
            );
           
         END IF;

    END IF;
    
   END p_registra_periodo;

-- -- Registra desde la tabla intermedia a la tabla de integracion 
    PROCEDURE p_registra_periodo_int IS
    
        l_json        CLOB;
    
        -- Configuración Brightspace
        v_url              GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_path_base        GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_path             GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_method           GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_org_type         GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_org_parent       GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_seq              number;
        
        v_error           VARCHAR2(300);
        l_body        CLOB;
    
    BEGIN
    
        ------------------------------------------------------------------
        -- Configuración
        ------------------------------------------------------------------
        v_url :=
            pkg_int_bripace_term.f_get_gtvsdax(
                'ONLINE',
                'INSTANAME',
                'DEV_INT_BRIGTHSPACE'
            );
    
        v_path_base :=
            pkg_int_bripace_term.f_get_gtvsdax(
                'ONLINE',
                'CREA_TERM',
                'DEV_INT_BRIGTHSPACE'
            );
 
 -- como en el path esta incluido el metodo, lo separamos para luego usarlo adecuadamente 
 -- en los valores del JSON
        
         v_method:= SUBSTR(v_path_base,1, INSTR(v_path_base, ',') -1);
         
         v_path:= SUBSTR(v_path_base, INSTR(v_path_base, ',') + 1);
    
        v_org_type :=
            pkg_int_bripace_term.f_get_gtvsdax(
                'ONLINE',
                'TYPE',
                'DEV_INT_BRIGTHSPACE'
            );
    
        v_org_parent :=
            pkg_int_bripace_term.f_get_gtvsdax(
                'ONLINE',
                'ORG_PARENT',
                'DEV_INT_BRIGTHSPACE'
            );
    dbms_output.put_line('mensaje 1');
        ------------------------------------------------------------------
        -- Procesar todos los registros NEW
        ------------------------------------------------------------------
        FOR r IN (
            SELECT ROWID rid,
                   szrtmbp_desc,
                   szrtmbp_term_code,
                   szrtmbp_ptrm_code,
                   SZRTMBP_STATE,
                   SZRTMBP_ID_MAESTRO
              FROM szrtmbp
             WHERE szrtmbp_state = 'NEW'
        )
        LOOP
    
        BEGIN
                ------------------------------------------------------------------
                -- Generar JSON
                ------------------------------------------------------------------
                 -- 1. Generar BODY específico de CREATE_TERM
            SELECT JSON_OBJECT(
                       'Type' VALUE TO_NUMBER(v_org_type),
                       'Name' VALUE r.szrtmbp_term_code || '-' ||
                                    r.szrtmbp_ptrm_code || ' ' ||
                                    r.szrtmbp_desc,
                       'Code' VALUE r.szrtmbp_term_code || '-' ||
                                    r.szrtmbp_ptrm_code,
                       'Parents' VALUE JSON_ARRAY(
                                     TO_NUMBER(v_org_parent)
                                  )
                       RETURNING CLOB
                   )
            INTO l_body
            FROM dual;
            
            -- 2. El paquete genera REQUEST completo e inserta ITZBGSP
            PKG_INT_BRIPACE_UTIL.p_genera_inserta_itzbgsp(
                p_business_line => 'ONLINE',
                p_op_type       => 'CREATE_TERM',
                p_endpoint      => v_url || v_path,
                p_method        => v_method,
                p_body          => l_body,
                p_id_generado   => v_seq
            );
        

                ------------------------------------------------------------------
                -- Actualizar estado en SZRTMBP
                ------------------------------------------------------------------
                UPDATE szrtmbp
                   SET szrtmbp_state = 'SEND',
                       SZRTMBP_ID_MAESTRO= v_seq
                 WHERE ROWID = r.rid;
                 
                --voy por aqui mer tmp
                IF SQL%ROWCOUNT = 1 THEN
                   PKG_INT_BRIPACE_UTIL.p_registra_error_log(
                    p_business_line => 'ONLINE',
                    p_op_type       => 'CREATE_TERM',
                    p_id_maestro    => v_seq,
                    p_term_code     => r.szrtmbp_term_code,
                    p_ptrm_code     => r.szrtmbp_ptrm_code,
                    p_data_origin   => 'SOBPTRM',
                    p_crn           => NULL,
                    p_pidm          => NULL,
                    p_state         => 'OK',
                    p_error_code    => 'OK',
                    p_error_message => 'Periodo creado correctamente');
                    
             END IF;
             
            EXCEPTION
                WHEN OTHERS THEN
                   v_error := sqlerrm;
    
                    UPDATE szrtmbp
                       SET szrtmbp_state = 'FAIL',
                           SZRTMBP_ID_MAESTRO= v_seq,
                            SZRTMBP_STATE_DET = v_error
                     WHERE ROWID = r.rid;
                     
                      PKG_INT_BRIPACE_UTIL.p_registra_error_log(
                            p_business_line => 'ONLINE',
                            p_op_type       => 'CREATE_TERM',
                            p_id_maestro    => v_seq,
                            p_term_code     => r.szrtmbp_term_code,
                            p_ptrm_code     => r.szrtmbp_ptrm_code,
                            p_error_code    => 'CREATE_TERM_INT',
                            p_error_message => v_error
                        );
                    
 END;
    
        END LOOP;

    END p_registra_periodo_int;

-- Inserta datos supl en tabla intermedia de Periodo
  
  PROCEDURE p_insert_itzsupl(p_id_maestro NUMBER) Is
    r_pk_parenttab    gobsdtb.gobsdtb_pk_dynsql%TYPE;
    v_rid              varchar2(18):=null;
    r_gorsdav_rowid   varchar2(18):=null;
    v_error VARCHAR2(200);
  
  -- mer tmp hay que meter un loop aqui para que vaya insertando en ITZSUPL y luego en datos suplementarios
    Cursor c_supl is
      select ITZSUPL_TERM_CODE term_code, 
             ITZSUPL_PTRM_CODE ptrm_code, 
             ITZSUPL_VALOR valor,
             SZRTMBP_ID_MAESTRO id_maestro
        from ITZSUPL A
        INNER JOIN SZRTMBP B
               ON B.SZRTMBP_ID_MAESTRO = A.ITZSUPL_ID_MAESTRO
       WHERE B.SZRTMBP_STATE = 'SEND'
         AND ITZSUPL_VALOR IS NOT NULL
         AND B.SZRTMBP_ID_MAESTRO = p_id_maestro;
    
    BEGIN
    
       INSERT INTO ITZSUPL
       (
          ITZSUPL_TERM_CODE,
          ITZSUPL_PTRM_CODE,
          ITZSUPL_LINE_NEG,
          ITZSUPL_ID_MAESTRO,
          ITZSUPL_VERSION,
          ITZSUPL_DATA_ORIGIN,
          ITZSUPL_USER_ID,
          ITZSUPL_ACTIVITY_DATE,
          ITZSUPL_VALOR
       )
       SELECT
           M.SZRTMBP_TERM_CODE,
           M.SZRTMBP_PTRM_CODE,
           M.SZRTMBP_LINE_NEG,
             M.SZRTMBP_ID_MAESTRO,
             0,
              'ITZBGSP',
          USER,
          SYSDATE,
          JSON_VALUE(B.RESPONSE,
                     '$[0].response.body.Identifier'
                     RETURNING VARCHAR2(20))      AS IDENTIFIER_TERM_CODE 
       FROM ITZBGSP B
            INNER JOIN SZRTMBP M
               ON M.SZRTMBP_ID_MAESTRO = B.ID
       WHERE B.STATUS = 'PROCESSED_OK'
         AND B.OP_TYPE = 'CREATE_TERM'
         AND B.RESPONSE IS NOT NULL
         AND JSON_EXISTS(B.RESPONSE,'$[0].response.body.Identifier')
         AND NOT EXISTS
         (
             SELECT 1
             FROM ITZSUPL S
             WHERE S.ITZSUPL_TERM_CODE =  M.SZRTMBP_TERM_CODE
           AND S.ITZSUPL_PTRM_CODE = M.SZRTMBP_PTRM_CODE
         );
    
     --  COMMIT;
       
       For i in c_supl LOOP
         BEGIN
       
          SELECT ROWID into v_rid  FROM SOBPTRM WHERE SOBPTRM_TERM_CODE=i.term_code AND SOBPTRM_PTRM_CODE= i.ptrm_code;
          
           r_pk_parenttab:=gp_goksdif.f_get_pk('SOBPTRM',v_rid);
           
            select max(a.rowid) into r_gorsdav_rowid 
             from  gorsdav  a
             where a.gorsdav_table_name = 'SOBPTRM'
             and a.gorsdav_attr_name = 'IDENTIFIER_PERIODO'
             and a.gorsdav_disc = '1'
             and a.gorsdav_pk_parenttab = r_pk_parenttab;
           
           -- aqui se inserta el dato suplementario original de banner
           gp_goksdif.p_set_attribute('SOBPTRM'
                                     ,'IDENTIFIER_PERIODO'
                                     ,'1'--1 CUANDO NO DEPENDE DE UNA LISTA DE VALORES, DE LO CONTRARIO SE TRAE EL CODE DE LA TABLA DE VALIDACI??N
                                     ,r_pk_parenttab
                                     ,r_gorsdav_rowid
                                     ,'VARCHAR2'
                                     ,i.valor
                                     );
           
          PKG_INT_BRIPACE_UTIL.P_ACTUALIZA_ESTADO_ITZBGSP( i.ID_MAESTRO, 'CREATE_TERM', 'COMPLETED_OK'); 
            
              
           PKG_INT_BRIPACE_UTIL.P_ACTUALIZA_INTERMEDIA_STATE(
                P_TIPO       => 'CREATE_TERM',
                P_ID_MAESTRO => I.ID_MAESTRO,
                P_STATE_OLD  => 'SEND',
                P_STATE      => 'APPLIED'
            );
              
              
         EXCEPTION  WHEN OTHERS THEN
           BEGIN
             v_error:= sqlerrm;
             
               PKG_INT_BRIPACE_UTIL.P_ACTUALIZA_ESTADO_ITZBGSP( i.ID_MAESTRO, 'CREATE_TERM', 'COMPLETED_KO'); 
                
               PKG_INT_BRIPACE_UTIL.P_ACTUALIZA_INTERMEDIA_STATE(
                        P_TIPO       => 'CREATE_TERM',
                        P_ID_MAESTRO => I.ID_MAESTRO,
                        P_STATE_OLD  => 'SEND',
                        P_STATE      => 'FAIL',
                        P_MENSAJE    => v_error
                    );
                
            EXCEPTION
              WHEN OTHERS THEN
                NULL; -- INCLUIR EL LOG 
            END;
           
        END;
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
        v_error           VARCHAR2(300);
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


END PKG_INT_BRIPACE_TERM;