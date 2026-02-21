select distinct proc.id proc_id, proc.process_name process, proc.process_start, proc.proc_steps_todo, proc.proc_steps_done proc_steps_done, detail.action_count,
        proc.proc_steps_done / proc.proc_steps_todo * 100 percent_of_work,
        round((TO_NUMBER(TO_CHAR(proc.process_start, 'SSSSS.FF3'), '99999.999', 'NLS_NUMERIC_CHARACTERS = ''. ''') - 
         TO_NUMBER(TO_CHAR(proc.last_update, 'SSSSS.FF3'), '99999.999', 'NLS_NUMERIC_CHARACTERS = ''. ''')) /-60, 2) min_work
from remote_log proc
join (
    select process_id, max(action_count) action_count
    from remote_log_mon
    group by process_id
) detail
    on detail.process_id = proc.id
    and detail.action_count is not null
order by proc.id
