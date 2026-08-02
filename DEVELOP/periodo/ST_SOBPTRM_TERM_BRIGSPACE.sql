TRIGGER ST_SOBPTRM_TERM_BRIGSPACE
AFTER INSERT OR UPDATE OR DELETE ON SOBPTRM
FOR EACH ROW
DECLARE
  v_periodo VARCHAR2(30);

BEGIN
/* PENDIENTE incluir logica de GTVSDAX */
-- Se consulta que el periodo sea ONLINE
   v_periodo:= pkg_int_bripace_term.f_get_gtvsdax(
                'ONLINE',
                'PERIODO',
                'DEV_INT_BRIGTHSPACE'
            );
    
    -- Se valida que las 2 ultimas posiciones sea igual al periodo parametrizado en GTVSDAX
    IF v_periodo = SUBSTR(:NEW.SOBPTRM_TERM_CODE,5,2) Then
    
        IF INSERTING THEN
            integracion.PKG_INT_BRIPACE_TERM.p_registra_periodo(
                'INSERT',
                :NEW.SOBPTRM_TERM_CODE,
                :NEW.SOBPTRM_PTRM_CODE,
                :NEW.SOBPTRM_DESC,
                :NEW.SOBPTRM_START_DATE,
                :NEW.SOBPTRM_END_DATE
            );
    
        ELSIF UPDATING THEN
            integracion.PKG_INT_BRIPACE_TERM.p_registra_periodo(
                'UPDATE',
                :NEW.SOBPTRM_TERM_CODE,
                :NEW.SOBPTRM_PTRM_CODE,
                :NEW.SOBPTRM_DESC,
                :NEW.SOBPTRM_START_DATE,
                :NEW.SOBPTRM_END_DATE
            );
    
        ELSIF DELETING THEN
            integracion.PKG_INT_BRIPACE_TERM.p_registra_periodo(
                'DELETE',
                :OLD.SOBPTRM_TERM_CODE,
                :OLD.SOBPTRM_PTRM_CODE,
                :OLD.SOBPTRM_DESC,
                :OLD.SOBPTRM_START_DATE,
                :OLD.SOBPTRM_END_DATE
            );
    
        END IF;
  END IF;
END;