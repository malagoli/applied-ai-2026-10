# Retail Return-Fraud & Abuse Ring Detection — Lab I

**Hackathon Slot:** 10:30 AM – 11:30 AM CEST (Hands-on Lab I)  
**Verticale:** Retail & E-Commerce  
**Dataset BigQuery:** `retail_fraud` (Location: **EU**)  
**Connection Vertex AI:** `eu.vertex_ai_conn` (Modello: `gemini-3.8-flash` + `TimesFM 3.0`)

---

## 🎯 Obiettivo del Laboratorio

Gli e-commerce moderni subiscono perdite significative a causa di **frodi organizzate sui resi** (*Return Abuse Rings*):
1. **Wardrobing (Ring A - Account `9001–9006`)**: acquisto di capi d'abbigliamento, utilizzo e restituzione sistematica (~68% return rate) con cartellini riattaccati.
2. **Loyalty Points Cycling (Ring B - Account `9101–9104`)**: acquisto, riscatto immediato dei punti fedeltà in gift card/sconti entro 48 ore, e successivo reso della merce.
3. **False "Item Not Received" / Empty Box Claims (Ring C - Account `9201–9205`)**: reclami seriali di mancata consegna su elettronica ad alto valore (€400+), pagati con lo stesso metodo di pagamento.

Analizzando le transazioni singolarmente, ogni reso appare legittimo. Questo laboratorio dimostra come combinare **4 pilastri dell'Agentic Data Cloud in BigQuery** per smascherare i ring criminali:

1. **TimesFM 3.0 (`AI.DETECT_ANOMALIES`, `AI.FORECAST` Multivariato & `AI.EVALUATE`)** per intercettare i picchi macroeconomici di rimborso, proiettare congiuntamente esposizione in € e volumi pacchi (`target_cols`) e validare il MAPE senza addestrare modelli ML.
2. **BigQuery Property Graph (`CREATE PROPERTY GRAPH` & GQL)** per scoprire le reti occulte di account che condividono Device ID, Indirizzi di Spedizione o Metodi di Pagamento.
3. **Generative AI in SQL (`AI.GENERATE_BOOL`, `AI.GENERATE_TABLE`, `AI.GENERATE`)** in modalità **asincrona (batch incrementale schedulato ogni 15 minuti)** per estrarre segnali strutturati dalle note testuali degli operatori di customer care.
4. **Aggregazione Semantica (`AI.AGG`)** per generare automaticamente i dossier investigativi (*Case Briefs*) per ciascun ring.

---

## 🏛️ Architettura & Slide Deck

👉 Consulta il documento dedicato **[ARCHITECTURE_AND_SLIDES.md](ARCHITECTURE_AND_SLIDES.md)** per:
* Diagramma architetturale End-to-End (Mermaid).
* Set completo di **10 Slide** per la presentazione in aula durante l'Hackathon.

---

## 📂 Struttura degli Script SQL (`sql/`)

Tutti gli script sono idempotenti e progettati per essere eseguiti in sequenza:

| Script | Fase | Funzionalità Principale |
|---|---|---|
| [`01_customers_products.sql`](sql/01_customers_products.sql) | Setup Dati | Crea i 5.000 clienti e 500 prodotti (con descrizioni grezze per l'enrichment). |
| [`02_orders_returns_loyalty.sql`](sql/02_orders_returns_loyalty.sql) | Setup Dati | Genera 50.000 ordini, ~4.400 resi con note testuali e i 3 Fraud Ring (`_ground_truth_rings`). |
| [`03_property_graph.sql`](sql/03_property_graph.sql) | Graph DDL | Crea il grafo `retail_fraud.fraud_graph` (Nodi: `Customer`, `Device`, `Address`, `PaymentMethod`). |
| [`04_ring_detection.sql`](sql/04_ring_detection.sql) | Graph + SQL | Esegue query GQL (`GRAPH_TABLE`) + filtri comportamentali per materializzare `suspicious_rings`. |
| [`05_graph_exploration_queries.sql`](sql/05_graph_exploration_queries.sql) | Esplorazione | Query interattive GQL per device condivisi, multi-hop e loyalty cycling. |
| [`06_remote_model.sql`](sql/06_remote_model.sql) | Setup AI | Crea il remote model `gemini_model` su `gemini-3.8-flash`. |
| [`07_async_scoring_batch.sql`](sql/07_async_scoring_batch.sql) | Pipeline Async | Batch incrementale (`LIMIT 500`) con `AI.GENERATE_BOOL` per classificare i nuovi resi. |
| [`08_notes_extraction.sql`](sql/08_notes_extraction.sql) | Estrazione | Usa `AI.GENERATE_TABLE` con schema tipizzato sulle note degli agenti. |
| [`09_case_summaries.sql`](sql/09_case_summaries.sql) | Sintesi | Genera un dossier narrativo per ciascun ring combinando prove grafo + testo. |
| [`10_catalog_enrichment.sql`](sql/10_catalog_enrichment.sql) | Bonus Retail | Arricchisce le descrizioni legacy del catalogo prodotti con `AI.GENERATE`. |
| [`11_fraud_dashboard.sql`](sql/11_fraud_dashboard.sql) | Dashboard | Crea la vista unificata `fraud_dashboard` ordinata per esposizione finanziaria (€ a rischio). |
| [`12_simulate_new_returns.sql`](sql/12_simulate_new_returns.sql) | Live Demo | Inserisce 10 nuovi resi sospetti per testare il recupero incrementale della pipeline. |
| [`13_timesfm_and_ai_agg_enhancements.sql`](sql/13_timesfm_and_ai_agg_enhancements.sql) | **Novità AI** | **TimesFM 3.0** (`AI.DETECT_ANOMALIES`, `AI.FORECAST` univariato/multivariato `target_cols`, `AI.EVALUATE`) + **`AI.AGG`**, **`AI.SCORE`** e **`AI.SIMILARITY`**. |
| [`14_augmented_analytics_bonus_pack.sql`](sql/14_augmented_analytics_bonus_pack.sql) | **Bonus Pack TVF** | **Augmented Analytics TVFs** (`ML.DETECT_CHANGE_POINTS`, `ML.TREND`, `ML.SEASONALITY`, `AI.KEY_DRIVERS`, `AI.CAUSAL_EFFECT`, `ML.CORRELATION`). Vedi [AUGMENTED_ANALYTICS_BONUS_PACK.md](AUGMENTED_ANALYTICS_BONUS_PACK.md). |

---

## ⚡ Quickstart & Esecuzione

Per eseguire il walkthrough passo-passo in console o via CLI, segui **[WALKTHROUGH.md](WALKTHROUGH.md)**.

Per testare le nuove funzionalità **TimesFM 3.0** e **AI.AGG**:
```bash
bq query --location=EU --use_legacy_sql=false < sql/13_timesfm_and_ai_agg_enhancements.sql
```
