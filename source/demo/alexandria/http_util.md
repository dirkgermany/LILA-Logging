# Demo with http_util of "Alexandria plsql/sql utility library"

## About
**LILA: LILA Integrated Logging Architecture**
Logging and monitoring pl/sql applications: https://github.com/dirkgermany/LILA-Logging

This demo shows the integration of lila into the subproject 'http_util'
of the 'alexandria-plsql-utils' tool collection on GitHub: https://github.com/mortenbra/alexandria-plsql-utils/tree/master/ora.

## The sample
At first this sample calls up a valid web address and writes some log entries, immediately after that it calls an invalid adress.
The results of both calls you can see in the tables lila_log and lila_log_detail.

Have a look to the procedure body and see how few calls are needed for an exact logging.

## Prerequisites
To try out this example only some steps must be done before.

### Oracle ACL list
Extend ACL list as sysdba (replace placeholder USER_NAME with your user):
```sql
BEGIN
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE (
    host       => 'httpbin.org', 
    lower_port => 443,
    upper_port => 443,
    ace        => xs$ace_type(privilege_list => xs$name_list('http', 'connect'),
                              principal_name => 'USER_NAME', -- mostly written in uppercase!
                              principal_type => XS_ACL.PTYPE_DB)
  );
END;
/
```
### Privileges of your schema user
Grant the user certain rights (also with sysdba rights)
```sql
GRANT RESOURCE TO USER_NAME;
GRANT EXECUTE ANY PROCEDURE TO USER_NAME;
GRANT SELECT ANY TABLE TO USER_NAME;
GRANT CREATE TABLE TO USER_NAME;
GRANT CREATE SESSION TO USER_NAME;
GRANT EXECUTE ON UTL_HTTP TO USER_NAME;
```
### Create demo package
1. Copy pl/sql code of both script files (lila_demo_http.pks and lila_demo_http.pkb) into the sql window and execute them.
   * at first the .pks file
   * then the .pkb file

## Try the demo and see log results
Execution of demo package
```sql
exec lila_demo_http.getBlobFromUrl;
```

See log entries. The detailed table contains the backtrace and the error stack.
```sql
-- Process overview with status:
select * from lila_log;
-- Details
select * from lila_log_detail order by process_id, no;

   
