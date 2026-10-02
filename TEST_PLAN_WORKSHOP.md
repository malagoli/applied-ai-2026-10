# Piano di Test & Validazione End-to-End dei Laboratori

**Progetto GCP Target:** `<PROJECT_ID>` (Project Number: `<PROJECT_NUMBER>`)  
**Ambiente Esecuzione:** Google Cloud Shell / Qwiklabs  
**Location (Multi-Region):** `EU` (`europe`)  
**Connection Vertex AI:** `eu.vertex_ai_conn` (`CLOUD_RESOURCE`)

---

## 🎯 1. Obiettivo del Piano di Test

Questo documento definisce la procedura di verifica tecnica end-to-end per certificare che entrambi i laboratori dell'evento **[Applied AI & Data Hackathon (Milano, 13 Ottobre 2026)](https://cloud.google.com/events/intl/it-it/applied-ai-data-hackathon-trasforma-i-tuoi-dati-in-valore)** funzionino senza errori, rispettando i vincoli di latenza, quota e configurazione di un progetto Google Cloud / Qwiklabs.

Il piano copre:
1. **Infrastruttura & Permessi IAM** (Connessione Cloud Resource e Service Account Delegation).
2. **Lab I (`retail_fraud`)**: Setup dati, Property Graph (GQL), Pipeline Asincrona GenAI e le nuove integrazioni **TimesFM (`AI.DETECT_ANOMALIES`, `AI.FORECAST`)** e **`AI.AGG`**.
3. **Lab II (`mfg_quality_demo`)**: Setup dati ERP/BOM, Triage Cost-Optimized (`MINIMIZE_COST`), Stored Procedure con Retry Loop, Root-Cause Analysis e le nuove integrazioni **`AI.KEY_DRIVERS`** e **`AI.AGG`**.

---

## 🧪 2. Matrice dei Test & Benchmark Rilevati Live su `<PROJECT_ID>`

Tutti i test seguenti sono stati eseguiti e verificati end-to-end su un progetto Google Cloud pulito:

| ID Test | Modulo | Componente / Funzione BigQuery | Criterio di Successo (Expected Output) | Latenza Rilevata | Stato |
|---|---|---|---|---|---|
| **T-00** | Infra | `bq show --connection eu.vertex_ai_conn` | Connection `CLOUD_RESOURCE` attiva in `EU` con SA `bqcx-<PROJECT_NUMBER>-...@...` | < 1s | ✅ PASS |
| **T-01** | Lab I | Verifica Dataset & Tabelle (`retail_fraud`) | 19 tabelle/viste presenti (`orders`: 50k, `returns`: 4.417, `suspicious_rings`: 3) | < 1s | ✅ PASS |
| **T-02** | Lab I | Property Graph (`GRAPH_TABLE` su `fraud_graph`) | Query GQL restituisce esattamente i 3 ring (`RING-1`, `RING-2`, `RING-3`) con 0 falsi positivi | 1.8s | ✅ PASS |
| **T-03** | Lab I | **TimesFM 3.0 Anomaly Detection** (`AI.DETECT_ANOMALIES`) | Rileva zero-shot il picco del `2025-11-16` (€17.205,16 vs max €14.432, **prob = 0.973**) | 3.1s | ✅ PASS |
| **T-04** | Lab I | **TimesFM 3.0 Forecasting & Eval** (`AI.FORECAST` + `AI.EVALUATE`) | Forecast multivariato (`target_cols`) a 8 settimane + backtest MAPE = **14.49%** | 2.4s | ✅ PASS |
| **T-05** | Lab I | **Semantic Aggregation** (`AI.AGG` su `suspicious_rings`) | Sintetizza il Modus Operandi in 2 frasi per ciascun ring direttamente in `GROUP BY ring_id` | 4.2s | ✅ PASS |
| **T-06** | Lab II | Verifica Dataset & Tabelle (`mfg_quality_demo`) | 8 tabelle/viste presenti (`product_reviews`: 60, `review_insights`: 60, `component_lots`: 13) | < 1s | ✅ PASS |
| **T-07** | Lab II | Cost-Optimized Triage (`AI.IF` + `AI.CLASSIFY` con `MINIMIZE_COST`) | Esecuzione su 10 recensioni; identifica `is_defect_report = TRUE` e `heating` sulle rotture | 3.5s | ✅ PASS |
| **T-08** | Lab II | Quota-Resilient Pipeline (`CALL enrich_new_reviews()`) | Esecuzione idempotente (`0` righe rielaborate se già presenti; `ai_status` vuoto = 100% clean) | 2.1s | ✅ PASS |
| **T-09** | Lab II | Root-Cause BOM Analysis (`v_component_lot_defect_rates`) | Isola il lotto `HE-4471` (**77% defect rate**) e la stazione `CAL-02` (manutenzione scaduta `2025-01-17`) | 1.2s | ✅ PASS |
| **T-10** | Lab II | **Automated Contribution Analysis** (`AI.KEY_DRIVERS`) | Identifica in zero-shot il driver `heating_element + ThermoCore` con **+1600% relative difference** | **0.5s** | ✅ PASS |
| **T-11** | Lab II | **TimesFM 3.0 Multivariate Forecast** (`AI.FORECAST` + `AI.DETECT_ANOMALIES`) | Prevede congiuntamente `defect_reports` e `severe_defects` con covariata `total_reviews` (`TimesFM 3.0`) | 2.5s | ✅ PASS |

---

## 🛠️ 3. Analisi Tecnica & Architettura dei Laboratori

Dall'analisi tecnica e dai benchmark end-to-end emergono **4 pilastri operativi fondamentali**:

### A. Bootstrap Automatico per Ambienti Qwiklabs Vuoti
* **Stato Attuale:** Tutti gli script SQL sono 100% project-agnostic (`location = 'EU'` nei `CREATE SCHEMA` e connection `eu.vertex_ai_conn`).
* **Setup Qwiklabs da Zero:** Ogni partecipante dispone di un ambiente Qwiklabs / GCP vuoto dedicato. Eseguendo `./init_hackathon_student.sh` all'inizio del lab:
  1. Vengono abilitate automaticamente le API `bigquery.googleapis.com`, `bigqueryconnection.googleapis.com` e `aiplatform.googleapis.com`.
  2. Viene creata la Cloud Resource Connection `eu.vertex_ai_conn` e vengono assegnati i permessi IAM (`roles/aiplatform.user`) al relativo Service Account.
  3. Vengono popolati i dataset e le tabelle seed di partenza per Lab I (`retail_fraud`) e Lab II (`mfg_quality_demo`).

### B. Integrazione TimesFM 3.0 in Entrambi i Laboratori (Univariato & Multivariato)
* **In Lab I (`retail_fraud`) $\rightarrow$ Implementato in `sql/13_timesfm_and_ai_agg_enhancements.sql`**:
  * Il dataset ha **549 giorni di storico** (78 settimane). Con `model => 'TimesFM 3.0'`, `AI.DETECT_ANOMALIES` cattura il picco criminale di Novembre 2025 al 97.3% di probabilità, `AI.FORECAST` supporta sia il forecast univariato sia il **forecast multivariato (`target_cols => ['weekly_refund_eur', 'return_count']`)**, e `AI.EVALUATE` certifica un **MAPE del 14.49%** (migliore del 16.41% di TimesFM 2.5).
* **In Lab II (`mfg_quality_demo`) $\rightarrow$ Implementato in `sql/07_key_drivers_and_ai_agg_enhancements.sql` (`7e`, `7f`, `7g`)**:
  * Aggregando la serie storica giornaliera continua su tutti i 46 giorni di calendario (1 Luglio – 15 Agosto 2025), **TimesFM 3.0** intercetta con `AI.DETECT_ANOMALIES` l'impennata di difetti dopo l'ingresso del lotto `HE-4471`, esegue il **forecast multivariato (`target_cols => ['defect_reports', 'severe_defects']`, `past_covariate_cols => ['total_reviews']`)** e certifica l'errore con `AI.EVALUATE` (`MAE = 0.72` recensioni/giorno), completando l'analisi multidimensionale di `AI.KEY_DRIVERS`.

### C. Allineamento Sintattico Server-less tra Lab I e Lab II
* **Implementato in Lab I:** Nel file `sql/08_notes_extraction.sql`, Lab I utilizza il pattern moderno **Serverless** `AI.GENERATE(..., connection_id => 'eu.vertex_ai_conn', endpoint => 'gemini-3.8-flash', output_schema => '...')` con campionamento deterministico `_sampled_returns`.

### D. Integrazione Tema Keynote: "Agentic Data Cloud"
* Poiché il Keynote delle 10:00 è intitolato **"Agentic Data Cloud"**, suggeriamo di chiudere entrambi i lab mostrando **BigQuery Data Canvas & Gemini Conversational Analytics**:
  * Aprire Data Canvas su `v_component_lot_defect_rates` (Lab II) e `fraud_dashboard` (Lab I) e chiedere in chat: *"Quali sono i 3 ring con maggiore esposizione e quale azione immediata consigli per il Ring 2?"*.

---

## 🚀 4. Esecuzione Automatica della Suite di Test (`test_workshop.sh`)

Per rieseguire da zero l'intero provisioning (inclusa la materializzazione di tutte le tabelle dei lab) e la validazione completa su un progetto vuoto:

```bash
chmod +x init_hackathon_student.sh test_workshop.sh
./init_hackathon_student.sh --full
./test_workshop.sh
```

---

## 🧹 5. Pulizia Completa delle Risorse (`cleanup_hackathon.sh`)

Per rimuovere in un singolo comando tutti i dataset BigQuery (`retail_fraud`, `mfg_quality_demo`), i modelli BQML/Remoti, i Property Graph, la Cloud Resource Connection (`eu.vertex_ai_conn`) e il bucket Cloud Storage (`gs://<PROJECT_ID>-fraud-evidence`):

```bash
chmod +x cleanup_hackathon.sh
./cleanup_hackathon.sh -y
```

