create or replace TRIGGER ST_SSBSECT_CRN_BRIGSPACE
FOR INSERT ON SSBSECT
COMPOUND TRIGGER

    TYPE t_reg IS RECORD (
        accion        VARCHAR2(10),
        term_code     SSBSECT.SSBSECT_TERM_CODE%TYPE,
        crn           SSBSECT.SSBSECT_CRN%TYPE,
        ptrm_code     SSBSECT.SSBSECT_PTRM_CODE%TYPE,
        subj_code     SSBSECT.SSBSECT_SUBJ_CODE%TYPE,
        crse_numb     SSBSECT.SSBSECT_CRSE_NUMB%TYPE,
        start_date    SSBSECT.SSBSECT_PTRM_START_DATE%TYPE,
        title         SSBSECT.SSBSECT_CRSE_TITLE%TYPE,
        max_enrl      SSBSECT.SSBSECT_MAX_ENRL%TYPE
    );

    TYPE t_tab IS TABLE OF t_reg INDEX BY PLS_INTEGER;
    g_data t_tab;
    g_idx  PLS_INTEGER := 0;

    v_periodo VARCHAR2(30);

AFTER STATEMENT IS
BEGIN
    -- Se consulta una sola vez (mejor rendimiento también)
    v_periodo := pkg_int_bripace_term.f_get_gtvsdax(
                    'ONLINE',
                    'PERIODO',
                    'DEV_INT_BRIGTHSPACE'
                 );

    -- Procesamos todo cuando la tabla YA NO está mutando
    FOR i IN 1 .. g_idx LOOP

        IF v_periodo = SUBSTR(g_data(i).term_code, 5, 2) THEN

            PKG_INT_BRIPACE_NRC.p_registra_nrc(
                g_data(i).accion,
                g_data(i).term_code,
                g_data(i).crn,
                g_data(i).ptrm_code,
                g_data(i).subj_code,
                g_data(i).crse_numb,
                g_data(i).start_date,
                g_data(i).title,
                g_data(i).max_enrl
            );

        END IF;

    END LOOP;
END AFTER STATEMENT;


AFTER EACH ROW IS
BEGIN
    g_idx := g_idx + 1;

    IF INSERTING THEN
        g_data(g_idx).accion := 'INSERT';
        g_data(g_idx).term_code := :NEW.SSBSECT_TERM_CODE;
        g_data(g_idx).crn := :NEW.SSBSECT_CRN;
        g_data(g_idx).ptrm_code := :NEW.SSBSECT_PTRM_CODE;
        g_data(g_idx).subj_code := :NEW.SSBSECT_SUBJ_CODE;
        g_data(g_idx).crse_numb := :NEW.SSBSECT_CRSE_NUMB;
        g_data(g_idx).start_date := :NEW.SSBSECT_PTRM_START_DATE;
        g_data(g_idx).title := :NEW.SSBSECT_CRSE_TITLE;
        g_data(g_idx).max_enrl := :NEW.SSBSECT_MAX_ENRL;

   /* ELSIF UPDATING THEN
        g_data(g_idx).accion := 'UPDATE';
        g_data(g_idx).term_code := :NEW.SSBSECT_TERM_CODE;
        g_data(g_idx).crn := :NEW.SSBSECT_CRN;
        g_data(g_idx).ptrm_code := :NEW.SSBSECT_PTRM_CODE;
        g_data(g_idx).subj_code := :NEW.SSBSECT_SUBJ_CODE;
        g_data(g_idx).crse_numb := :NEW.SSBSECT_CRSE_NUMB;
        g_data(g_idx).start_date := :NEW.SSBSECT_PTRM_START_DATE;
        g_data(g_idx).title := :NEW.SSBSECT_CRSE_TITLE;
        g_data(g_idx).max_enrl := :NEW.SSBSECT_MAX_ENRL;

    ELSIF DELETING THEN
        g_data(g_idx).accion := 'DELETE';
        g_data(g_idx).term_code := :OLD.SSBSECT_TERM_CODE;
        g_data(g_idx).crn := :OLD.SSBSECT_CRN;
        g_data(g_idx).ptrm_code := :OLD.SSBSECT_PTRM_CODE;
        g_data(g_idx).subj_code := :OLD.SSBSECT_SUBJ_CODE;
        g_data(g_idx).crse_numb := :OLD.SSBSECT_CRSE_NUMB;
        g_data(g_idx).start_date := :OLD.SSBSECT_PTRM_START_DATE;
        g_data(g_idx).title := :OLD.SSBSECT_CRSE_TITLE;
        g_data(g_idx).max_enrl := :OLD.SSBSECT_MAX_ENRL;*/
    END IF;

END AFTER EACH ROW;

END ST_SSBSECT_CRN_BRIGSPACE;