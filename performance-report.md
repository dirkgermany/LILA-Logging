# 📊 LILAM Performance & Stress-Test Report

## 1. Ausstattung der Hardware (Host)
*   **Modell:** [Dein Notebook Modell, z.B. Dell XPS 15]
*   **Prozessor (CPU):** [z.B. Intel i7-12700H] ([X] Kerne / [X] Threads)
*   **Arbeitsspeicher (RAM):** [X] GB DDR4/DDR5
*   **Festplatte (Storage):** [X] GB NVMe SSD (Basis für High-Speed I/O)

## 2. Setup Software-Stack
*   **Host-OS:** [z.B. Windows 11 Pro]
*   **Virtualisierung:** Oracle VM VirtualBox [Version, z.B. 7.0]
*   **Gast-OS:** Oracle Linux [Version, z.B. 8.8]
*   **Datenbank:** **Oracle Database 21c Free (XE)**

## 3. Ressourcen-Zuweisung (VM an DB)
*   **vCPU:** [X] Kerne (In VirtualBox zugewiesen)
*   **VM RAM:** [X] GB (Gesamtspeicher der virtuellen Maschine)
*   **SGA (System Global Area):** [X] MB (Shared Memory für Pipes und Buffer)
*   **PGA (Process Global Area):** **2,0 GB** (Kritisches Limit für komplexe Joins / ORA-04036)

## 4. Datenbank-Limits (21c Free Edition)
*   **User Data:** Max. 12 GB (während des Tests ca. 800 - 1.500 MB belegt)
*   **RAM (SGA/PGA):** Max. 2 GB (Hardware-Limit der Free Edition, unabhängig von VM-Zuweisung)
*   **CPU:** Verwendet max. 2 Threads (Engpass bei parallelen Workern)

## 5. Ressourcenverbrauch pro Server (Worker)
Unter Volllast (ca. 1.700 - 2.200 EPS) verbraucht ein einzelner Worker-Prozess:
*   **Pipe-Speicher:** Minimaler SGA-Footprint (Nachrichten werden sofort konsumiert).
*   **PGA:** Effizienter Verbrauch durch `FORALL` Bulk-Processing.
*   **CPU-Last:** Permanent am Limit des zugewiesenen Threads (`resmgr:cpu quantum` bei Überlast).
*   **Log-Traffic:** Generiert massiv Redo-Logs (3 Gruppen à 200 MB, Wechsel alle ~1-2 Min).

## 6. Durchsatz & Testszenario
Das Szenario simulierte eine extreme Mischlast (Mixed Workload).

### Setup des Szenarios
*   **Paar 1 (High Performance):** 1 Produzent + 1 Worker. Loop mit **4.000.000 Aufrufen**. 
    *   *Aktion:* API-Call + Bulk-Schreiben in 3 Tabellen (`REMOTE_LOG`, `REMOTE_LOG_MON`, `LILAM_ALERTS`).
*   **Paar 2 (Latenz-Messung):** 1 Produzent + 1 Worker. **100.000 Aufrufe**.
    *   *Aktion:* API-Call + Schreiben in 2 Tabellen (`REMOTE_LOG`, `REMOTE_LOG_MON`) + **Einzel-Inserts** in `LATENZ_TEST` (indiziert).

### Messergebnisse (Durchsatz)


| Paar | Verarbeitungs-Modus | Durchsatz (EPS) | Status |
| :--- | :--- | :--- | :--- |
| **Paar 1 (Bulk)** | `FORALL` (1000er Batch) | **~1.300 - 1.900** | Stabil über 4 Mio. Datensätze |
| **Paar 2 (Latenz)** | `Row-by-Row` | **~460 - 800** | Einbruch bei ~450k (I/O Sättigung) |

*Hinweis: Der Durchsatz von Paar 2 stieg nach Umstellung auf 1.000er Commits um den **Faktor 3** an.*

## 7. Darstellung der Latenz (Echtzeit-Fähigkeit)
Gemessen durch den Zeitstempel-Vergleich zwischen Producer (`LATENZ_TEST`) und Engine-Eingang (`REMOTE_LOG_MON`).


| Metrik | Wert (Clean Run 100k) | Wert (Dauerlast 4M) |
| :--- | :--- | :--- |
| **Durchschnitt (Avg)** | **4,14 ms** | ~47.000 ms (Stau-Phase) |
| **Maximum (Max)** | 2.037,96 ms | > 60.000 ms |
| **Jitter (StdDev)** | 510,19 | Extrem hoch (CPU Sättigung) |

### Fazit der Latenzmessung
Die LILAM-Engine ist im Kern **hochperformant (4,14 ms Basis-Latenz)**. Die Latenzsteigerung unter Dauerlast ist ein rein physikalischer Effekt: Das Notebook-I/O und das 2-Thread-Limit der 21c Free Edition führen bei Überlastung zur Stau-Bildung in den Pipes. Durch die implementierte **Flusssteuerung (Backpressure/Handshake)** blieb das Gesamtsystem jedoch zu jeder Zeit konsistent und stabil.
