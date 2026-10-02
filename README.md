# Applied AI & Data Hackathon: Trasforma i tuoi dati in valore concreto

**Evento Ufficiale Google Cloud:** [Applied AI & Data Hackathon - Milano (13 Ottobre 2026)](https://cloud.google.com/events/intl/it-it/applied-ai-data-hackathon-trasforma-i-tuoi-dati-in-valore)  
**Location:** Google Milan, Via Federico Confalonieri 4, Milano  
**Ambiente Target:** Progetto Qwiklabs / Google Cloud (Location: EU)

---

## 📅 Agenda & Mappatura dei Laboratori

| Orario | Sessione | Contenuto / Repository Path |
|---|---|---|
| **09:30 – 10:00** | Registration & Welcome Coffee | Accoglienza partecipanti e setup ambienti Qwiklabs / Cloud Shell |
| **10:00 – 10:30** | **Agentic Data Cloud** (Keynote Frontale) | Visione architetturale: Da Data Warehouse passivo a piattaforma Agentic AI in BigQuery |
| **10:30 – 11:30** | **Hands-on Lab I: Fraud Detection in Retail** | 📂 [`retail_fraud/`](retail_fraud/) — Graph Analytics (GQL) + **TimesFM 3.0** (`AI.DETECT_ANOMALIES` / `AI.FORECAST` multivariato / `AI.EVALUATE`) + GenAI (`AI.GENERATE`, `AI.AGG`, `AI.SCORE`, `AI.SIMILARITY`) |
| **11:30 – 12:30** | **Hands-on Lab II: Unstructured Product Reviews** | 📂 [`product_analytics/`](product_analytics/) — Cost-Optimized Triage (`AI.IF` / `AI.CLASSIFY`) + `AI.SCORE` + Semantic `JOIN ON AI.IF` + `AI.SIMILARITY` + `AI.KEY_DRIVERS` + **TimesFM 3.0** |
| **12:30 – 12:45** | Closing Remarks & Lessons Learned | Q&A, confronto architetture, pattern di produzione e Data Agents |
| **12:45 – 14:00** | Networking Lunch | Pranzo e networking con gli specialisti Google Cloud |

---

## 📊 Presentazioni & Catalogo Funzioni Multi-Verticale

* 📘 **[Catalogo Completo delle 16 Funzionalità & 96 Use Case Verticali (`VERTICAL_USE_CASES_DECK.md`)](VERTICAL_USE_CASES_DECK.md)** — Panoramica generale delle 16 funzionalità (`AI.IF`, `AI.CLASSIFY`, `AI.SCORE`, `AI.GENERATE`, `AI.GENERATE_BOOL`, `AI.AGG`, `AI.SIMILARITY`, `AI.FORECAST` TimesFM 3.0, `AI.DETECT_ANOMALIES` TimesFM 3.0, `AI.EVALUATE` TimesFM 3.0, `AI.KEY_DRIVERS`, `AI.CAUSAL_EFFECT`, `ML.DETECT_CHANGE_POINTS`, `ML.TREND`, `ML.SEASONALITY`, `ML.CORRELATION`, `CREATE PROPERTY GRAPH` & `GQL`) + **16 schede dedicate** con **96 casi d'uso verticali** per **Banking/Finance, Retail, Pharma, Manufacturing, Public Sector e Telco**.
* 🏛️ **[Master Architecture & Deep-Dive Deck dei 2 Lab (`HACKATHON_MASTER_DECK.md`)](HACKATHON_MASTER_DECK.md)**

---

## 🚀 Panoramica dei Due Hands-on Lab

### 1. Lab I — Retail Return-Fraud & Abuse Ring Detection (`retail_fraud/`)
Un e-commerce subisce perdite organizzate sui resi (*wardrobing*, falsi reclami "pacco vuoto/non ricevuto", riciclaggio di punti fedeltà). Singolarmente ogni reso sembra legittimo.
* **TimesFM 3.0 (`AI.DETECT_ANOMALIES`, `AI.FORECAST` Multivariato, `AI.EVALUATE`)**: Rileva istantaneamente (zero-shot, `model => 'TimesFM 3.0'`) il picco anomalo di rimborsi nel Q4 (€17.2k/settimana, $p=0.967$), stima congiuntamente l'esposizione finanziaria e il volume di pacchi resi (`target_cols`) e valida il MAE/MAPE storico in backtesting (`MAPE = 14.49%`).
* **BigQuery Property Graph (GQL)**: Scopre i *Fraud Ring* (`RING-1`, `RING-2`, `RING-3`) analizzando le condivisioni multi-hop di dispositivi, indirizzi di spedizione e carte di pagamento.
* **BigQuery Managed GenAI (`AI.GENERATE_BOOL`, `AI.GENERATE`, `AI.AGG`, `AI.SCORE`, `AI.SIMILARITY`)**: Analizza in background le note testuali degli operatori di supporto, ordina i reclami per minaccia di chargeback (`ORDER BY AI.SCORE`), individua reclami copia-incolla (`AI.SIMILARITY`) e sintetizza il *Modus Operandi* di ciascun ring (`AI.AGG`).
* 📄 **Documentazione & Risorse Lab I:**
  * [README & Guida Rapida](retail_fraud/README.md)
  * [Walkthrough Completo Demo](retail_fraud/WALKTHROUGH.md)
  * [Disegno Architetturale & Slide Deck (Lab I)](retail_fraud/ARCHITECTURE_AND_SLIDES.md)
  * [Nuove Query AI (TimesFM 3.0 + AI.AGG + AI.SCORE + AI.SIMILARITY)](retail_fraud/sql/13_timesfm_and_ai_agg_enhancements.sql)
  * 🌟 **[Bonus Pack: BigQuery Augmented Analytics TVFs (Guide)](retail_fraud/AUGMENTED_ANALYTICS_BONUS_PACK.md)** — Script SQL: [`14_augmented_analytics_bonus_pack.sql`](retail_fraud/sql/14_augmented_analytics_bonus_pack.sql) (`ML.DETECT_CHANGE_POINTS`, `ML.TREND`, `ML.SEASONALITY`, `AI.KEY_DRIVERS`, `AI.CAUSAL_EFFECT`, `ML.CORRELATION`).

---

### 2. Lab II — NovaHome Product Review Intelligence (`product_analytics/`)
NovaHome produce piccoli elettrodomestici. I clienti lasciano migliaia di recensioni non strutturate su Amazon, app e ticket email. L'obiettivo è individuare difetti reali di fabbrica e risalire **al singolo lotto di componenti e al macchinario di stabilimento responsabile**.
* **Cost Optimization & Semantic Ranking (`AI.IF`, `AI.CLASSIFY`, `AI.SCORE`)**: `AI.IF` e `AI.CLASSIFY` (`optimization_mode => 'MINIMIZE_COST'`) addestrano autonomamente un modello distillato leggero sugli embedding per abbattere costi e latenza su grandi volumi (>3.000 righe), mentre `AI.SCORE` ordina le recensioni per urgenza di sicurezza fisica direttamente nell'`ORDER BY`.
* **Quota-Error Resilience (`enrich_new_reviews()`)**: Stored procedure incrementale con loop `REPEAT ... UNTIL` che intercetta errori `retryable` di Vertex AI senza mai ri-fatturare le righe già elaborate.
* **Automated Contribution Analysis (`AI.KEY_DRIVERS`), Semantic Join (`JOIN ON AI.IF`), `AI.SIMILARITY` & `TimesFM 3.0`**: Identifica in 0.5 secondi la combinazione dimensionale colpevole (`heating_element` + fornitore `ThermoCore` + stazione di calibrazione `CAL-02`, con **+1600% di incremento difetti**), unisce semanticamente i bollettini tecnici dei fornitori alle recensioni senza foreign key (`JOIN ... ON AI.IF`), trova reclami simili con `AI.SIMILARITY` e usa **TimesFM 3.0** (`AI.DETECT_ANOMALIES`, `AI.FORECAST` multivariato con covariate, `AI.EVALUATE`) per monitorare e prevedere i difetti giornalieri.
* 📄 **Documentazione & Risorse Lab II:**
  * [README & Hardening di Produzione](product_analytics/README.md)
  * [Walkthrough Completo Demo](product_analytics/DEMO_WALKTHROUGH.md)
  * [Disegno Architetturale & Slide Deck (Lab II)](product_analytics/ARCHITECTURE_AND_SLIDES.md)
  * [Nuove Query AI (AI.KEY_DRIVERS + AI.AGG + Semantic JOIN ON AI.IF + AI.SIMILARITY + TimesFM 3.0)](product_analytics/sql/07_key_drivers_and_ai_agg_enhancements.sql)

---

## 🧪 Checkout, Provisioning, Validazione & Pulizia Ambiente (Qwiklabs / Empty GCP Project)

Il repository include script end-to-end 100% project-agnostic pensati per partire da un **ambiente Qwiklabs / GCP completamente vuoto** direttamente da **Google Cloud Shell**:

* 📥 **1. Checkout del Repository in Cloud Shell:**
  ```bash
  git clone https://github.com/malagoli/applied-ai-2026-10.git
  cd applied-ai-2026-10
  ```
* 🚀 **2. Setup Iniziale Ambiente Studente (Abilita API, Connection `eu.vertex_ai_conn`, IAM e Tabelle Base):**
  ```bash
  chmod +x init_hackathon_student.sh
  ./init_hackathon_student.sh
  ```
* ⚡ **3. Build Completa + Esecuzione Automatica dei Test End-to-End:**
  *(Se vuoi materializzare in automatico tutte le tabelle intermedie di Lab I e Lab II ed eseguire subito la suite di test)*
  ```bash
  chmod +x init_hackathon_student.sh test_workshop.sh
  ./init_hackathon_student.sh --full
  ./test_workshop.sh
  ```
* 🧹 **4. Pulizia Completa delle Risorse Create (Cleanup):**
  ```bash
  chmod +x cleanup_hackathon.sh
  ./cleanup_hackathon.sh -y
  ```
* 📋 **[Piano di Test Completo](TEST_PLAN_WORKSHOP.md)**


