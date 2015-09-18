Rem    NAME
Rem      tapigen2_install.sql
Rem
Rem    DESCRIPTION
Rem 	 TAPI Gen2 installation script.
Rem
Rem    REQUIREMENTS
Rem      - Oracle Database 10 or later
Rem
Rem    Example:
Rem      sqlplus "user/userpasss" @tapigen2_install
Rem
Rem    MODIFIED   (MM/DD/YYYY)
Rem    osalvador  16/09/2015 - Created

whenever sqlerror exit
-- User Grants
DECLARE
   l_count   PLS_INTEGER := 0;
BEGIN
   SELECT   COUNT ( * )
     INTO   l_count
     FROM   user_tab_privs
    WHERE   table_name = 'DBMS_CRYPTO' AND privilege = 'EXECUTE';

   IF l_count = 0
   THEN
      raise_application_error (-20000, 'Execute on DBMS_CRYPTO grant is necessary.');
   END IF;
END;
/

whenever sqlerror continue

@@../packages/tePLSQL.pks
@@../packages/TAPI_GEN2.pks
@@../tables/TE_TEMPLATES.sql
@@../packages/tePLSQL.pkb
@@../packages/TAPI_GEN2.pkb

quit;
/
