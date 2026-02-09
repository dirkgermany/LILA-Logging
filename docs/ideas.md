
## Laufzeitkontrolle der Prozesse
```sql
select distinct proc.id proc_id, proc.process_name process, proc.process_start, proc.proc_steps_done proc_steps_done, detail.mon_steps_done,
        proc.proc_steps_todo * 100 / proc.proc_steps_done percent_of_work,
        round((TO_NUMBER(TO_CHAR(proc.process_start, 'SSSSS.FF3'), '99999.999', 'NLS_NUMERIC_CHARACTERS = ''. ''') - 
         TO_NUMBER(TO_CHAR(proc.last_update, 'SSSSS.FF3'), '99999.999', 'NLS_NUMERIC_CHARACTERS = ''. ''')) /-60, 2) min_work
from remote_log proc
join (
    select process_id, max(mon_steps_done) mon_steps_done
    from remote_log_detail
    group by process_id
) detail
    on detail.process_id = proc.id
    and detail.mon_steps_done is not null
order by proc.id
;
```


### Lösung: Der System-Trigger (ON LOGOFF)
Du kannst LILA noch "runder" machen, indem du ein fertiges Snippet für einen AFTER LOGOFF ON SCHEMA Trigger in deine Dokumentation/Installation packst.
So würde ein solcher Sicherheits-Trigger für LILA aussehen:

Du könntest eine Prozedur lila.enable_safety_trigger anbieten, die das dynamisch per EXECUTE IMMEDIATE erledigt.
Warum das Monitoring davon profitiert:
Wenn ein Prozess hart abstürzt, bleibt bei vielen Frameworks der Status in der Monitoring-Tabelle auf "Running" stehen (eine "Leiche"). Mit dem Logoff-Flush oder einem Cleanup-Trigger kannst du den Status beim Abbruch der Verbindung automatisch auf "ABORTED" setzen. Das macht dein Monitoring-Level (Level 3) wesentlich zuverlässiger.

## Die Singleton-Herausforderung (Server-Lock)
Damit nicht zwei Prozesse gleichzeitig DBMS_ALERT.WAITONE auf denselben Kanal machen (was zu unvorhersehbarem Verhalten führt), ist DBMS_LOCK (oder in neueren Versionen DBMS_APPLICATION_INFO) dein Freund.
### Einfachste Lösung:
Bevor der LOOP startet, versucht der Server einen exklusiven Lock zu setzen:
```sql
l_lock_result := DBMS_LOCK.REQUEST(
    lockhandle => l_lock_handle,
    lockmode   => DBMS_LOCK.X_MODE,
    timeout    => 0, -- Sofort fehlschlagen, wenn besetzt
    release_on_commit => FALSE
);

IF l_lock_result != 0 THEN
    raise_application_error(-20001, 'LILA-Server läuft bereits.');
END IF;
```
