TRIGGER BANINST1.ST_SIBINST_BRIGSPACE
FOR INSERT OR UPDATE OF SIBINST_SCHD_IND, SIBINST_FCST_CODE
ON SATURN.SIBINST
COMPOUND TRIGGER

   TYPE t_registro IS RECORD (
      pidm       SATURN.SIBINST.SIBINST_PIDM%TYPE,
      term_code  SATURN.SIBINST.SIBINST_TERM_CODE_EFF%TYPE,
      fcst_code  SATURN.SIBINST.SIBINST_FCST_CODE%TYPE
   );

   TYPE t_registros IS TABLE OF t_registro
      INDEX BY PLS_INTEGER;

   g_registros t_registros;
   g_count     PLS_INTEGER := 0;


   ----------------------------------------------------------------------------
   -- AFTER EACH ROW
   ----------------------------------------------------------------------------
   AFTER EACH ROW IS
   BEGIN

      -------------------------------------------------------------------------
      -- INSERT
      --
      -- Al insertar debe cumplirse:
      --   SCHD_IND  = Y
      --   FCST_CODE = AC
      -------------------------------------------------------------------------
      IF INSERTING THEN

         IF :NEW.SIBINST_SCHD_IND = 'Y'
            AND :NEW.SIBINST_FCST_CODE = 'AC'
         THEN

            g_count := g_count + 1;

            g_registros(g_count).pidm :=
                :NEW.SIBINST_PIDM;

            g_registros(g_count).term_code :=
                :NEW.SIBINST_TERM_CODE_EFF;

            g_registros(g_count).fcst_code :=
                :NEW.SIBINST_FCST_CODE;

         END IF;


      -------------------------------------------------------------------------
      -- UPDATE
      --
      -- Procesar solamente cuando el registro PASA a cumplir:
      --   SCHD_IND  = Y
      --   FCST_CODE = AC
      --
      -- Casos:
      --   N + AC  -> Y + AC
      --   Y + IN  -> Y + AC
      --   N + IN  -> Y + AC
      -------------------------------------------------------------------------
      ELSIF UPDATING THEN

         IF :NEW.SIBINST_SCHD_IND = 'Y'
            AND :NEW.SIBINST_FCST_CODE = 'AC'
            AND (
                   NVL(:OLD.SIBINST_SCHD_IND, 'N') <> 'Y'
                   OR NVL(:OLD.SIBINST_FCST_CODE, 'XX') <> 'AC'
                )
         THEN

            g_count := g_count + 1;

            g_registros(g_count).pidm :=
                :NEW.SIBINST_PIDM;

            g_registros(g_count).term_code :=
                :NEW.SIBINST_TERM_CODE_EFF;

            g_registros(g_count).fcst_code :=
                :NEW.SIBINST_FCST_CODE;

         END IF;

      END IF;

   END AFTER EACH ROW;


   ----------------------------------------------------------------------------
   -- AFTER STATEMENT
   ----------------------------------------------------------------------------
   AFTER STATEMENT IS
   BEGIN

      FOR i IN 1 .. g_count
      LOOP

         ----------------------------------------------------------------------
         -- Registrar / activar persona
         ----------------------------------------------------------------------
         PKG_INT_BRIPACE_PERS.p_registra_persona(
             g_registros(i).pidm,
             g_registros(i).term_code
         );

      END LOOP;

   END AFTER STATEMENT;

END ST_SIBINST_BRIGSPACE;