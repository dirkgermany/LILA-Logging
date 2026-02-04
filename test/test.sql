drop table test_log_detail purge;
drop table lila_log purge;
drop table lila_log_detail purge;
drop table local_log purge;
drop table local_log_detail purge;
drop table remote_log purge;
drop table remote_log_detail purge;

exec lila.SERVER_SEND_EXIT('{"msg":"okay"}');


DECLARE
    v_sessionRemote1_id VARCHAR2(100);
    v_sessionRemote2_id VARCHAR2(100);
    v_sessionRemote3_id VARCHAR2(100);
    v_sessionLokal_id   VARCHAR2(100);
    v_remoteCloser_id   VARCHAR2(100);
    v_shutdownResponse  VARCHAR2(500);
BEGIN

    -- Start remote LILA server
    lila.start_server('LILA_P1', 'geheim');
    lila.start_server('LILA_P2', 'geheim');
    dbms_session.sleep(5);

    -- New remote sessions
    v_sessionRemote1_id := lila.server_new_session('{"process_name":"Remote Session","log_level":8,"steps_todo":3,"days_to_keep":3,"tabname_master":"remote_log"}');
    dbms_output.put_line('Session remote: ' || v_sessionRemote1_id);
    v_sessionRemote2_id := lila.server_new_session('{"process_name":"Remote Session","log_level":8,"steps_todo":3,"days_to_keep":3,"tabname_master":"remote_log"}');
    dbms_output.put_line('Session remote: ' || v_sessionRemote2_id);
    v_sessionRemote3_id := lila.server_new_session('{"process_name":"Remote Session","log_level":8,"steps_todo":3,"days_to_keep":3,"tabname_master":"remote_log"}');
    dbms_output.put_line('Session remote: ' || v_sessionRemote3_id);
    
    -- New local session
    v_sessionLokal_id := lila.new_session('Local Session', 8, 'local_log');
    dbms_output.put_line('Session lokal: ' || v_sessionLokal_id);
   
    -- Bulk send
    for i in 1..1000 loop
        lila.info(v_sessionLokal_id, 'Nachricht vom lokalen Client');
        lila.info(v_sessionRemote1_id, 'Nachricht von Client 1');
        lila.info(v_sessionRemote2_id, 'Nachricht von Client 2');
    end loop;
   
    v_shutdownResponse := lila.close_session(v_sessionRemote1_id);
    dbms_output.put_line('Close: ' || v_shutdownResponse);
    v_shutdownResponse := lila.close_session(v_sessionRemote2_id);
    dbms_output.put_line('Close: ' || v_shutdownResponse);
    v_shutdownResponse := lila.close_session(v_sessionLokal_id);
    dbms_output.put_line('Close: ' || v_shutdownResponse);

    -- Session dedicated to server shutdown
    v_remoteCloser_id := lila.server_new_session('{"process_name":"Remote Session","log_level":8,"steps_todo":3,"days_to_keep":3,"tabname_master":"remote_log"}');
    dbms_output.put_line('Session remote for later server shutdown: ' || v_sessionRemoteCloser_id);  
    lila.server_shutdown(v_remoteCloser_id);
    dbms_output.put_line('Any server closed');
        
    -- Shutdown another server
    v_remoteCloser_id := lila.server_new_session('{"process_name":"Remote Session","log_level":8,"steps_todo":3,"days_to_keep":3,"tabname_master":"remote_log"}');
    dbms_output.put_line('Session remote: ' || v_sessionRemoteCloser_id);    
    lila.server_shutdown(v_remoteCloser_id);
    dbms_output.put_line('Another server closed');

END;
/
