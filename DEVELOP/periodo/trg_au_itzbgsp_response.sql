create or replace TRIGGER integracion.trg_au_itzbgsp_response
FOR UPDATE ON integracion.itzbgsp
COMPOUND TRIGGER

   TYPE t_row IS RECORD(
      op_type integracion.itzbgsp.op_type%TYPE,
      status  integracion.itzbgsp.status%TYPE
   );

   TYPE t_tab IS TABLE OF t_row INDEX BY PLS_INTEGER;

   g_rows t_tab;
   g_idx  NUMBER := 0;

AFTER EACH ROW IS
BEGIN

   IF :NEW.STATUS = 'PROCESSED_OK'
      AND :NEW.RESPONSE IS NOT NULL
   THEN
      g_idx := g_idx + 1;

      g_rows(g_idx).op_type := :NEW.OP_TYPE;
      g_rows(g_idx).status  := :NEW.STATUS;
   END IF;

END AFTER EACH ROW;

AFTER STATEMENT IS
BEGIN

   FOR i IN 1 .. g_idx LOOP

      CASE g_rows(i).op_type

         WHEN 'CREATE_TERM' THEN
            integracion.PKG_INT_BRIPACE_TERM.p_insert_itzsupl;

         WHEN 'CREATE_NRC' THEN
            integracion.PKG_INT_BRIPACE_NRC.p_insert_itzsupl;

      END CASE;

   END LOOP;

END AFTER STATEMENT;

END;