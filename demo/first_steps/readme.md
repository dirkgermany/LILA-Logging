# First steps

## LILA
**LILA: LILA Is Logging Architecture**
Logging and monitoring PL/SQL applications: https://github.com/dirkgermany/LILA-Logging

## This demo app
This demo shows the basic API-calls (and there aren't many more) of LILA:
* Opening new log session
* Closing log session
* Writing log entries
* Updating process (application) status

This demo also includes an example of how the LILA API supports application **monitoring** (see procedure increment_steps_and_monitor).

---
## Prerequisites
To try out this example only some steps must be done before.

### Privileges of your schema user
Grant the user certain rights (also with sysdba rights)
```sql
GRANT EXECUTE ANY PROCEDURE TO USER_NAME;
GRANT SELECT ANY TABLE TO USER_NAME;
GRANT CREATE TABLE TO USER_NAME;
GRANT CREATE SESSION TO USER_NAME;
GRANT EXECUTE ON UTL_HTTP TO USER_NAME;
```
### Create packages
Two packages are needed.
Copy PL/SQL code of the LILA package and the sample package (.pks and .pkb) into the sql window and execute them.

#### LILA
Find the package under https://github.com/dirkgermany/LILA-Logging/tree/main/source/package.

#### Demo
Same directory as where you found this .md-file: https://github.com/dirkgermany/LILA-Logging/new/main/demo/first_steps.

---
## Try the demo and see log results
Execution of sample procedures/functions. For example:
```sql
exec learn_lila.simple_sample;
```

See log entries. The detailed table contains the backtrace and the error stack.
```sql
-- Process overview with status:
select * from lila_log;
-- Details
select * from lila_log_detail order by process_id, no;

   
