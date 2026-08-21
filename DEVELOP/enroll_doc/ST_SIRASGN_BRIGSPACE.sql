CREATE OR REPLACE TRIGGER ST_SIRASGN_BRIGSPACE
AFTER INSERT OR DELETE ON SIRASGN
FOR EACH ROW
BEGIN

   IF INSERTING THEN

      PKG_INT_BRIPACE_ENROLL.p_registra_enroll_doc(
          p_action    => 'I',
          p_term_code => :NEW.SIRASGN_TERM_CODE,
          p_crn       => :NEW.SIRASGN_CRN,
          p_pidm      => :NEW.SIRASGN_PIDM,
          p_cat       => :NEW.SIRASGN_CATEGORY,
          p_line      => 'ON',
          p_prim_ind  => :NEW.SIRASGN_PRIMARY_IND);

   ELSIF DELETING THEN

      PKG_INT_BRIPACE_ENROLL.p_registra_enroll_doc(
          p_action    => 'D',
          p_term_code => :OLD.SIRASGN_TERM_CODE,
          p_crn       => :OLD.SIRASGN_CRN,
          p_pidm      => :OLD.SIRASGN_PIDM,
          p_cat       => :OLD.SIRASGN_CATEGORY,
          p_line      => 'ON',
          p_prim_ind  => :OLD.SIRASGN_PRIMARY_IND);

   END IF;

END;
