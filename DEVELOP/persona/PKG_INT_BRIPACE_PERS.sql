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
    
    v_periodo VARCHAR2(6);

    BEGIN
	-- VALIDAR SI LA PERSONA NO EXISTE EN BRIGSPACE
    -- 
    -- Validacion del periodo que sea ONLINE
     v_periodo:= pkg_int_bripace_term.f_get_gtvsdax(
                'ONLINE',
                'PERIODO',
                'DEV_INT_BRIGTHSPACE'
            );
    
    -- Se valida que las 2 ultimas posiciones sea igual al periodo parametrizado en GTVSDAX
    IF v_periodo = SUBSTR(p_term_code,5,2) Then
      v_line_neg:= 'ON'; -- Por ahora se trabajará en solo la linea ONLINE
    
        SELECT ROWID into v_rid  
          FROM SIBINST 
         WHERE SIBINST_PIDM = p_pidm AND SIBINST_TERM_CODE_EFF = p_term_code;
         
          r_pk_parenttab:=gp_goksdif.f_get_pk('SIBINST',v_rid);
         
          v_rol:=   PKG_INT_BRIPACE_PERS.fn_get_gorsdav_value(
                                    'SIBINST', 'SMART_ONLINE', 
                                    r_pk_parenttab);
        
        
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
    
        -- llama el procedure de integracion. Pobla los datos a la tabla principal itzbgsp
       -- p_registra_periodo_int; 
    END IF;
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
                'CREA_TERM',
                'DEV_INT_BRIGTHSPACE'
            );

 -- como en el path esta incluido el metodo, lo separamos para luego usarlo adecuadamente 
 -- en los valores del JSON

         v_method:= SUBSTR(v_path_base,1, INSTR(v_path_base, ',') -1);

         v_path:= SUBSTR(v_path_base, INSTR(v_path_base, ',') + 1);

        v_org_type :=
            PKG_INT_BRIPACE_PERS.f_get_gtvsdax(
                'ONLINE',
                'TYPE',
                'DEV_INT_BRIGTHSPACE'
            );

        v_org_parent :=
            PKG_INT_BRIPACE_PERS.f_get_gtvsdax(
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
                   SZRPEBP_PIDM
              FROM SZRPEBP
             WHERE SZRPEBP_STATE = 'NEW'
        )
        LOOP

          BEGIN
    dbms_output.put_line('mensaje 2');
                ------------------------------------------------------------------
                -- Generar JSON
                ------------------------------------------------------------------

           v_seq := INTEGRACION.SEQ_ITZBGSP.NEXTVAL;

          SELECT JSON_ARRAYAGG(
                   JSON_OBJECT(
                       'request' VALUE JSON_OBJECT(
                           'id' VALUE v_seq, 
                           'endpoint' VALUE v_url || v_path,
                           'method' VALUE v_method,
                           'body' VALUE JSON_OBJECT(
                               'Type' VALUE TO_NUMBER(v_org_type),
                     --          'Name' VALUE r.szrtmbp_term_code || '-' || r.szrtmbp_ptrm_code ||' ' ||r.szrtmbp_desc,
                     --          'Code' VALUE r.szrtmbp_term_code || '-' || r.szrtmbp_ptrm_code,
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
                    'CREATE_USER',
                    'PENDING'
                );
    dbms_output.put_line('mensaje 4');
                ------------------------------------------------------------------
                -- Actualizar estado en SZRTMBP
                ------------------------------------------------------------------
                UPDATE SZRPEBP
                   SET SZRPEBP_STATE = 'SEND',
                       SZRPEBP_ID_MAESTRO= v_seq
                 WHERE ROWID = r.rid;

            EXCEPTION
                WHEN OTHERS THEN

                    UPDATE SZRPEBP
                       SET SZRPEBP_STATE = 'FAIL'
                     WHERE ROWID = r.rid;
 END;

        END LOOP;

     --mer tmp   COMMIT;
    dbms_output.put_line('mensaje 5');
    END p_registra_persona_int;

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
             WHERE S.ITZSUPL_TERM_CODE =  M.SZRTMBP_PTRM_CODE
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

grant execute on integracion.PKG_INT_BRIPACE_PERS to public

CREATE PUBLIC SYNONYM PKG_INT_BRIPACE_PERS FOR integracion.PKG_INT_BRIPACE_PERS;


