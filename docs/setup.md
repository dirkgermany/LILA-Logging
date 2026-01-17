# Setting up LILA

## Overview
Since LILA is a pl/sql package, only a few steps are required for commissioning and use.

All steps below are done in the oracle database.

Ultimately, three database objects are required:
* Two Tables
* One Sequence

In order to perform logging, the schema user must also have the necessary rights.
As a rule, these rights should already exist, as LILA is only an addition to existing PL/SQL packages.
If you got in trouble see the section [`Trouble Shooting`](#trouble-shooting)

## Login to database schema
Within your preferred sql tool (e.g. sqlDeveloper) login to the desired database schema.
All following steps will done in the same schema (except trouble shooting commands).

## Creating Sequence
First of all the Sequence for the process IDs must exist. Otherwise the packages cannot be compiled.
Execute the following statement:
```sql
CREATE SEQUENCE SEQ_LILA_LOG MINVALUE 0 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 10 NOORDER  NOCYCLE  NOKEEP  NOSCALE  GLOBAL;
```

## Creating Package
Is done by copy&paste and execute
1. Copy the complete content of lila.pks (the specification) into your preferred sql tool (e.g. sqlDeveloper) and execute the sql script
2. Copy the complete content of lila.pkb (the body) and execute the sql script
3. Open the new package LILA (perhaps you have to refresh the object tree in your sql tool)

That's it. If you got exceptions when executing the scripts please see [`Trouble Shooting`](#trouble-shooting).


## Trouble shooting
Most problems are caused by insufficient permissions.
Log in to the database with DBA rights(*sys* or *system*).
Execute the following statements. You may want to try this iteratively, executing one statement at a time and attempting to perform the setup steps immediately after each one.
```sql
GRANT CREATE SESSION TO <schema user>;
GRANT CREATE TABLE TO <schema user>;
GRANT CREATE PROCEDURE TO <schema user>;
GRANT CREATE SEQUENCE TO <schema user>;
```

If the user who executes your scripts, is not the same, you have to grant one more Privilege:
```sql
GRANT EXECUTE ON <schema user>.LILA TO <another schema user>;
```

## Testing
After all creation steps are done successfully, you can test LILA by calling the life check :)
```sql
-- call LILA
execute lila.is_alive;
-- show LILA log data
select * from LILA_LOG;
select * from LILA_LOG_DETAIL;
```
