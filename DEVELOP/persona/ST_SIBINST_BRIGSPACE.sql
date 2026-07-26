create or replace TRIGGER BANINST1.ST_SIBINST_BRIGSPACE
FOR INSERT OR UPDATE OF SIBINST_SCHD_IND
ON SATURN.SIBINST
COMPOUND TRIGGER

   g_pidm SATURN.SIBINST.SIBINST_PIDM%TYPE;
   g_term_code SATURN.SIBINST.SIBINST_TERM_CODE_EFF%TYPE;

   ----------------------------------------------------------------------------
   -- AFTER EACH ROW
   ----------------------------------------------------------------------------
   AFTER EACH ROW IS
   BEGIN
      g_pidm := NULL;

      IF :NEW.SIBINST_SCHD_IND = 'Y' THEN
         g_pidm := :NEW.SIBINST_PIDM;
         g_term_code := :NEW.SIBINST_TERM_CODE_EFF;
      END IF;

   END AFTER EACH ROW;

   ----------------------------------------------------------------------------
   -- AFTER STATEMENT
   ----------------------------------------------------------------------------
   AFTER STATEMENT IS
   BEGIN
      IF g_pidm IS NOT NULL THEN
         PKG_INT_BRIPACE_PERS.p_registra_persona(g_pidm, g_term_code);
      END IF;
   END AFTER STATEMENT;

END ST_SIBINST_BRIGSPACE;