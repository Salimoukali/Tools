REM --- Marking Strings --------------------------------------
REM --- @(#)F3GFAR-S: $Workfile:   kill_session.sql  $ $Revision:   1.3  $
REM-----------------------------------------------------------------------------------------------
REM--- @(#)F3GFAR-E: $Workfile:   kill_session.sql  $ VersionLivraison = 2.0.0.0
REM-----------------------------------------------------------------------------------------------
REM ----------------------------------------------------------

 set heading off
 set termout off
 set verify off
 set echo off
 set feedback off
 
 spool &2
 
 SELECT 'alter system kill session '''||sid||','||serial#||''' ;' 
 FROM v_$session
 WHERE username=upper('&1');
 
 spool off
 
@&2

exit
 
 



