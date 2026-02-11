# LILA API

<details>
<summary>📖<b>Content</summary>b></summary>

- [Functions and Procedures](#functions-and-procedures)
  - [Session related Functions and Procedures](#session-related-functions-and-procedures)
    - [Function NEW_SESSION](#function-new_session--server_new_session)
    - [Procedure CLOSE_SESSION](#procedure-close_session)
    - [Procedure SET_PROCESS_STATUS](#procedure-set_process_status)
    - [Procedure SET_STEPS_TODO](#procedure-set_steps_todo)
    - [Procedure SET_STEPS_DONE](#procedure-set_steps_done)
    - [Procedure STEP_DONE](#procedure-step_done)
  - [Write Logs related Procedures](#write-logs-related-procedures)
    - [General Logging Procedures](#general-logging-procedures)
    - [Procedure LOG_DETAIL](#procedure-log_detail)
  - [Appendix](#appendix)
    - [Log Level](#log-level)
        - [Declaration of Log Levels](#declaration-of-log-levels)

</details>


> [!TIP]
> This document serves as the LILA API reference, providing a straightforward description of the programming interface. For those new to LILA, I recommend starting with the document ["architecture and concepts.md"](docs/architecture-and-concepts.md), which (hopefully) provides a fundamental understanding of how LILA works. Furthermore, the demos and examples in the #demo folder demonstrate how easily the LILA API can be integrated.

---
## Functions and Procedures
Parameters for procedures and functions can be mandatory, nullable, or optional and some can have default values.In the overview tables, they are marked as follows:

### Shortcuts for parameter requirement
* <a id="M"> ***M***andatory</a>
* <a id="O"> ***O***ptional</a>
* <a id="N"> ***N***ullable</a>
* <a id="D"> ***D***efault</a>

The functions and procedures are organized into the following five groups:
* Session Handling
* Process Control
* Logging
* Metrics
* Server Control

---
### Session Handling

| Name               | Type      | Description                         | Scope
| ------------------ | --------- | ----------------------------------- | ---------
| [NEW_SESSION](#function-new_session--server_new_session) | Function  | Opens a new log session | Session control
| [SERVER_NEW_SESSION](#function-new_session--server_new_session) | Function  | Opens a new decoupled session | Session control
| [CLOSE_SESSION](#procedure-close_session) | Procedure | Ends a log session | Session control

All API calls are the same, independent of whether LILA is used 'locally' or in a 'decoupled' manner. One exception is the function `SERVER_NEW_SESSION`, which initializes the LILA package to function as a dedicated client, managing the communication with the LILA server seamlessly. **The parameters and return value of `SERVER_NEW_SESSION` are identical to those of `NEW_SESSION`.**


#### Function NEW_SESSION / SERVER_NEW_SESSION
The `NEW_SESSION` resp. `SERVER_NEW_SESSION` function starts the logging session for a process. This procedure must be called first. Calls to the API without a prior `NEW_SESSION` do not make sense or can (theoretically) lead to undefined states.
`NEW_SESSION` and `SERVER_NEW_SESSION` are overloaded so various signatures are available.

**Signatures**

To accommodate different logging requirements, the following variants are available:

<details>
  <summary><b>1. Basic Mode</b> (Standard initialization)</summary>
  
 ```sql
  FUNCTION NEW_SESSION(
    p_processName   VARCHAR2, 
    p_logLevel      PLS_INTEGER, 
    p_TabNameMaster VARCHAR2 DEFAULT 'LILA_LOG'
  )
 ```
</details>

<details>
  <summary><b>2. Retention Mode</b> (With automated cleanup)</summary>

```sql
FUNCTION NEW_SESSION(
  p_processName   VARCHAR2, 
  p_logLevel      PLS_INTEGER, 
  p_daysToKeep    PLS_INTEGER, 
  p_TabNameMaster VARCHAR2 DEFAULT 'LILA_LOG'
)
 ```
</details>

<details>
  <summary><b>3. Full Progress Mode</b> (With progress tracking)</summary>

```sql
FUNCTION NEW_SESSION(
  p_processName   VARCHAR2, 
  p_logLevel      PLS_INTEGER, 
  p_stepsToDo     PLS_INTEGER, 
  p_daysToKeep    PLS_INTEGER, 
  p_TabNameMaster VARCHAR2 DEFAULT 'LILA_LOG'
)
 ```
</details>

**Parameters**

| Parameter | Type | Description | Required
| --------- | ---- | ----------- | -------
| p_processName | VARCHAR2| freely selectable name for identifying the process; is written to *master table* | [`M`](#m)
| p_logLevel | PLS_INTEGER | determines the level of detail in *detail table* (see above) | [`M`](#m)
| p_stepsToDo | PLS_INTEGER | defines how many steps must be done during the process | [`O`](#o)
| p_daysToKeep | PLS_INTEGER | max. age of entries in days; if not NULL, all entries older than p_daysToKeep and whose process name = p_processName (not case sensitive) are deleted | [`O`](#o)
| p_TabNameMaster | VARCHAR2 | optional prefix of the LOG table names (see above) | [`D`](#d)

**Returns**
* Type: NUMBER
* Description: The new process ID; this ID is required for subsequent calls in order to be able to assign the LOG calls to the process

**Example**
```sql
DECLARE
  v_processId NUMBER;
BEGIN
  -- Using the "Retention" variant
  v_processId := NEW_SESSION('DATA_IMPORT', 2, 30);
END;

```

#### Procedure CLOSE_SESSION
Ends a logging session with optional final informations. Four function signatures are available for different scenarios.

**Signatures**

<details>
  <summary><b>1. No information about process</b> (Standard)</summary>
  
 ```sql
  PROCEDURE CLOSE_SESSION(
    p_processId     NUMBER
  )
 ```
</details>

<details>
  <summary><b>2. Update process info and process status</b> (Standard)</summary>
  
 ```sql
  PROCEDURE CLOSE_SESSION(
    p_processId     NUMBER,
    p_processInfo   VARCHAR2,
    p_processStatus PLS_INTEGER
  )
 ```
</details>

<details>
  <summary><b>3. Update process info and metric results</b> (Standard)</summary>
  
 ```sql
  PROCEDURE CLOSE_SESSION(
    p_processId     NUMBER,
    p_stepsDone     PLS_INTEGER,
    p_processInfo   VARCHAR2,
    p_processStatus PLS_INTEGER
  )
 ```
</details>

<details>
  <summary><b>4. Update complete process data and complete metric data</b> (Standard)</summary>
  
 ```sql
  PROCEDURE CLOSE_SESSION(
    p_processId     NUMBER,
    p_stepsToDo     PLS_INTEGER,
    p_stepsDone     PLS_INTEGER,
    p_processInfo   VARCHAR2,
    p_processStatus PLS_INTEGER
  )
 ```
</details>

**Parameters**

| Parameter | Type | Description | Required
| --------- | ---- | ----------- | -------
| p_processId | NUMBER | ID of the process to which the session applies | [`M`](#m)
| p_stepsToDo | PLS_INTEGER | Number of work steps that would have been necessary for complete processing. This value must be managed by the calling package | [`N`](#n)
| p_stepsDone | PLS_INTEGER | Number of work steps that were actually processed. This value must be managed by the calling package | [`N`](#n)
| p_processInfo | VARCHAR2 | Final information about the process (e.g., a readable status) | [`N`](#n)
| p_status | PLS_INTEGER | Final status of the process (freely selected by the calling package) | [`N`](#n)


> [!IMPORTANT]
> Since LILA utilizes high-performance buffering, calling CLOSE_SESSION is essential to ensure that all remaining data is flushed and securely written to the database. To prevent data loss during an unexpected application crash, ensure that CLOSE_SESSION is part of your exception handling:
  
```sql
EXCEPTION WHEN OTHERS THEN
    -- Flushes buffered data and logs the error state before terminating
    lila.close_session(
        p_process_id  => l_proc_id, 
        p_status      => -1,          -- Your custom error status code here
        p_processInfo => SQLERRM      -- Captures the Oracle error message
    );
    RAISE;
```

---
### Process Control
Documents the lifecycle of a process.


| Name               | Type      | Description                         | Scope
| ------------------ | --------- | ----------------------------------- | -------
| [`SET_PROCESS_STATUS`](#procedure-set_process_status) | Procedure | Sets the state of the log status | Process
| [`SET_STEPS_TODO`](#procedure-set_steps_todo) | Procedure | Sets the required number of actions | Process
| [`STEP_DONE`](#procedure-step_done) | Procedure | Increments the counter of completed steps | Process
| [`SET_STEPS_DONE`](#procedure-set_steps_todo) | Procedure | Sets the number of completed actions | Process
| [`GET_PROC_STEPS_DONE`](fFunction-get_proc_steps_done) | FUNCTION | Returns number of already finished steps | Process
| [`GET_PROC_STEPS_TODO`](fFunction-get_proc_steps_done) | FUNCTION | Returns number of steps to do
| [`GET_PROCESS_START`](#function-get_process_start) | FUNCTION | Returns time of process start
| [`GET_PROCESS_END`](#function-get_process_end) | FUNCTION | Returns time of process end (if finished)
| [`GET_PROCESS_STATUS`](#function-get_process_status) | FUNCTION | Returns the process state
| [`GET_PROCESS_INFO`](#function-get_process_info) | FUNCTION | Returns info text about process
| [`GET_PROCESS_DATA`](#function-get_process_data) | FUNCTION | Returns all process data as a record (see below) 

  
#### Procedure SET_PROCESS_STATUS
The process status provides information about the overall state of the process. This integer value is not evaluated by LILA; its meaning depends entirely on the specific application scenario.

 ```sql
  PROCEDURE SET_PROCESS_STATUS(
    p_processId     NUMBER,
    p_processStatus PLS_INTEGER
  )
 ```

#### Procedure SET_STEPS_TODO
This value specifies the planned number of work steps for the entire process. There is no correlation between this value and the actual number of actions recorded within the metrics.

 ```sql
  PROCEDURE SET_STEPS_TODO(
    p_processId     NUMBER,
    p_stepsToDo     PLS_INTEGER
  )

 ```

#### Procedure STEP_DONE
Increments the number of completed steps (progress). This simplifies the management of this value within the application.

 ```sql
  PROCEDURE SET_STEPS_DONE(
    p_processId     NUMBER
  )
 ```

#### Procedure SET_STEPS_DONE
Sets the total number of completed steps. Note: Calling this procedure overwrites any progress previously calculated via `STEP_DONE`.

 ```sql
  PROCEDURE SET_STEPS_DONE(
    p_processId     NUMBER,
    p_stepsDone     PLS_INTEGER
  )
 ```

> [!NOTE]
> Whenever a record in the master table is changed, the `last_update field` is updated implicitly. This mechanism is designed to support the monitoring features.

#### Function GET_PROC_STEPS_DONE

 ```sql
  FUNCTION GET_PROC_STEPS_DONE(
    p_processId     NUMBER
  )
 ```

**Returns**
* Type: PLS_INTEGER
* Description: Number of already processed steps (progress)

#### Function GET_PROC_STEPS_TODO

 ```sql
  FUNCTION GET_PROC_STEPS_TODO(
    p_processId     NUMBER
  )
 ```

**Returns**
* Type: PLS_INTEGER
* Description: Number of planned steps

#### Function GET_PROCESS_START

 ```sql
  FUNCTION GET_PROCESS_START(
    p_processId     NUMBER
  )
 ```

**Returns**
* Type: TIMESTAMP
* Description: Numeric state of the process; depends entirely on the specific application scenario 

#### Function GET_PROCESS_STATUS

 ```sql
  FUNCTION GET_PROCESS_STATUS(
    p_processId     NUMBER
  )
 ```

**Returns**
* Type: PLS_INTEGER
* Description: Numeric state of the process; depends entirely on the specific application scenario 


#### Function GET_PROC_STEPS_DONE

 ```sql
  FUNCTION GET_PROC_STEPS_DONE(
    p_processId     NUMBER
  )
 ```



#### Record Type `t_process_rec`
Usefull for getting a complete set of all process data.

TYPE t_process_rec IS RECORD (
    id              NUMBER(19,0),
    process_name    varchar2(100),
    log_level       PLS_INTEGER,
    process_start   TIMESTAMP,
    process_end     TIMESTAMP,
    last_update     TIMESTAMP,
    proc_steps_todo PLS_INTEGER,
    proc_steps_done PLS_INTEGER,
    status          PLS_INTEGER,
    info            VARCHAR2(4000),
    tab_name_master   VARCHAR2(100)
);


---
### Logging
| [`INFO`](#general-logging-procedures) | Procedure | Writes INFO log entry               | Detail Logging
| [`DEBUG`](#general-logging-procedures) | Procedure | Writes DEBUG log entry              | Detail Logging
| [`WARN`](#general-logging-procedures) | Procedure | Writes WARN log entry               | Detail Logging
| [`ERROR`](#general-logging-procedures) | Procedure | Writes ERROR log entry              | Detail Logging


---
### Metrics
#### Setting Values
#### Querying Values

---
### Server Control

| [`PROCEDURE IS_ALIVE`](#procedure-is-alive) | Procedure | Excecutes a very simple logging session | Test



### Write Logs related Procedures
#### General Logging Procedures
The detailed log entries in *detail table* are written using various procedures.
Depending on the log level corresponding to the desired entry, the appropriate procedure is called.

The procedures have the same signatures and differ only in their names.
Their descriptions are therefore summarized below.

* Procedure ERROR: details are written if the debug level is one of
  - logLevelError
  - logLevelWarn
  - logLevelInfo
  - logLevelDebug
* Procedure WARN: details are written if the debug level is one of
  - logLevelWarn
  - logLevelInfo
  - logLevelDebug
* Procedure INFO: details are written if the debug level is one of
  - logLevelInfo
  - logLevelDebug
* Procedure DEBUG: details are written if the debug level is one of
  - logLevelDebug

| Parameter | Type | Description | Required
| --------- | ---- | ----------- | -------
| p_processId | NUMBER | ID of the process to which the session applies | [`M`](#m)
| p_stepInfo | VARCHAR2 | Free text with information about the process | [`M`](#m)

**Syntax and Examples**
```sql
-- Syntax
---------
PROCEDURE ERROR(p_processId NUMBER, p_stepInfo VARCHAR2)
PROCEDURE WARN(p_processId NUMBER, p_stepInfo VARCHAR2)
PROCEDURE INFO(p_processId NUMBER, p_stepInfo VARCHAR2)
PROCEDURE DEBUG(p_processId NUMBER, p_stepInfo VARCHAR2)

-- Usage
--------
-- assuming that gProcessId is the global stored process ID

-- write an error
lila.error(gProcessId, 'Something happened');
-- write a debug information
lila.debug(gProcessId, 'Function was called');
```

#### Procedure LOG_DETAIL
Writes a LOG entry, regardless of the currently set LOG level.

| Parameter | Type | Description | Required
| --------- | ---- | ----------- | -------
| p_processId | NUMBER | ID of the process to which the session applies | [`M`](#m)
| p_stepInfo | VARCHAR2 | Free text with information about the process | [`M`](#m)
| p_logLevel | NUMBER | This log level is written into the detail table | [`M`](#m)

**Syntax and Examples**
```sql
-- Syntax
---------
PROCEDURE LOG_DETAIL(p_processId NUMBER, p_stepInfo VARCHAR2, p_logLevel NUMBER);

-- Usage
--------
-- assuming that gProcessId is the global stored process ID

-- write a log record
lila.log_detail(gProcessId, 'I ignore the log level');
```
### Testing
Independent to other Packages you can check if LILA works in general.

#### Procedure IS_ALIVE
Creates one entry in the *master table* and one in the *detail table*.

This procedure needs no parameters.
```sql
-- execute the following statement in sql window
execute lila.is_alive;
-- check data and note the process_id
select * from lila_log where process_name = 'LILA Life Check';
-- check details using the process_id
select * from lila_log_detail where process_id = <process id>;
```

## Appendix
### Log Level
Depending on the selected log level, additional information is written to the *detail table*.
        
To do this, the selected log level must be >= the level implied in the logging call.
* logLevelSilent -> No details are written to the *detail table*
* logLevelError  -> Calls to the ERROR() procedure are taken into account
* logLevelWarn   -> Calls to the WARN() and ERROR() procedures are taken into account
* logLevelInfo   -> Calls to the INFO(), WARN(), and ERROR() procedures are taken into account
* logLevelDebug  -> Calls to the DEBUG(), INFO(), WARN(), and ERROR() procedures are taken into account

If you want to suppress any logging, set logLevelSilent as active log level.

#### Declaration of Log Levels
To simplify usage and improve code readability, constants for the log levels are declared in the specification (lila.pks).

```sql
logLevelSilent  constant number := 0;
logLevelError   constant number := 1;
logLevelWarn    constant number := 2;
logLevelInfo    constant number := 4;
logLevelDebug   constant number := 8;
```

### Record Type for init
TYPE t_session_init IS RECORD (
    processName VARCHAR2(100),
    logLevel PLS_INTEGER,
    stepsToDo PLS_INTEGER,
    daysToKeep PLS_INTEGER,
    tabNameMaster VARCHAR2(100) DEFAULT 'LILA_LOG'
);
