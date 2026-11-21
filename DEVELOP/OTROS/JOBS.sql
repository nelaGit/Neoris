BEGIN
   DBMS_SCHEDULER.CREATE_JOB (
      job_name        => 'JOB_REGISTRA_PERIODO_INT',
      job_type        => 'STORED_PROCEDURE',
      job_action      => 'PKG_INT_BRIPACE_TERM.P_REGISTRA_PERIODO_INT',
      start_date      => SYSTIMESTAMP,
      repeat_interval => 'FREQ=SECONDLY;INTERVAL=10',
      enabled         => TRUE,
      auto_drop       => FALSE,
      comments        => 'Procesa registros NEW de la tabla SZRTMBP'
   );
END;


BEGIN
   DBMS_SCHEDULER.CREATE_JOB (
      job_name        => 'JOB_REGISTRA_NRC_INT',
      job_type        => 'STORED_PROCEDURE',
      job_action      => 'PKG_INT_BRIPACE_NRC.P_REGISTRA_NRC_INT',
      start_date      => SYSTIMESTAMP,
      repeat_interval => 'FREQ=SECONDLY;INTERVAL=10',
      enabled         => TRUE,
      auto_drop       => FALSE,
      comments        => 'Procesa registros NEW de la tabla SZRSSBP'
   );
END;

BEGIN
   DBMS_SCHEDULER.CREATE_JOB (
      job_name        => 'JOB_REGISTRA_DOC_INT',
      job_type        => 'STORED_PROCEDURE',
      job_action      => 'PKG_INT_BRIPACE_PERS.p_registra_persona_int',
      start_date      => SYSTIMESTAMP,
      repeat_interval => 'FREQ=SECONDLY;INTERVAL=10',
      enabled         => TRUE,
      auto_drop       => FALSE,
      comments        => 'Procesa registros NEW de la tabla SZRPEBP'
   );
END;


BEGIN
   DBMS_SCHEDULER.CREATE_JOB (
      job_name        => 'JOB_REGISTRA_ENROLL_INT',
      job_type        => 'STORED_PROCEDURE',
      job_action      => 'PKG_INT_BRIPACE_ENROLL.p_registra_enroll_doc_int',
      start_date      => SYSTIMESTAMP,
      repeat_interval => 'FREQ=SECONDLY;INTERVAL=10',
      enabled         => TRUE,
      auto_drop       => FALSE,
      comments        => 'Procesa registros NEW, DEL de la tabla SZREDBP'
   );
END;

BEGIN
       DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'JOB_REGISTRA_ENROLL_EST_INT',
        job_type        => 'STORED_PROCEDURE',
        job_action      => 'PKG_INT_BRIPACE_ENROLL.P_PROCESA_ENROLLMENT_INT',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=SECONDLY;INTERVAL=10',
        enabled         => TRUE,
        auto_drop       => FALSE,
        comments        => 'Procesa enrollment de estudiantes mediante el proceso orquestador'
    );
END;


BEGIN

    DBMS_SCHEDULER.CREATE_JOB (
        job_name        => 'JOB_PROCESA_RESPONSE_BS',
        job_type        => 'STORED_PROCEDURE',
        job_action      => 'INTEGRACION.PKG_INT_BRIPACE_UTIL.P_PROCESA_RESPONSE',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=SECONDLY;INTERVAL=20',
        enabled         => TRUE,
        auto_drop       => FALSE,
        comments        => 'Procesa las respuestas de la integracion Brightspace cada minuto para docentes'
    );

END;

BEGIN

    DBMS_SCHEDULER.CREATE_JOB (
        job_name        => 'JOB_PROCESA_RESPONSE_BS_ALU',
        job_type        => 'STORED_PROCEDURE',
        job_action      => 'INTEGRACION.PKG_INT_BRIPACE_UTIL.P_PROCESA_RESPONSE_ALU',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=SECONDLY;INTERVAL=20',
        enabled         => TRUE,
        auto_drop       => FALSE,
        comments        => 'Procesa las respuestas de la integracion Brightspace cada minuto para alumnos'
    );

END;

BEGIN

    DBMS_SCHEDULER.CREATE_JOB (
        job_name        => 'JOB_PROCESA_CALIFICACIONES',
        job_type        => 'PLSQL_BLOCK',
        job_action      => '
            BEGIN
                PKG_INT_BS_GRADE.p_procesa_calificaciones;
                PKG_INT_BS_GRADE.p_inserta_itvexgr;
            END;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=SECONDLY;INTERVAL=20',
        enabled         => TRUE,
        comments        => 'Procesa calificaciones y luego inserta en tabla espejo itvexgr'
    );

END;

-- CREAR USER ESTUDIANTE
BEGIN
    DBMS_SCHEDULER.CREATE_JOB (
        job_name        => 'JOB_REGISTRA_ALU_INT',
        job_type        => 'PLSQL_BLOCK',
        job_action      => '
            BEGIN
                PKG_INT_BRIPACE_PERS.p_registra_alumnos;
                PKG_INT_BRIPACE_PERS.p_registra_alumnos_int;
            END;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=SECONDLY;INTERVAL=60',
        enabled         => TRUE,
        comments        => 'Procesa alumnos y los deja en tabla integracion'
    );

END;



-- CONSULTAR LOS JOBS

SELECT job_name,
       enabled,
       state,
       last_start_date,
       next_run_date
FROM user_scheduler_jobs
WHERE job_name LIKE '%JOB%REGISTRA%INT%';

-- HABILITAR JOB
BEGIN
    DBMS_SCHEDULER.ENABLE(
        name => 'BANINST1.JOB_PROCESA_RESPONSE_BS'
    );
END;

BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'JOB_PROCESA_ESTADO_USUARIO',
        job_type        => 'PLSQL_BLOCK',
        job_action      => q'[
            BEGIN
                -- ACTIVAR USUARIOS
                BEGIN
                    PKG_INT_BRIPACE_PERS.P_PROCESA_ESTADO_ALU(
                        P_OP_TYPE   => 'ACTIVE_USER',
                        P_IS_ACTIVE => 'true'
                    );
                EXCEPTION
                    WHEN OTHERS THEN
                        NULL;
                END;

                -- INACTIVAR USUARIOS
                BEGIN
                    PKG_INT_BRIPACE_PERS.P_PROCESA_ESTADO_ALU(
                        P_OP_TYPE   => 'INACTIVE_USER',
                        P_IS_ACTIVE => 'false'
                    );
                EXCEPTION
                    WHEN OTHERS THEN
                        NULL;
                END;
            END;
        ]',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=SECONDLY;INTERVAL=10',
        enabled         => TRUE,
        auto_drop       => FALSE,
        comments        => 'Procesa activacion e inactivacion de usuarios Brightspace cada 10 segundos'
    );
END;

-- DESABILITAR JOB
BEGIN
    DBMS_SCHEDULER.DISABLE(
        NAME  => 'BANINST1.JOB_PROCESA_ESTADO_USUARIO',
        FORCE => TRUE
    );
END;
