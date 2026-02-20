create or replace PACKAGE BODY LILAM_MAILER AS

    TYPE t_alert_rec IS RECORD (
        alert_id            NUMBER,
        process_id          NUMBER,
        master_table_name   VARCHAR2(50),
        monitor_table_name  VARCHAR2(50),
        action_name         VARCHAR2(50),
        context_name        VARCHAR2(50),
        action_count        PLS_INTEGER,
        rule_set_name       VARCHAR2(50),
        rule_id             VARCHAR2(50),
        rule_set_version    PLS_INTEGER,
        alert_severity      VARCHAR2(30)
    );
    
    TYPE t_json_rec IS RECORD (
        id                  varchar2(30),
        trigger_type        varchar2(30),
        action              varchar2(50),
        condition_operator  varchar2(50),
        condition_value     varchar2(50),
        alert_handler       varchar2(30),
        alert_severity      varchar2(30),
        alert_throttle      pls_integer
    );
    
    TYPE t_process_rec IS RECORD (
        process_id      NUMBER,
        process_name    VARCHAR2(50),
        process_start   TIMESTAMP,
        process_end     TIMESTAMP,
        process_status  PLS_INTEGER,
        process_info    VARCHAR2(1000),
        steps_todo      PLS_INTEGER,
        steps_done      PLS_INTEGER,
        monitor_type    PLS_INTEGER,
        action_name     VARCHAR2(50),
        context_name    VARCHAR2(50),
        action_start    TIMESTAMP,
        action_stop     TIMESTAMP,
        action_count    PLS_INTEGER,
        used_millis     PLS_INTEGER,
        avg_millis      PLS_INTEGER
    );
    
    -------------------------------------------------------------------------
    
    function get_ms_diff(p_start timestamp, p_end timestamp) return number is
        v_diff interval day(0) to second(3); -- Präzision auf ms begrenzen
    begin
        v_diff := p_end - p_start;
        -- Wir extrahieren nur die Sekunden inklusive der Nachkommastellen (ms)
        -- und addieren die Minuten/Stunden/Tage als Sekunden-Vielfache
        return (extract(day from v_diff) * 86400000)
             + (extract(hour from v_diff) * 3600000)
             + (extract(minute from v_diff) * 60000)
             + (extract(second from v_diff) * 1000);
    end;

    -------------------------------------------------------------------------

    PROCEDURE send_mail_via_relay(p_subject VARCHAR2, p_body VARCHAR2, p_recipient VARCHAR2) IS
        l_conn  utl_smtp.connection;
        l_offset     NUMBER := 1;
        l_chunk_size NUMBER := 1500; -- Bleibt sicher unter dem SMTP-Limit
        l_body_len   NUMBER := DBMS_LOB.GETLENGTH(p_body);
    BEGIN
        -- 1. Verbindung zum lokalen Postfix (ohne Wallet!)
        l_conn := utl_smtp.open_connection('localhost', 25);
        utl_smtp.helo(l_conn, 'localhost');
        
        -- 2. Absender und Empfänger (Strato braucht eine valide Absender-Mail)
        utl_smtp.mail(l_conn, 'dirk@dirk-goldbach.de');
        utl_smtp.rcpt(l_conn, p_recipient);
        
        -- 3. Die Mail-Daten (Header)
        utl_smtp.open_data(l_conn);
        

        utl_smtp.write_data(l_conn, 'From: LILAM Engine <dirk@dirk-goldbach.de>' || utl_tcp.crlf);
        utl_smtp.write_data(l_conn, 'To: ' || p_recipient || utl_tcp.crlf);
        utl_smtp.write_data(l_conn, 'Subject: ' || p_subject || utl_tcp.crlf);
        
        -- 4. DER ENTSCHEIDENDE TEIL: MIME-Version und HTML Content-Type
        utl_smtp.write_data(l_conn, 'MIME-Version: 1.0' || utl_tcp.crlf);
        utl_smtp.write_data(l_conn, 'Content-Type: text/html; charset=UTF-8' || utl_tcp.crlf);

        utl_smtp.write_data(l_conn, utl_tcp.crlf);
        
        -- 5. Der CLOB-Splitter (Damit keine Zeilen mehr zerreißen)
        WHILE l_offset <= l_body_len LOOP
            utl_smtp.write_data(l_conn, DBMS_LOB.SUBSTR(p_body, l_chunk_size, l_offset));
            l_offset := l_offset + l_chunk_size;
        END LOOP;
--        utl_smtp.write_data(l_conn, p_body);

        utl_smtp.close_data(l_conn);
        
        utl_smtp.quit(l_conn);
    END;
    
    -------------------------------------------------------------------------

    function readJsonRule(p_alert_rec t_alert_rec) return t_json_rec
    as
        l_json_rec t_json_rec;
    begin
        -- 3. Regel-Details aus LILAM_RULES extrahieren
        SELECT jt.id, jt.trigger_type, jt.action, jt.condition_operator,
            jt.condition_value, jt.alert_handler, jt.alert_severity, jt.alert_throttle
        INTO  l_json_rec.id, l_json_rec.trigger_type, l_json_rec.action, l_json_rec.condition_operator,
            l_json_rec.condition_value, l_json_rec.alert_handler, l_json_rec.alert_severity, l_json_rec.alert_throttle
        FROM LILAM_RULES lr,
             JSON_TABLE(lr.rule_set, '$.rules[*]'
                COLUMNS (
                    id                  varchar2 PATH '$.id',
                    trigger_type        varchar2 PATH '$.trigger_type',
                    action              varchar2 PATH '$.action',
                    condition_operator  varchar2 PATH '$.condition.operator',
                    condition_value     varchar2 PATH '$.condition.value',
                    alert_handler       varchar2 PATH '$.alert.handler',
                    alert_severity      varchar2 PATH '$.alert.severity',
                    alert_throttle      number   PATH '$.alert.throttle'
                )
             ) jt
        WHERE lr.set_name = p_alert_rec.rule_set_name
          AND lr.version  = p_alert_rec.rule_set_version
          AND jt.id      = p_alert_rec.rule_id;

        return l_json_rec;
    end;
    
    -------------------------------------------------------------------------

    FUNCTION readProcessData(p_processId NUMBER, p_action VARCHAR2, p_actionCount PLS_INTEGER, p_masterTabName VARCHAR2, p_monitorTabName VARCHAR2) return t_process_rec
    as
        l_process_rec t_process_rec;
    begin
        -- Da die Tabellennamen variabel sind, nutzen wir EXECUTE IMMEDIATE
        EXECUTE IMMEDIATE 
            'SELECT master.id, master.process_name, master.status,
                master.info, master.process_start, master.process_end,
                master.proc_steps_todo, master.proc_steps_done, monitor.mon_type,
                monitor.action, monitor.context,monitor.start_time, monitor.stop_time,
                monitor.action_count, monitor.used_millis, monitor.avg_millis
             FROM ' || p_masterTabName || ' master
             LEFT JOIN ' || p_monitorTabName || ' monitor
                ON master.id = monitor.process_id
                AND monitor.action = :1
                AND monitor.action_count = :2
             WHERE master.id = :3'
        INTO l_process_rec.process_id, l_process_rec.process_name, l_process_rec.process_status,
            l_process_rec.process_info, l_process_rec.process_start, l_process_rec.process_end,
            l_process_rec.steps_todo, l_process_rec.steps_done,
            l_process_rec.monitor_type, l_process_rec.action_name, l_process_rec.context_name,
            l_process_rec.action_start, l_process_rec.action_stop, l_process_rec.action_count,
            l_process_rec.used_millis,l_process_rec.avg_millis      
        USING p_action, p_actionCount, p_processId;
        
        return l_process_rec;
    end;
    
    -------------------------------------------------------------------------
    
    function prepareMailBodyHtml(p_processRec t_process_rec, p_alertRec t_alert_rec, p_json_rec  t_json_rec) return CLOB
    as
        v_color varchar2(20);
        v_html clob;
    begin
    
        v_color := CASE p_alertRec.alert_severity 
                      WHEN 'CRITICAL' THEN '#e74c3c' -- Rot
                      WHEN 'WARN'     THEN '#f39c12' -- Orange
                      ELSE                 '#3498db' -- Blau
                   END;
                   
        
        v_html := '<html><body style="font-family: Arial, sans-serif; color: #333; line-height: 1.5;">' || utl_tcp.crlf ||
                  -- HEADER
                  '<div style="background-color: ' || v_color || '; color: white; padding: 15px; font-size: 20px; font-weight: bold;">' ||
                  'LILAM Alert: ' || p_alertRec.rule_id || ' (' || p_alertRec.alert_severity || ')</div>' || utl_tcp.crlf ||
                  
                  -- 1. BLOCK: REGEL (JSON)
                  '<h3 style="color: ' || v_color || ';">Regel-Details</h3>' ||
                  '<table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">' ||
                  '<tr><td style="width: 200px; font-weight: bold; border-bottom: 1px solid #ddd; padding: 8px;">Trigger / Action:</td>' ||
                  '<td style="border-bottom: 1px solid #ddd; padding: 8px;">' || p_json_rec.trigger_type || ' / ' || p_json_rec.action || '</td></tr>' ||
                  '<tr><td style="font-weight: bold; border-bottom: 1px solid #ddd; padding: 8px;">Bedingung:</td>' ||
                  '<td style="border-bottom: 1px solid #ddd; padding: 8px;">' || p_json_rec.condition_operator || ' (' || p_json_rec.condition_value || ')</td></tr>' ||
                  '</table>' ||
        
                  -- 2. BLOCK: PROZESS (MASTER)
                  '<h3 style="color: ' || v_color || ';">Prozess-Status</h3>' ||
                  '<table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">' ||
                  '<tr><td style="width: 200px; font-weight: bold; border-bottom: 1px solid #ddd; padding: 8px;">Prozess Name (ID):</td>' ||
                  '<td style="border-bottom: 1px solid #ddd; padding: 8px;">' || p_processRec.process_name || ' (' || p_processRec.process_id || ')</td></tr>' ||
                  '<tr><td style="font-weight: bold; border-bottom: 1px solid #ddd; padding: 8px;">Fortschritt / Status:</td>' ||
                  '<td style="border-bottom: 1px solid #ddd; padding: 8px;">' || p_processRec.steps_done || ' von ' || p_processRec.steps_todo || ' erledigt (Status: ' || p_processRec.process_status || ')</td></tr>' ||
                  '<tr><td style="font-weight: bold; border-bottom: 1px solid #ddd; padding: 8px;">Info:</td>' ||
                  '<td style="border-bottom: 1px solid #ddd; padding: 8px;">' || NVL(p_processRec.process_info, '-') || '</td></tr>' || utl_tcp.crlf ||
                  '</table>';
        
        -- 3. BLOCK: MONITORING (Nur wenn vorhanden via LEFT JOIN)
        IF p_processRec.action_name IS NOT NULL THEN
            v_html := v_html || 
                  '<h3 style="color: ' || v_color || ';">Monitoring / Performance</h3>' ||
                  '<table style="width: 100%; border-collapse: collapse; background-color: #f9f9f9;">' ||
                  '<tr><td style="width: 200px; font-weight: bold; border-bottom: 1px solid #ddd; padding: 8px;">Aktion / Kontext:</td>' ||
                  '<td style="border-bottom: 1px solid #ddd; padding: 8px;">' || p_processRec.action_name || ' | ' || NVL(p_processRec.context_name, 'None') || '</td></tr>' ||
                  '<tr><td style="font-weight: bold; border-bottom: 1px solid #ddd; padding: 8px;">Dauer (Ist / Schnitt):</td>' ||
                  '<td style="border-bottom: 1px solid #ddd; padding: 8px;"><b>' || p_processRec.used_millis || ' ms</b> (Schnitt: ' || p_processRec.avg_millis || ' ms)</td></tr>' ||
                  '<tr><td style="font-weight: bold; border-bottom: 1px solid #ddd; padding: 8px;">Zeitpunkt:</td>' ||
                  '<td style="border-bottom: 1px solid #ddd; padding: 8px;">' || TO_CHAR(p_processRec.action_start, 'HH24:MI:SS.FF3') || '</td></tr>' ||
                  '</table>';
        END IF;
        
        v_html := v_html || '<p style="font-size: 10px; color: #999; margin-top: 30px;">LILAM Engine Alert ID: ' || p_alertRec.alert_id || '</p></body></html>';
        return v_html;

    end;

    FUNCTION prepareMailBodyPlain(p_process_rec t_process_rec, p_alertRec t_alert_rec, l_json_rec  t_json_rec) return CLOB
    as
        l_body CLOB;
        l_duration pls_integer;
    begin
        if p_process_rec.action_name is null then
            l_duration := get_ms_diff(p_process_rec.process_start, p_process_rec.process_end);
        else
            l_duration := p_process_rec.used_millis;
        end if;

        -- 5. Mail-Body zusammenstellen (Beispiel)
        l_body := 'LILAM ALERT REPORT' || CHR(10) ||
                       '-------------------' || CHR(10) ||
                       'Alert ID: ' || p_alertRec.alert_id || CHR(10) ||
                       'Rule:     ' || p_alertRec.rule_id  || ' (' || l_json_rec.condition_operator || ')' || CHR(10) ||
                       'Details:  ' || p_process_rec.process_info || CHR(10) ||
                       'Dauer:    ' || l_duration || ' ms';
                       
        return l_body;
    end;
    
    -------------------------------------------------------------------------
    
    procedure updateAlert(p_alertId number)
    as
    begin
        UPDATE LILAM_ALERTS SET status = 'PROCESSED', processed_at = systimestamp WHERE alert_id = p_alertId;
        
        EXCEPTION
            WHEN OTHERS THEN
            declare
                v_err_msg CLOB := SUBSTR(SQLERRM, 1, 2000); 
            begin
                ROLLBACK;
                UPDATE LILAM_ALERTS 
                SET status = 'ERROR', 
                    -- Jetzt die Variable statt der Funktion nutzen
                    error_message = v_err_msg,
                    processed_at = SYSTIMESTAMP -- Hilfreich für das Debugging
                WHERE alert_id = p_alertId;
                COMMIT;
            end;
    end;
   
    


    -------------------------------------------------------------------------

    PROCEDURE runMailer IS
        -- Variablen für DBMS_ALERT
        v_alert_name    CONSTANT VARCHAR2(30) := 'LILAM_ALERT_MAIL_LOG';
        
        -- Dynamische Daten
        v_info_text     VARCHAR2(2000);
        v_used_millis   NUMBER;
        v_mail_body     CLOB;
        
        l_alert_rec t_alert_rec;
        l_json_rec  t_json_rec;
        l_process_rec t_process_rec;
        
        v_msg_payload varchar2(4000);
        v_status    pls_integer;
        v_count     pls_integer;

    BEGIN
        DBMS_ALERT.REMOVE('v_alert_name');
        DBMS_ALERT.REGISTER(v_alert_name);
        DBMS_OUTPUT.PUT_LINE('LILAM Mail-Log Consumer gestartet...');
    
        LOOP
            -- 1. Warten auf Signal (Timeout nach 60s für Idle-Check)
            DBMS_ALERT.WAITONE(v_alert_name, v_msg_payload, v_status, 5);
    
            IF v_status = 0 THEN
                -- Wir loopen kurz, bis die Daten wirklich sichtbar sind 
                -- oder ein Timeout greift (Retry-Logik statt blindem Sleep)
                FOR i IN 1..5 LOOP
                    -- WICHTIG: Ein neues SELECT braucht oft einen frischen Snapshot
                    SELECT count(*) INTO v_count 
                    FROM LILAM_ALERTS 
                    WHERE handler_type = 'MAIL_LOG' and status = 'PENDING';
                    
                    EXIT WHEN v_count > 0;
                    DBMS_SESSION.SLEEP(0.05); -- Kurzes Warten (50ms) falls Snapshot noch hinkt
                END LOOP;
                
                IF v_count > 0 THEN
                    FOR rec IN (
                        SELECT alert_id, process_id, master_table_name, monitor_table_name, action_name, context_name,
                            action_count, rule_set_name, rule_id, rule_set_version, alert_severity
                        FROM LILAM_ALERTS
                        WHERE handler_type = 'MAIL_LOG' and status in ('PENDING') FOR UPDATE SKIP LOCKED
                    ) LOOP
                        l_alert_rec.alert_id            := rec.alert_id;
                        l_alert_rec.process_id          := rec.process_id; 
                        l_alert_rec.master_table_name   := rec.master_table_name;
                        l_alert_rec.monitor_table_name  := rec.monitor_table_name;
                        l_alert_rec.action_name         := rec.action_name;
                        l_alert_rec.context_name        := rec.context_name;
                        l_alert_rec.action_count        := rec.action_count;
                        l_alert_rec.rule_set_name       := rec.rule_set_name;
                        l_alert_rec.rule_id             := rec.rule_id;
                        l_alert_rec.rule_set_version    := rec.rule_set_version;
                        l_alert_rec.alert_severity      := rec.alert_severity;

                        l_json_rec := readJsonRule(l_alert_rec);
                        l_process_rec := readProcessData(l_alert_rec.process_id, l_alert_rec.action_name, l_alert_rec.action_count, l_alert_rec.master_table_name, l_alert_rec.monitor_table_name);
                        v_mail_body := prepareMailBodyHtml(l_process_rec, l_alert_rec, l_json_rec);
                       
                        send_mail_via_relay('LILAM-ALERT: ' || l_alert_rec.rule_id, v_mail_body, 'dirk@dirk-goldbach.de');
--                        send_mail_via_relay('LILAM-ALERT: ' || l_alert_rec.rule_id, v_mail_body, 'matthias.weinert@t-online.de');
                        
                        updateAlert(rec.alert_id);
                        dbms_session.sleep(10); -- Vermeidung von Spam-Sperre
                    END LOOP;
                    COMMIT; -- Macht die Verarbeitung für andere sichtbar
                END IF;
                
            END IF;
        END LOOP;
    END;

END LILAM_MAILER;
