create or replace PACKAGE BODY          PKG_INT_BRIPACE_NRC AS
    

    PROCEDURE p_registra_nrc(
        p_action            VARCHAR2,
        p_term_code         VARCHAR2,
        p_crn               VARCHAR2,
        p_ptrm_code         VARCHAR2,
        p_subj_code         VARCHAR2,
        p_crse_numb         VARCHAR2,
        p_start_date        DATE,
        p_crse_title        VARCHAR2,
        p_max_enrl          NUMBER
    ) IS
    BEGIN

       IF p_action = 'INSERT' THEN
    --validar si se mete la misma tabla u otra para manejar los periodos/ mejor otra tabla
        MERGE INTO integracion.SZRSSBP tgt
        USING (
            SELECT 
                p_term_code   AS term_code,
                p_crn         AS crn
            FROM dual
        ) src
        ON (
            tgt.SZRSSBP_TERM_CODE = src.term_code
            AND tgt.SZRSSBP_CRN = src.crn
        )
        
        WHEN MATCHED THEN
            UPDATE SET
                tgt.SZRSSBP_CRSE_TITLE       = p_crse_title,
                tgt.SZRSSBP_PTRM_START_DATE  = p_start_date,
                tgt.SZRSSBP_MAX_ENRL      = p_max_enrl,
                tgt.SZRSSBP_STATE         = 'NEW',
                tgt.SZRSSBP_OPERACION     = 'U',
                tgt.SZRSSBP_VERSION       = NVL(tgt.SZRSSBP_VERSION,0) + 1,
                tgt.SZRSSBP_USER_ID       = USER,
                tgt.SZRSSBP_ACTIVITY_DATE = SYSDATE
        
        WHEN NOT MATCHED THEN
            INSERT (
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
            VALUES (
                p_term_code,
                p_crn,
                p_ptrm_code,
                p_subj_code,
                p_crse_numb,
                p_start_date,
                p_crse_title,
                p_max_enrl,
                NULL,
                'NEW',
                'I',
                1,
                'SSBSECT',
                USER,
                SYSDATE
            );

    ELSIF p_action = 'UPDATE' THEN

        UPDATE integracion.SZRSSBP
           SET SZRSSBP_CRSE_TITLE       = p_crse_title,
                SZRSSBP_PTRM_START_DATE  = p_start_date,
                SZRSSBP_MAX_ENRL      = p_max_enrl,
                SZRSSBP_STATE         = 'NEW',
                SZRSSBP_OPERACION     = 'U',
                SZRSSBP_VERSION       = NVL(SZRSSBP_VERSION,0) + 1,
                SZRSSBP_USER_ID       = USER,
                SZRSSBP_ACTIVITY_DATE = SYSDATE               
         WHERE SZRSSBP_TERM_CODE = p_term_code
           AND SZRSSBP_CRN = p_crn;

    ELSIF p_action = 'DELETE' THEN
    
        UPDATE integracion.SZRSSBP
           SET SZRSSBP_STATE         = 'D',
               SZRSSBP_VERSION       = NVL(SZRSSBP_VERSION,0) + 1,
               SZRSSBP_USER_ID       = USER,
               SZRSSBP_ACTIVITY_DATE = SYSDATE
         WHERE SZRSSBP_TERM_CODE = p_term_code
           AND SZRSSBP_PTRM_CODE = p_ptrm_code;

    END IF;
  
  -- llama el procedure de integracion. Pobla los datos a la tabla principal itzbgsp
  --p_registra_nrc_int; 

   END p_registra_nrc;

-- -- Registra desde la tabla intermedia a la tabla de integracion
    PROCEDURE p_registra_nrc_int IS
    
        l_json        CLOB;
    
        -- Configuración Brightspace
        v_url              GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_path_base        GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_path             GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_method           GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_org_type         GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_org_parent       GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_located          GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_id_master_bs     VARCHAR2(10);
        v_crse_title       VARCHAR2(30);
        v_seq              number;
        
        v_path_base_copia GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_path_base_cons  GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_method_copia    GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_method_cons     GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_path_copia      GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        v_path_cons       GTVSDAX.GTVSDAX_COMMENTS%TYPE;
        
        v_id_template_bs  VARCHAR2(10);
        v_id_periodo_bs   VARCHAR2(10);
        
        v_estado          VARCHAR2(10);
        
        v_error           VARCHAR2(200);
    
    BEGIN
    
        ------------------------------------------------------------------
        -- Configuración
        ------------------------------------------------------------------
        -- Creacion de cursos peticion 1
        v_url :=
            pkg_int_bripace_term.f_get_gtvsdax(
                'ONLINE',
                'INSTANAME',
                'DEV_INT_BRIGTHSPACE'
            );
    
        v_path_base :=
            pkg_int_bripace_term.f_get_gtvsdax(
                'ONLINE',
                'CREA_NRC',
                'DEV_INT_BRIGTHSPACE'
            );
            
          -- Copia de contenido peticion 2
           v_path_base_copia :=
            pkg_int_bripace_term.f_get_gtvsdax(
                'ONLINE',
                'CREA_NRC_1',
                'DEV_INT_BRIGTHSPACE'
            );
          
          -- Consulta de estado de la copia del contenido peticion 3
          
           v_path_base_cons :=
            pkg_int_bripace_term.f_get_gtvsdax(
                'ONLINE',
                'CREA_NRC_2',
                'DEV_INT_BRIGTHSPACE'
            );
 
 -- como en el path esta incluido el metodo, lo separamos para luego usarlo adecuadamente 
 -- en los valores del JSON
        
         v_method:= SUBSTR(v_path_base,1, INSTR(v_path_base, ',') -1);
         v_path:= SUBSTR(v_path_base, INSTR(v_path_base, ',') + 1);
         
         v_method_copia:= SUBSTR(v_path_base_copia,1, INSTR(v_path_base_copia, ',') -1);
         v_path_copia:= SUBSTR(v_path_base_copia, INSTR(v_path_base_copia, ',') + 1);
         
         v_method_cons:= SUBSTR(v_path_base_cons,1, INSTR(v_path_base_cons, ',') -1);
         v_path_cons:= SUBSTR(v_path_base_cons, INSTR(v_path_base_cons, ',') + 1);
         
         
    
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
            
         v_located :=
            pkg_int_bripace_term.f_get_gtvsdax(
                'ONLINE',
                'LOCATED_ID',
                'DEV_INT_BRIGTHSPACE'
            );
    dbms_output.put_line('mensaje 1');
    
    
        ------------------------------------------------------------------
        -- Procesar todos los registros NEW e 
        -- INCOMPLETE( si ya tiene los regitros v_id_periodo_bs , v_id_template_bs , v_id_master_bs con valor para que sean procesados como PENDING)
        ------------------------------------------------------------------
        FOR r IN (
            SELECT ROWID rid,
                   SZRSSBP_TERM_CODE,
                   SZRSSBP_CRN,
                   SZRSSBP_PTRM_CODE,
                   SZRSSBP_SUBJ_CODE,
                   SZRSSBP_CRSE_NUMB,
                   SZRSSBP_PTRM_START_DATE,
                   SZRSSBP_CRSE_TITLE,
                   SZRSSBP_MAX_ENRL,
                   SZRSSBP_state,
                   SZRSSBP_ID_MAESTRO
              FROM integracion.SZRSSBP
             WHERE SZRSSBP_state IN( 'NEW', 'INCOMPLETE')
        )
        LOOP
    
            BEGIN
    dbms_output.put_line('mensaje 2');
         ------------------------------------------------------------------
         -- Generar JSON
         ------------------------------------------------------------------
        -- La secuencia es para el state NEW porque el INCOMPLETE ya tiene seq
        IF r.SZRSSBP_state = 'NEW' THEN
           v_seq := INTEGRACION.SEQ_ITZBGSP.NEXTVAL;
        ELSE
        -- Con state INCOMPLETE le capturo la secuencia 
          v_seq := r.SZRSSBP_ID_MAESTRO;
          -- MER TMP voy por aqui
          -- una vez capturada la v_seq del estado INCOMPLETE, generamos en el JSON el error para guardarlo
          -- hay que poner un MERGE en el insert de integracion.itzbgsp linea 409 para que no duplique cuando es estado incomplete
        END IF;   
           --obtenermos el titulo del crn
           v_crse_title:= PKG_INT_BRIPACE_NRC.get_course_title(r.szrssbp_crn,r.szrssbp_term_code );
           
    -- Obtener datos suplementarios
               v_id_master_bs:= PKG_INT_BRIPACE_TERM.fn_get_gorsdav_value(
                                'SCBCRSE', 'ID_MASTER_BS', 
                                r.SZRSSBP_SUBJ_CODE||CHR(1)||r.SZRSSBP_CRSE_NUMB||CHR(1)||r.SZRSSBP_TERM_CODE);
                                
                                
            Begin
            -- seleccionamos el dato suplementario de SCBCRSE
                SELECT  decode(datasu.gorsdav_value.gettypeName(),
                   'SYS.VARCHAR2', datasu.gorsdav_value.accessVARCHAR2(),
                   'SYS.DATE', datasu.gorsdav_value.accessDATE(),
                   'SYS.NUMBER', datasu.gorsdav_value.accessNUMBER(),
                   '*ERROR* Unknown SYS.ANYDATA data type ***') VALOR
               INTO v_id_template_bs
                FROM SCBCRSE, gorsdav datasu --relacione la table base STVCHRT y la table de DS gorsdav
               WHERE gp_goksdif.f_get_pk('SCBCRSE',SCBCRSE.ROWID) = datasu.gorsdav_pk_parenttab --aqui se hace la union de la table base y la DS
                 and datasu.gorsdav_table_name = 'SCBCRSE'--TABLA BASE DEL DATO SUPLEMENTARIO
                 AND datasu.gorsdav_attr_name = 'ID_TEMPLATE_BS'
                 AND SCBCRSE_CRSE_NUMB = r.SZRSSBP_CRSE_NUMB
                 AND SCBCRSE_SUBJ_CODE = r.SZRSSBP_SUBJ_CODE
                 AND SCBCRSE_EFF_TERM = r.SZRSSBP_TERM_CODE;
            
            Exception WHEN OTHERS THen
              v_id_template_bs:= NULL;
            end;
            
            Begin
            -- seleccionamos el dato suplementario de PERIODO, sino existe debe pasar a estado INCOMPLETE
                SELECT  decode(datasu.gorsdav_value.gettypeName(),
                   'SYS.VARCHAR2', datasu.gorsdav_value.accessVARCHAR2(),
                   'SYS.DATE', datasu.gorsdav_value.accessDATE(),
                   'SYS.NUMBER', datasu.gorsdav_value.accessNUMBER(),
                   '*ERROR* Unknown SYS.ANYDATA data type ***') VALOR
               INTO v_id_periodo_bs
                FROM SOBPTRM, gorsdav datasu --relacione la table base STVCHRT y la table de DS gorsdav
               WHERE gp_goksdif.f_get_pk('SOBPTRM',SOBPTRM.ROWID) = datasu.gorsdav_pk_parenttab --aqui se hace la union de la table base y la DS
                 and datasu.gorsdav_table_name = 'SOBPTRM'--TABLA BASE DEL DATO SUPLEMENTARIO
                 AND datasu.gorsdav_attr_name = 'IDENTIFIER_PERIODO'
                 AND SOBPTRM_TERM_CODE = r.SZRSSBP_TERM_CODE
                 AND SOBPTRM_PTRM_CODE = r.SZRSSBP_PTRM_CODE;
            
            Exception WHEN OTHERS THen
              v_id_periodo_bs:= NULL;--'6911';
            end;
            
           
          SELECT JSON_ARRAY(
         -------------------------------------------------------------------
         -- PETICIÓN 1 : Crear curso
         -------------------------------------------------------------------
         JSON_OBJECT(
           'request' VALUE JSON_OBJECT(
             'id'       VALUE v_seq,
             'endpoint' VALUE v_url || v_path,--'https://smartonlinetest.brightspace.com/d2l/api/lp/1.60/courses/',
             'method'   VALUE v_method, --'POST',
             'body' VALUE JSON_OBJECT(
               'Name' VALUE v_crse_title || ' (CRN ' || r.szrssbp_crn || ')',
               'Code' VALUE r.szrssbp_crn || '-' ||
                             r.szrssbp_term_code ||'-' ||
                             r.szrssbp_ptrm_code,
               'Path' VALUE '',
               'CourseTemplateId' VALUE TO_NUMBER(v_id_master_bs),
               'SemesterId' VALUE TO_NUMBER(v_id_periodo_bs),
               'StartDate' VALUE
                    TO_CHAR(r.szrssbp_ptrm_start_date,
                            'YYYY-MM-DD"T"HH24:MI:SS') || '.000Z',
               'EndDate' VALUE NULL,
               'LocaleId' VALUE to_number(v_located),
               'ForceLocale' VALUE 'false' FORMAT JSON,
               'ShowAddressBook' VALUE 'false' FORMAT JSON,
               'Description' VALUE JSON_OBJECT(
                   'Content' VALUE
                        v_crse_title || '-' ||
                        r.szrssbp_subj_code  || '-' ||
                        r.szrssbp_crse_numb  || '-' ||
                        'CUPO:' || r.szrssbp_max_enrl,
                   'Type' VALUE 'Text'
               ),
               'CanSelfRegister' VALUE NULL,
               'IsActive' VALUE 'true' FORMAT JSON
             RETURNING CLOB)
           RETURNING CLOB),

           'response' VALUE JSON_OBJECT(
               'code' VALUE NULL,
               'body' VALUE NULL
           RETURNING CLOB)

         RETURNING CLOB),

         -------------------------------------------------------------------
         -- PETICIÓN 2 : Copiar contenidos
         -------------------------------------------------------------------
         JSON_OBJECT(
           'request' VALUE JSON_OBJECT(
             'id' VALUE v_seq,
             'endpoint' VALUE v_url || v_path_copia,  --'https://smartonlinetest.brightspace.com/d2l/api/le/1.94/import/{Identifier}/copy/',
             'method' VALUE v_method_copia, --'POST',
             'body' VALUE JSON_OBJECT(
                 'SourceOrgUnitId' VALUE TO_NUMBER(v_id_template_bs),--'id_template_bs',
                 'Components' VALUE NULL,
                 'CallbackUrl' VALUE NULL,
                 'DaysToOffsetDates' VALUE 0,
                 'HoursToOffsetDates' VALUE 0,
                 'OffsetByStartDateDifference' VALUE 0
             RETURNING CLOB)
           RETURNING CLOB),

           'response' VALUE JSON_OBJECT(
               'code' VALUE NULL,
               'body' VALUE NULL
           RETURNING CLOB)

         RETURNING CLOB),

         -------------------------------------------------------------------
         -- PETICIÓN 3 : Consultar estado de copia
         -------------------------------------------------------------------
         JSON_OBJECT(
           'request' VALUE JSON_OBJECT(
             'id' VALUE v_seq,
             'endpoint' VALUE v_url || v_path_cons,--      'https://smartonlinetest.brightspace.com/d2l/api/le/1.94/import/{Identifier}/copy/{JobToken}',
             'method' VALUE v_method_cons, --'GET',
             'body' VALUE JSON_OBJECT(
                 'SourceOrgUnitId' VALUE TO_NUMBER(v_id_template_bs),--'id_template_bs',
                 'Components' VALUE NULL,
                 'CallbackUrl' VALUE NULL,
                 'DaysToOffsetDates' VALUE 0,
                 'HoursToOffsetDates' VALUE 0,
                 'OffsetByStartDateDifference' VALUE 0
             RETURNING CLOB)
           RETURNING CLOB),

           'response' VALUE JSON_OBJECT(
               'code' VALUE NULL,
               'body' VALUE NULL
           RETURNING CLOB)

         RETURNING CLOB)

         RETURNING CLOB) AS json_peticion
       INTO l_json
       FROM dual;
       
       -- se reemplaza el path null a cadena vacía
       l_json := REPLACE(l_json, '"Path":null', '"Path":""');
            
    dbms_output.put_line('mensaje 3');
                ------------------------------------------------------------------
                -- Registrar solicitud
                ------------------------------------------------------------------
       -- v_id_periodo_bs:= '6911'; -- mer tmp valor fijo mientras tanto
        -- Validamos estas variables: v_id_periodo_bs, v_id_template_bs, v_id_master_bs, si alguna  esta en NULO el estado se crea en INCOMPLETE
        If (v_id_periodo_bs IS NULL) OR (v_id_template_bs IS NULL) OR (v_id_master_bs IS NULL) Then 
          v_estado := 'INCOMPLETE'; -- Este estado se va a la tabla JSON
        else
          v_estado := 'PENDING';
        End if;
                
               /* 
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
                    'CREATE_NRC',
                    v_estado
                );
                */
            
            MERGE INTO integracion.itzbgsp t
            USING (
                SELECT
                    v_seq     AS id,
                    'ONLINE'  AS business_line,
                    l_json    AS request,
                    NULL      AS response,
                    SYSDATE   AS create_date,
                    SYSDATE   AS request_date,
                    NULL      AS response_date,
                    'CREATE_NRC' AS op_type,
                    v_estado  AS status
                FROM dual
            ) s
            ON (t.id = s.id)
            WHEN MATCHED THEN
                UPDATE SET
                   -- t.business_line = s.business_line,
                    t.request       = s.request,
                   -- t.response      = s.response,
                   -- t.request_date  = s.request_date,
                   -- t.response_date = s.response_date,
                   -- t.op_type       = s.op_type,
                    t.status        = s.status
        WHERE t.status != s.status
            WHEN NOT MATCHED THEN
                INSERT (
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
                    s.id,
                    s.business_line,
                    s.request,
                    s.response,
                    s.create_date,
                    s.request_date,
                    s.response_date,
                    s.op_type,
                    s.status
                );    
                
    dbms_output.put_line('mensaje 4');
                ------------------------------------------------------------------
                -- Actualizar estado en SZRSSBP
                -- Si el estado v_estado es INCOMPLETE, en tabla intermedia tambien se va con ese estado para que 
                -- sea procesado nuevamente 
                ------------------------------------------------------------------
                UPDATE SZRSSBP
                   SET SZRSSBP_state = DECODE(v_estado, 'INCOMPLETE', v_estado, 'SEND'),
                       SZRSSBP_ID_MAESTRO = v_seq
                 WHERE ROWID = r.rid
                   AND SZRSSBP_state != v_estado; -- Actualiza si el estado es distinto
    
            EXCEPTION
                WHEN OTHERS THEN
                  v_error := sqlerrm;
    
                    UPDATE SZRSSBP
                       SET SZRSSBP_state = 'FAIL',
                       SZRSSBP_STATE_DET = v_error
                     WHERE ROWID = r.rid;
    
                   /* INSERT INTO integracion.itzbgsp (
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
                        'ONLINE',
                        l_json,
                        JSON_OBJECT(
                            'error' VALUE SQLERRM
                            RETURNING CLOB
                        ),
                        SYSDATE,
                        SYSDATE,
                        SYSDATE,
                        'CREATE_TERM',
                        'FAIL'
                    );*/
    
            END;
    
        END LOOP;
    
     --mer tmp   COMMIT;
    dbms_output.put_line('mensaje 5');
    END p_registra_nrc_int;
    
    PROCEDURE p_insert_itzsupl iS
        r_pk_parenttab    gobsdtb.gobsdtb_pk_dynsql%TYPE;
        v_rid              varchar2(18):=null;
        r_gorsdav_rowid   varchar2(18):=null;
        v_registros number;
  
  -- mer tmp hay que meter un loop aqui para que vaya insertando en ITZSUPL y luego en datos suplementarios
    Cursor c_supl is
      select ITZSUPL_TERM_CODE term_code, 
             ITZSUPL_PTRM_CODE ptrm_code, 
             ITZSUPL_VALOR valor,
             SZRSSBP_ID_MAESTRO id_maestro,
             ITZSUPL_CRN crn
        from ITZSUPL A
        INNER JOIN SZRSSBP B
               ON B.SZRSSBP_ID_MAESTRO = A.ITZSUPL_ID_MAESTRO
       WHERE B.SZRSSBP_STATE = 'SEND'
         AND ITZSUPL_VALOR IS NOT NULL;
    
    BEGIN
   
   dbms_output.put_line('inicio..');
   
       INSERT INTO ITZSUPL
       (
          ITZSUPL_TERM_CODE,
          ITZSUPL_PTRM_CODE,
          ITZSUPL_CRN,
          ITZSUPL_LINE_NEG,
          ITZSUPL_ID_MAESTRO,
          ITZSUPL_VERSION,
          ITZSUPL_DATA_ORIGIN,
          ITZSUPL_USER_ID,
          ITZSUPL_ACTIVITY_DATE,
          ITZSUPL_VALOR
       )
       SELECT
           M.SZRSSBP_TERM_CODE,
           M.SZRSSBP_PTRM_CODE,
           SZRSSBP_CRN,
           M.SZRSSBP_LINE_NEG,
           M.SZRSSBP_ID_MAESTRO,
           0,
           'ITZBGSP',
          USER,
          SYSDATE,
          JSON_VALUE(B.RESPONSE,
                     '$[0].response.body.Identifier'
                     RETURNING VARCHAR2(20))      AS IDENTIFIER_TERM_CODE 
       FROM ITZBGSP B
            INNER JOIN SZRSSBP M
               ON M.SZRSSBP_ID_MAESTRO = B.ID
       WHERE B.STATUS = 'PROCESSED_OK'
         AND B.OP_TYPE = 'CREATE_NRC'
         AND JSON_VALUE(B.RESPONSE, '$[0].response.code') = '200'
         AND JSON_EXISTS(B.RESPONSE,'$[0].response.body.Identifier')
         AND JSON_VALUE(B.RESPONSE, '$[2].response.code') = '200'
         AND JSON_VALUE(B.RESPONSE,'$[2].response.body.Status') = 'COMPLETE'
         AND NOT EXISTS
         (
             SELECT 1
             FROM ITZSUPL S
             WHERE S.ITZSUPL_TERM_CODE =  M.SZRSSBP_PTRM_CODE
               AND S.ITZSUPL_CRN = M.SZRSSBP_CRN
         );
    
     v_registros := SQL%ROWCOUNT;
     
      dbms_output.put_line('ya insertó..'||v_registros);
     --  COMMIT;
       
       For i in c_supl LOOP
       
         dbms_output.put_line('inicia el for..');
         
          SELECT ROWID into v_rid  FROM SSBSECT WHERE SSBSECT_TERM_CODE=i.term_code AND SSBSECT_CRN= i.crn;
          
           r_pk_parenttab:=gp_goksdif.f_get_pk('SSBSECT',v_rid);
           
            select max(a.rowid) into r_gorsdav_rowid 
             from  gorsdav  a
             where a.gorsdav_table_name = 'SSBSECT'
             and a.gorsdav_attr_name = 'ID_LMS_BRIGHTSPACE'
             and a.gorsdav_disc = '1'
             and a.gorsdav_pk_parenttab = r_pk_parenttab;
      
       dbms_output.put_line('va a insertar dato supl.');
           
           -- aqui se inserta el dato suplementario original de banner
           gp_goksdif.p_set_attribute('SSBSECT'
                                     ,'ID_LMS_BRIGHTSPACE'
                                     ,'1'--1 CUANDO NO DEPENDE DE UNA LISTA DE VALORES, DE LO CONTRARIO SE TRAE EL CODE DE LA TABLA DE VALIDACI??N
                                     ,r_pk_parenttab
                                     ,r_gorsdav_rowid
                                     ,'VARCHAR2'
                                     ,i.valor
                                     );
           
          UPDATE  ITZBGSP 
            SET STATUS = 'COMPLETED'
          where STATUS='PROCESSED_OK'
            and OP_TYPE = 'CREATE_NRC'
            and ID= I.id_maestro;
            
          UPDATE SZRSSBP
            SET SZRSSBP_STATE = 'APPLIED'
            WHERE SZRSSBP_STATE = 'SEND'
              AND SZRSSBP_TERM_CODE = i.term_code
              AND SZRSSBP_CRN = i.crn
              AND SZRSSBP_ID_MAESTRO = i.id_maestro;
              
      End Loop;
      
   --   COMMIT;
    END p_insert_itzsupl;
    

FUNCTION get_course_title (
    p_crn       IN SSBSECT.SSBSECT_CRN%TYPE,
    p_term_code IN SSBSECT.SSBSECT_TERM_CODE%TYPE
)
RETURN VARCHAR2
IS
    l_title VARCHAR2(255);
BEGIN
    SELECT NVL(s.SSBSECT_CRSE_TITLE, c.SCBCRSE_TITLE)
      INTO l_title
      FROM SSBSECT s
      JOIN SCBCRSE c
        ON c.SCBCRSE_SUBJ_CODE = s.SSBSECT_SUBJ_CODE
       AND c.SCBCRSE_CRSE_NUMB = s.SSBSECT_CRSE_NUMB
     WHERE s.SSBSECT_CRN = p_crn
       AND s.SSBSECT_TERM_CODE = p_term_code
       AND c.SCBCRSE_EFF_TERM <= p_term_code
     ORDER BY c.SCBCRSE_EFF_TERM DESC
     FETCH FIRST 1 ROW ONLY;

    RETURN l_title;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
END;

END PKG_INT_BRIPACE_NRC;