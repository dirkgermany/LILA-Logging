# simpleOraLogger

## About
PL/SQL Package for simple logging of PL/SQL processes. Allows multiple and parallel logging out of the same session.

Even though debug information can be written, simpleOraLogger is primarily intended for monitoring (automated) PL/SQL processes (hereinafter referred to as the processes).
For easy daily monitoring log informations are written into two tables: one to see the status of your processes, one to see more details, e.g. something went wrong.
Your processes can be identified by their names.

## Simple means:
* Copy the package code to your database schema
* Call the logging procedures/functions out of your PL/SQL code
* Check log entries in the log tables

## Logging
simpleOraLogger monitors different informations about your processes.

***General informations***
* Process name
* Process ID
* Begin and Start
* Steps todo and steps done
* Any info
* (Last) status

***Detailed informations***
* Process ID
* Serial number
* Any info
* Log level
* Session time
* Session user
* Host name
* Error stack (when exception was thrown)
* Error backtrace (depends to log level)
* Call stack (depends to log level)

## Demo
You should use a 'global' variable to store the process id (better: logging).
```sql
   -- global process ID related to your logging process
   gProcessId number(19,0);
```
At first in your 'main' routine begin the log session
```sql
   -- begin a new logging session
   gProcessId := simpleOraLogger.new_session('my application', simpleOraLogger.logLevelWarn, 30);
```
Write log entries wherever you want
```sql
   -- e.g. simple informations
   simpleOraLogger.info(gProcessId, 'Something happened or not');
   -- e.g. informations when an exception was raised
   simpleOraLogger.error(gProcessId, 'I made a fault');

   -- also you can change the status during your process runs
   simpleOraLogger.set_process_status(1, 'DONE');
```
At last action end the logging session
```sql
  -- opional you can set the numbers of steps to do and steps done 
  simpleOraLogger.close_session(gProcessId, 100, 99, 'DONE', 1);
```

