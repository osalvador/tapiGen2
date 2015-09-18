Rem    NAME
Rem      tapigen2_install.sql
Rem
Rem    DESCRIPTION
Rem 	 TAPI Gen2 uninstallation script.
Rem
Rem    REQUIREMENTS
Rem      - Oracle Database 10 or later
Rem
Rem    Example:
Rem      sqlplus "user/userpasss" @tapigen2_uninstall
Rem
Rem    MODIFIED   (MM/DD/YYYY)
Rem    osalvador  16/09/2015 - Created

DROP PACKAGE TAPI_GEN2;
DROP PACKAGE tePLSQL;
DROP TABLE TE_TEMPLATES;

quit;
/
