# Ablauf der Kommunikation
Das System basiert auf einem Zwei-Wege-Kommunikationsmodell mittels Datenbank-Alerts (DBMS_ALERT) und einer persistenten Konfigurationstabelle (LILA_CONFIG).

## Phase 1: Statusabfrage (Anwender möchte aktive Sessions sehen)
1. Aktion Anwender (Inst2): Der Anwender ruft die PL/SQL-Funktion LILA.LIST_ACTIVE_SESSIONS auf.
2. Signal an Inst1 (Inst2 -> Inst1): Die Funktion löst den Alert LILA_REQUEST_PERSIST aus und wartet anschließend (mit Timeout) auf eine Antwort (LILA_DATA_PERSISTED).
3. Daten-Persistierung (Inst1): Die aktive LILA-Instanz (Inst1) überwacht zyklisch Alerts. Beim Empfang von LILA_REQUEST_PERSIST schreibt sie ihre im Speicher gehaltene Konfiguration in die Tabelle LILA_CONFIG (mittels PRAGMA AUTONOMOUS_TRANSACTION).
4. Antwort-Signal (Inst1 -> Inst2): Inst1 signalisiert LILA_DATA_PERSISTED und committet.
5. Darstellung (Inst2): Inst2 empfängt das Signal, liest die nun frischen Daten aus LILA_CONFIG und formatiert sie in einem lesbaren Text-CLOB, der dem Anwender präsentiert wird (SELECT LILA.LIST_ACTIVE_SESSIONS FROM DUAL).

## Phase 2: Konfigurationsänderung (Anwender ändert Parameter)
1. Aktion Anwender (Inst2): Der Anwender ruft eine Prozedur auf (z.B. LILA.SET_LOG_LEVEL(p_id, p_level)).
2. Änderung persistieren (Inst2): Die Prozedur schreibt die neuen Parameter in LILA_CONFIG.
3. Signal an Inst1 (Inst2 -> Inst1): Ein Alert LILA_CONFIG_CHANGED wird gesendet und committet.
4. Neuladen (Inst1): Die aktive Instanz (Inst1) empfängt den Alert in ihrem Loop, lädt die Konfiguration aus der Tabelle neu in ihren Speicher und passt das Log-Level an.
