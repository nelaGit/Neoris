CREATE OR REPLACE TRIGGER INTEGRACION.ST_SIRICNT_BRIGSPACE
FOR INSERT OR UPDATE OR DELETE
ON SATURN.SIRICNT
COMPOUND TRIGGER

   TYPE t_registro IS RECORD
   (
      pidm          SATURN.SIRICNT.SIRICNT_PIDM%TYPE,
      term_code_eff SATURN.SIRICNT.SIRICNT_TERM_CODE_EFF%TYPE,
      fcnt_code     SATURN.SIRICNT.SIRICNT_FCNT_CODE%TYPE,
      cntr_code     SATURN.SIRICNT.SIRICNT_CNTR_CODE%TYPE,
      operacion     VARCHAR2(10)
   );

   TYPE t_registros IS TABLE OF t_registro
      INDEX BY PLS_INTEGER;

   g_registros t_registros;
   g_count     PLS_INTEGER := 0;


   AFTER EACH ROW IS
   BEGIN

      g_count := g_count + 1;

      IF INSERTING THEN

         g_registros(g_count).pidm :=
            :NEW.SIRICNT_PIDM;

         g_registros(g_count).term_code_eff :=
            :NEW.SIRICNT_TERM_CODE_EFF;

         g_registros(g_count).fcnt_code :=
            :NEW.SIRICNT_FCNT_CODE;

         g_registros(g_count).cntr_code :=
            :NEW.SIRICNT_CNTR_CODE;

         g_registros(g_count).operacion :=
            'INSERT';


      ELSIF UPDATING THEN

         g_registros(g_count).pidm :=
            :NEW.SIRICNT_PIDM;

         g_registros(g_count).term_code_eff :=
            :NEW.SIRICNT_TERM_CODE_EFF;

         g_registros(g_count).fcnt_code :=
            :NEW.SIRICNT_FCNT_CODE;

         g_registros(g_count).cntr_code :=
            :NEW.SIRICNT_CNTR_CODE;

         g_registros(g_count).operacion :=
            'UPDATE';


      ELSIF DELETING THEN

         g_registros(g_count).pidm :=
            :OLD.SIRICNT_PIDM;

         g_registros(g_count).term_code_eff :=
            :OLD.SIRICNT_TERM_CODE_EFF;

         g_registros(g_count).fcnt_code :=
            :OLD.SIRICNT_FCNT_CODE;

         g_registros(g_count).cntr_code :=
            :OLD.SIRICNT_CNTR_CODE;

         g_registros(g_count).operacion :=
            'DELETE';

      END IF;

   END AFTER EACH ROW;


   AFTER STATEMENT IS
   BEGIN

      FOR i IN 1 .. g_count
      LOOP

         PKG_INT_BRIPACE_PERS.p_registra_docente
         (
            g_registros(i).pidm,
            g_registros(i).term_code_eff,
            g_registros(i).fcnt_code,
            g_registros(i).cntr_code,
            g_registros(i).operacion
         );

      END LOOP;

   END AFTER STATEMENT;

END ST_SIRICNT_BRIGSPACE;
/