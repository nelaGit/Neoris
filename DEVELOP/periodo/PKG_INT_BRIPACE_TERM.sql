create or replace PACKAGE                                                             PKG_INT_BRIPACE_TERM AS

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

-- proced registra errores
PROCEDURE p_registra_error_log (
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

END PKG_INT_BRIPACE_TERM;
/

create or replace PACKAGE BODY                                                                                      PKG_INT_BRIPACE_TERM AS
    

    PROCEDURE p_registra_periodo(
        p_action            VARCHAR2,
        p_term_code         VARCHAR2,
        p_ptrm_code         VARCHAR2,
        p_desc              VARCHAR2,
        p_start_date        DATE,
        p_end_date          DATE
    ) IS
    
     v_org_type         GTVSDAX.GTVSDAX_COMMENTS%TYPE;
     v_org_parent       GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        
    BEGIN

       IF p_action = 'INSERT' THEN
       
       -- Se validan las variables de configuracion. Si no estan va al LOG de errores
       -- y no llegan a tablas intermedias
       
       -- ini
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
       -- fin
    
            MERGE INTO integracion.SZRTMBP tgt
            USING (
                SELECT 
                    p_term_code   AS term_code,
                    p_ptrm_code   AS ptrm_code
                FROM dual
            ) src
            ON (
                tgt.SZRTMBP_TERM_CODE = src.term_code
                AND tgt.SZRTMBP_PTRM_CODE = src.ptrm_code
            )
            
            WHEN MATCHED THEN
                UPDATE SET
                    tgt.SZRTMBP_DESC          = p_desc,
                    tgt.SZRTMBP_START_DATE    = p_start_date,
                    tgt.SZRTMBP_END_DATE      = p_end_date,
                    tgt.SZRTMBP_STATE         = 'NEW',
                    tgt.SZRTMBP_OPERACION          = 'U',
                    tgt.SZRTMBP_VERSION       = NVL(tgt.SZRTMBP_VERSION,0) + 1,
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
                    p_term_code,
                    p_ptrm_code,
                    p_desc,
                    p_start_date,
                    p_end_date,
                    'NEW',
                    'I',
                    1,
                    'SOBPTRM',
                    USER,
                    SYSDATE
                );
         ELSE
           -- log de errores
           PKG_INT_BRIPACE_TERM.p_registra_error_log(
            p_business_line => 'ONLINE',
            p_op_type       => 'CREATE_TERM',
            p_term_code     => p_term_code,
            p_ptrm_code     => p_ptrm_code,
            p_error_code    => 'GTVSDAX_NOT_FOUND',
            p_error_message => 'Datos inexistentes en GTVSDAX para TYPE y ORG_PARENT '
        );
           
         END IF;

    END IF;
    
    -- llama el procedure de integracion. Pobla los datos a la tabla principal itzbgsp
   -- p_registra_periodo_int; 

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
    dbms_output.put_line('mensaje 2');
                ------------------------------------------------------------------
                -- Generar JSON
                ------------------------------------------------------------------
         -- La secuencia es para el state NEW porque el INCOMPLETE ya tiene seq
        IF r.SZRTMBP_STATE = 'NEW' THEN
           v_seq := INTEGRACION.SEQ_ITZBGSP.NEXTVAL;
        ELSE
            v_seq := r.SZRTMBP_ID_MAESTRO;
        END IF;
        
        -- Con state INCOMPLETE le capturo la secuencia       
          SELECT JSON_ARRAYAGG(
                   JSON_OBJECT(
                       'request' VALUE JSON_OBJECT(
                           'id' VALUE v_seq, 
                           'endpoint' VALUE v_url || v_path,
                           'method' VALUE v_method,
                           'body' VALUE JSON_OBJECT(
                               'Type' VALUE TO_NUMBER(v_org_type),
                               'Name' VALUE r.szrtmbp_term_code || '-' || r.szrtmbp_ptrm_code ||' ' ||r.szrtmbp_desc,
                               'Code' VALUE r.szrtmbp_term_code || '-' || r.szrtmbp_ptrm_code,
                               'Parents' VALUE JSON_ARRAY(TO_NUMBER(v_org_parent))
                           RETURNING CLOB)
                       RETURNING CLOB),
        
                       'response' VALUE JSON_OBJECT(
                           'code' VALUE NULL,
                           'body' VALUE NULL
                       ABSENT ON NULL RETURNING CLOB)
        
                   RETURNING CLOB)
               )
        INTO l_json
        FROM dual;
    
    dbms_output.put_line('mensaje 3');
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
                    'CREATE_TERM',
                    'PENDING'
                );
    dbms_output.put_line('mensaje 4');
                ------------------------------------------------------------------
                -- Actualizar estado en SZRTMBP
                ------------------------------------------------------------------
                UPDATE szrtmbp
                   SET szrtmbp_state = 'SEND',
                       SZRTMBP_ID_MAESTRO= v_seq
                 WHERE ROWID = r.rid;
                 
                --voy por aqui mer tmp
                IF SQL%ROWCOUNT = 1 THEN
                    PKG_INT_BRIPACE_TERM.p_registra_error_log(
                    p_business_line => 'ONLINE',
                    p_op_type       => 'CREATE_TERM',
                    p_term_code     => r.szrtmbp_term_code,
                    p_ptrm_code     => r.szrtmbp_ptrm_code,
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
                         SZRTMBP_STATE_DET = v_error
                     WHERE ROWID = r.rid;
                     
                      PKG_INT_BRIPACE_TERM.p_registra_error_log(
                            p_business_line => 'ONLINE',
                            p_op_type       => 'CREATE_TERM',
                            p_term_code     => r.szrtmbp_term_code,
                            p_ptrm_code     => r.szrtmbp_ptrm_code,
                            p_error_code    => 'CREATE_TERM_INT',
                            p_error_message => v_error
                        );
                    
 END;
    
        END LOOP;
    
     --mer tmp   COMMIT;
    dbms_output.put_line('mensaje 5');
    END p_registra_periodo_int;

-- Inserta datos supl en tabla intermedia de Periodo
  
  PROCEDURE p_insert_itzsupl Is
    r_pk_parenttab    gobsdtb.gobsdtb_pk_dynsql%TYPE;
    v_rid              varchar2(18):=null;
    r_gorsdav_rowid   varchar2(18):=null;
  
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
         AND ITZSUPL_VALOR IS NOT NULL;
    
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
           
          UPDATE  ITZBGSP 
            SET STATUS = 'COMPLETED'
          where STATUS='PROCESSED_OK'
            and OP_TYPE = 'CREATE_TERM'
            and ID= I.id_maestro;
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

    END p_registra_error_log;


END PKG_INT_BRIPACE_TERM;