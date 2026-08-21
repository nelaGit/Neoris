CREATE OR REPLACE TRIGGER ST_SSRMEET_CRN_BRIGSPACE
FOR INSERT ON SSRMEET
COMPOUND TRIGGER

    TYPE t_reg IS RECORD (
        term_code  SSRMEET.SSRMEET_TERM_CODE%TYPE,
        crn        SSRMEET.SSRMEET_CRN%TYPE
    );

    TYPE t_tab IS TABLE OF t_reg INDEX BY PLS_INTEGER;

    g_data t_tab;
    g_idx  PLS_INTEGER := 0;

    v_periodo VARCHAR2(30);


AFTER EACH ROW IS
BEGIN

    g_idx := g_idx + 1;

    g_data(g_idx).term_code := :NEW.SSRMEET_TERM_CODE;
    g_data(g_idx).crn       := :NEW.SSRMEET_CRN;

END AFTER EACH ROW;


AFTER STATEMENT IS
BEGIN

    -- Se consulta una sola vez el periodo configurado
    v_periodo := pkg_int_bripace_term.f_get_gtvsdax(
                    'ONLINE',
                    'PERIODO',
                    'DEV_INT_BRIGTHSPACE'
                 );

    -- Procesamos todos los SSRMEET insertados
    FOR i IN 1 .. g_idx LOOP

        -- Validamos que el periodo corresponda
        IF v_periodo = SUBSTR(g_data(i).term_code, 5, 2) THEN

            DECLARE
                v_ptrm_code  SSBSECT.SSBSECT_PTRM_CODE%TYPE;
                v_subj_code  SSBSECT.SSBSECT_SUBJ_CODE%TYPE;
                v_crse_numb  SSBSECT.SSBSECT_CRSE_NUMB%TYPE;
                v_start_date SSBSECT.SSBSECT_PTRM_START_DATE%TYPE;
                v_title      SSBSECT.SSBSECT_CRSE_TITLE%TYPE;
                v_max_enrl   SSBSECT.SSBSECT_MAX_ENRL%TYPE;
            BEGIN

                SELECT SSBSECT_PTRM_CODE,
                       SSBSECT_SUBJ_CODE,
                       SSBSECT_CRSE_NUMB,
                       SSBSECT_PTRM_START_DATE,
                       SSBSECT_CRSE_TITLE,
                       SSBSECT_MAX_ENRL
                  INTO v_ptrm_code,
                       v_subj_code,
                       v_crse_numb,
                       v_start_date,
                       v_title,
                       v_max_enrl
                  FROM SSBSECT
                 WHERE SSBSECT_TERM_CODE = g_data(i).term_code
                   AND SSBSECT_CRN       = g_data(i).crn;

                PKG_INT_BRIPACE_NRC.p_registra_nrc(
                    'INSERT',
                    g_data(i).term_code,
                    g_data(i).crn,
                    v_ptrm_code,
                    v_subj_code,
                    v_crse_numb,
                    v_start_date,
                    v_title,
                    v_max_enrl
                );

            END;

        END IF;

    END LOOP;

END AFTER STATEMENT;

END ST_SSRMEET_CRN_BRIGSPACE;
