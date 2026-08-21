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




-- CONSULTAR LOS JOBS

SELECT job_name,
       enabled,
       state,
       last_start_date,
       next_run_date
FROM user_scheduler_jobs
WHERE job_name LIKE '%JOB%REGISTRA%INT%';