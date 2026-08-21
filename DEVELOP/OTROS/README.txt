quiero hacer un mapa de esta integracion de banner con Brigspace 
* hay varias procesos de integracion
* PERIODO: Se activa trigger con la tabla SOBPTRM y llama a proc : PKG_INT_BRIPACE_TERM.p_registra_periodo y genera datos en tabla intermedia: szrtmbp
 tiene un JOB--> PKG_INT_BRIPACE_TERM.P_REGISTRA_PERIODO_INT que hace la integracion, pasa los datos desde la intermedia szrtmbp a la tabla de integracion general: itzbgsp
 
* NRC: trigger tabla SSBSECT, proc: --> PKG_INT_BRIPACE_NRC.p_registra_nrc , tabla inter: SZRSSBP. Job : --> 
* USUARIO: trig tabla SIBINST, proc: PKG_INT_BRIPACE_PERS.p_registra_persona, tabla inter: SZRPEBP, job
* ENROLLMENT DOCENTE
* ENROLLMANT ESTUDIANTE

