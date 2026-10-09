# NovaHome Product Review Intelligence — Lab II

**Hackathon Slot:** 11:30 AM – 12:30 PM CEST (Hands-on Lab II)  
**Verticale:** Manufacturing & Consumer Appliances  
**Dataset BigQuery:** `mfg_quality_demo` (Location: **US**)  
**Connection Vertex AI:** `us.vertex_ai_conn` (Modello: `gemini-3.8-flash` + `TimesFM 3.0`)

---

## 🎯 Obiettivo del Laboratorio

**NovaHome Appliances** produce piccoli elettrodomestici (bollitori elettrici, macchine da caffè, frullatori, tostapane e friggitrici ad aria). I clienti lasciano migliaia di recensioni in testo libero su Amazon, siti retail, app mobile e ticket email.

Il team di Quality Engineering deve rispondere a due domande critiche **senza leggere manualmente migliaia di recensioni**:
1. I reclami dei clienti indicano un **reale difetto hardware di fabbricazione** (distinguendolo dal rumore su spedizioni, imballaggi, prezzi o preferenze personali)?
2. Quale **specifico lotto di componenti (`lot_id`)** e quale **macchinario di stabilimento (`machine_id`)** sono responsabili del guasto sul campo?

Questo laboratorio dimostra come costruire una pipeline **Production-Grade AI in SQL** in BigQuery combinando:
1. **Cost Optimization & Model Distillation (`optimization_mode => 'MINIMIZE_COST'`)**: le funzioni `AI.IF` e `AI.CLASSIFY` addestrano autonomamente un modello distillato leggero sugli embedding per abbattere costi e latenza su grandi volumi (>3.000 righe).
2. **Estrazione Strutturata Tipizzata (`AI.GENERATE` con `output_schema`)**: trasforma ogni recensione in uno `STRUCT` SQL fortemente tipizzato (`sentiment`, `is_defect_report`, `defect_category`, `affected_component`, `severity`, `summary`).
3. **Quota-Error Resilience (`enrich_new_reviews()`)**: stored procedure asincrona incrementale con ciclo `REPEAT ... UNTIL` che intercetta e riprova automaticamente solo le righe fallite per rate-limit (`A retryable error occurred`) senza mai ri-fatturare le righe già analizzate.
4. **Root-Cause Tracing sulla Distinta Base (BOM) & `AI.KEY_DRIVERS`**: incrocia le ipotesi estratte dall'AI con le tabelle ERP di fabbrica (`batch_components`, `component_lots`, `machines`) e usa `AI.KEY_DRIVERS` per isolare in 0.5 secondi il lotto **`HE-4471`** e la stazione di calibrazione **`CAL-02`** (+1600% di incidenza difetti).
5. **TimesFM 3.0 (`AI.DETECT_ANOMALIES`, `AI.FORECAST` Multivariato & `AI.EVALUATE`)**: intercetta in zero-shot i picchi giornalieri di segnalazioni difettose (`p = 1.000`) e prevede congiuntamente difetti e severità media (`target_cols => ['defect_count', 'avg_severity']`) con covariate (`past_covariate_cols`).
6. **Multi-Row Semantic Aggregation (`AI.AGG`) & Executive Briefing**: sintetizza bollettini tecnici R&D per ogni SKU direttamente dentro `GROUP BY sku` e redige il piano d'azione esecutivo.

---


## 📂 Struttura degli Script SQL (`sql/`)

Tutti gli script sono idempotenti e progettati per essere eseguiti in sequenza in un ambiente Qwiklabs vuoto:

| Script | Fase | Funzionalità Principale |
|---|---|---|
| [`01_setup_dataset_and_data.sql`](sql/01_setup_dataset_and_data.sql) | Setup Dati | Crea lo schema `mfg_quality_demo` (`US`), le tabelle ERP/BOM (`products`, `machines`, `component_lots`, `production_batches`, `batch_components`) e 60 recensioni in `product_reviews`. |
| [`02_quick_triage.sql`](sql/02_quick_triage.sql) | Cost-Optimized Triage & Ranking | Triage ad-hoc con `AI.IF` e `AI.CLASSIFY` (`optimization_mode => 'MINIMIZE_COST'`) + `AI.GENERATE_INT` + Ranking semantico `ORDER BY AI.SCORE(...)`. |
| [`03_async_enrichment_pipeline.sql`](sql/03_async_enrichment_pipeline.sql) | Pipeline Async | Crea la tabella `review_insights` e la stored procedure `enrich_new_reviews()` con retry loop `REPEAT ... UNTIL`. |
| [`04_root_cause_analysis.sql`](sql/04_root_cause_analysis.sql) | Root-Cause BOM | Crea la vista `v_component_lot_defect_rates` e isola il lotto `HE-4471` (77% difetti) e la macchina `CAL-02`. |
| [`05_executive_summary.sql`](sql/05_executive_summary.sql) | Executive Brief | Passa le evidenze numeriche e lo storico manutenzioni a `AI.GENERATE` per generare il piano di recall/manutenzione. |
| [`06_simulate_new_reviews.sql`](sql/06_simulate_new_reviews.sql) | Live Demo | Inserisce 3 nuove recensioni per dimostrare l'elaborazione incrementale di `CALL enrich_new_reviews()`. |
| [`07_key_drivers_and_ai_agg_enhancements.sql`](sql/07_key_drivers_and_ai_agg_enhancements.sql) | **Novità AI & TimesFM 3.0** | **`AI.KEY_DRIVERS`** + **`AI.AGG`** + **Semantic `JOIN ON AI.IF`** + **`AI.SIMILARITY`** + **`TimesFM 3.0`** (`AI.DETECT_ANOMALIES`, `AI.FORECAST` multivariato `target_cols`, `AI.EVALUATE`). |

---

## ⚡ Quickstart & Walkthrough

Per eseguire il laboratorio passo-passo da un ambiente Qwiklabs vuoto, segui **[DEMO_WALKTHROUGH.md](DEMO_WALKTHROUGH.md)**.
