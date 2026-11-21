TRIGGER integracion.st_itzbgsp_prgnrep
AFTER INSERT OR UPDATE OR DELETE
ON integracion.itzbgsp
FOR EACH ROW
BEGIN
   IF INSERTING THEN

      INSERT INTO prgnrep.ivzbgsp
      (
         ID,
         BUSINESS_LINE,
         REQUEST,
         RESPONSE,
         CREATE_DATE,
         REQUEST_DATE,
         RESPONSE_DATE,
         OP_TYPE,
         STATUS,
         PIDM,
         ID_SPRIDEN
         
      )
      VALUES
      (
         :NEW.ID,
         :NEW.BUSINESS_LINE,
         :NEW.REQUEST,
         :NEW.RESPONSE,
         :NEW.CREATE_DATE,
         :NEW.REQUEST_DATE,
         :NEW.RESPONSE_DATE,
         :NEW.OP_TYPE,
         :NEW.STATUS,
         :NEW.PIDM,
         :NEW.ID_SPRIDEN
      );

   ELSIF UPDATING THEN

      UPDATE prgnrep.ivzbgsp
         SET BUSINESS_LINE = :NEW.BUSINESS_LINE,
             REQUEST       = :NEW.REQUEST,
             RESPONSE      = :NEW.RESPONSE,
             CREATE_DATE   = :NEW.CREATE_DATE,
             REQUEST_DATE  = :NEW.REQUEST_DATE,
             RESPONSE_DATE = :NEW.RESPONSE_DATE,
             OP_TYPE       = :NEW.OP_TYPE,
             STATUS        = :NEW.STATUS,
             PIDM          = :NEW.PIDM,
             ID_SPRIDEN    = :NEW.ID_SPRIDEN
       WHERE ID = :NEW.ID;

   ELSIF DELETING THEN

      DELETE
        FROM prgnrep.ivzbgsp
       WHERE ID = :OLD.ID;

   END IF;
END;