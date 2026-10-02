# Walkthrough Passo-Passo (Lab I) — Retail Return-Fraud & Abuse Ring Detection

**Ambiente Target:** Progetto Qwiklabs / GCP vuoto (Location: **EU**)  
**Dataset BigQuery:** `retail_fraud`  
**Connection Vertex AI:** `eu.vertex_ai_conn` (`gemini-3.8-flash` + `TimesFM 3.0`)

---

## 🎯 Scenario di Business

Un retailer e-commerce subisce perdite rilevanti a causa di **frodi organizzate sui resi** (*Return Abuse Rings*):
1. **Wardrobing (Ring A — Clienti `9001–9006`):** acquisto di capi d'abbigliamento, utilizzo per un evento e restituzione sistematica (~68% return rate) con cartellini riattaccati.
2. **Loyalty Points Cycling (Ring B — Clienti `9101–9104`):** acquisto, riscatto immediato dei punti fedeltà in gift card/buoni sconto entro 48 ore, e successivo reso della merce.
3. **False "Item Not Received" / Empty Box Claims (Ring C — Clienti `9201–9205`):** reclami seriali di mancata consegna o pacco vuoto su elettronica ad alto valore (€400+), pagati con lo stesso metodo di pagamento.

Osservando le transazioni singolarmente, ogni reso appare legittimo. La frode emerge solo quando si collegano gli account tramite le **entità fisiche/digitali condivise** (dispositivi, indirizzi di spedizione, metodi di pagamento) e si analizzano su larga scala le **motivazioni di reso e le note in testo libero degli operatori**.

| Ring Seeded | Account Membri | Schema di Frode | Entità Condivise |
|---|---|---|---|
| **Ring A** | `9001–9006` | Wardrobing (~68% return rate) | Device `999001`/`999002`, Indirizzo `888001` |
| **Ring B** | `9101–9104` | Riciclaggio punti fedeltà (Loyalty Cycling) | Indirizzo `888101` |
| **Ring C** | `9201–9205` | Falsi reclami "Pacco non ricevuto / vuoto" su elettronica | Metodo di pagamento `777201` |

Il dataset sintetico contiene **~5.000 clienti**, **50.000 ordini**, **~4.400 resi** e include anche **50 clienti alto-rendenti legittimi** (`4001–4050`, ad es. chi ordina più taglie per provarle) più condivisioni domestiche fisiologiche come rumore realistico.

---

## 🛠️ Step 0 — Setup Iniziale in Ambiente Qwiklabs Vuoto

Apri **Google Cloud Shell** nel tuo ambiente Qwiklabs vuoto.

### Opzione A (Consigliata): Setup Automatico con Script di Bootstrap
Clona il repository ed esegui lo script di inizializzazione automatica (abilita le API, crea la Cloud Resource Connection `eu.vertex_ai_conn`, assegna i permessi IAM al Service Account e carica le tabelle base):

```bash
git clone https://github.com/malagoli/applied-ai-2026-10.git
cd applied-ai-2026-10
chmod +x init_hackathon_student.sh
./init_hackathon_student.sh
```

### Opzione B: Setup Manuale Passo-Passo (Alternativa didattica)
Se preferisci eseguire manualmente ogni singolo comando infrastrutturale nel tuo progetto Qwiklabs vuoto:

```bash
# 1. Imposta il progetto attivo e abilita le API necessarie (~10s)
export PROJECT_ID="$(gcloud config get-value project)"
gcloud config set project "${PROJECT_ID}"
gcloud services enable \
  bigquery.googleapis.com \
  bigqueryconnection.googleapis.com \
  aiplatform.googleapis.com

# 2. Crea la Cloud Resource Connection per Vertex AI in EU (~5s)
bq mk --connection \
  --location=EU \
  --project_id="${PROJECT_ID}" \
  --connection_type=CLOUD_RESOURCE \
  vertex_ai_conn

# 3. Assegna il ruolo Vertex AI User al Service Account della connessione (~15s)
SA_EMAIL=$(bq show --format=json --connection "${PROJECT_ID}.EU.vertex_ai_conn" | python3 -c "import sys, json; print(json.load(sys.stdin)['cloudResource']['serviceAccountId'])")
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/aiplatform.user" \
  --condition=None
sleep 15
```

> **💡 Nota per l'uso da Console Web BigQuery (Qwiklabs Standard Edition):**
> * Tutti gli script creano il dataset `retail_fraud` forzando esplicitamente `OPTIONS (location = 'EU')`. Se esegui query ad-hoc nella Console Web di BigQuery, assicurati che la processing location sia impostata su **`EU`** (o lascia che BigQuery la rilevi dal dataset `retail_fraud`).
> * L'operatore GQL `GRAPH_TABLE` richiede una reservation BigQuery Enterprise Edition; sugli ambienti Qwiklabs On-Demand (Standard Edition), gli script [`sql/04_ring_detection.sql`](sql/04_ring_detection.sql) e [`sql/05_graph_exploration_queries.sql`](sql/05_graph_exploration_queries.sql) includono già un blocco `BEGIN ... EXCEPTION WHEN ERROR` che effettua il **fallback automatico trasparente in puro SQL** producendo lo stesso identico risultato in ~2 secondi.

---

## 🚀 Guida Operativa Passo-Passo

Entra nella cartella del **Lab I**:

```bash
cd retail_fraud
```

Puoi eseguire ogni passo sia da terminale Cloud Shell (`bq query --location=EU --use_legacy_sql=false < sql/...`) sia copiando il contenuto dei file `.sql` nell'editor di **BigQuery Studio**.

---

### Step 1 — Creazione Dataset & Esplorazione Dati Grezzi (`sql/01` e `sql/02`)

Se non hai già usato `./init_hackathon_student.sh`, popola lo schema `retail_fraud` con i dati transazionali:

```bash
bq query --location=EU --use_legacy_sql=false < sql/01_customers_products.sql
bq query --location=EU --use_legacy_sql=false < sql/02_orders_returns_loyalty.sql
```

Ispeziona ora la tabella dei resi in BigQuery:

```sql
SELECT return_id, order_id, customer_id, return_date, refund_amount,
       return_reason_text, agent_notes
FROM `retail_fraud.returns`
ORDER BY return_id DESC
LIMIT 20;
```

**Cosa osservare:** guardando una singola riga, ogni reso sembra plausibile. I segnali chiave sono nascosti nelle note testuali (`return_reason_text` e `agent_notes`) e nelle connessioni invisibili tra account diversi.

---

### Step 2 — Allerta Macroeconomica & Forecasting Multivariato con TimesFM 3.0 (`sql/13`)

Prima ancora di indagare sui singoli clienti, il team Finance o Antifrode nota un'anomalia macroscopica nei rimborsi settimanali usando il foundation model **TimesFM 3.0** (`model => 'TimesFM 3.0'`) di BigQuery (`AI.DETECT_ANOMALIES`, `AI.FORECAST` ed `AI.EVALUATE` — *zero-shot*, senza alcun `CREATE MODEL`):

```bash
bq query --location=EU --use_legacy_sql=false < sql/13_timesfm_and_ai_agg_enhancements.sql
```

Puoi eseguire direttamente in Console la query di **Anomaly Detection (13a)** con `TimesFM 3.0`:

```sql
WITH weekly_returns AS (
  SELECT DATE_TRUNC(return_date, WEEK) AS week_start,
         ROUND(SUM(refund_amount), 2) AS weekly_refund_eur
  FROM `retail_fraud.returns`
  GROUP BY 1
)
SELECT time_series_timestamp AS week_start,
       time_series_data AS actual_eur,
       ROUND(upper_bound, 0) AS expected_max_eur,
       ROUND(anomaly_probability, 3) AS prob
FROM AI.DETECT_ANOMALIES(
  (SELECT * FROM weekly_returns WHERE week_start < '2025-09-01'),
  (SELECT * FROM weekly_returns WHERE week_start BETWEEN '2025-09-01' AND '2026-01-31'),
  data_col => 'weekly_refund_eur',
  timestamp_col => 'week_start',
  model => 'TimesFM 3.0',
  anomaly_prob_threshold => 0.80
)
WHERE is_anomaly = TRUE
ORDER BY week_start;
```

**Risultato atteso:** TimesFM 3.0 intercetta immediatamente il picco della settimana **`2025-11-16`** (**€17.205** contro un massimo atteso di €14.811, probabilità di anomalia **`0.967`**), che coincide esattamente con l'entrata in azione del **Ring C** sull'elettronica.
* **Forecasting Univariato & Multivariato (`13b` & `13b-bis` - `AI.FORECAST` con `TimesFM 3.0`):** proietta oltre **€100.000** di esposizione nelle 8 settimane successive e mostra la novità esclusiva di **TimesFM 3.0 (`target_cols => ['weekly_refund_eur', 'return_count']`)** per prevedere simultaneamente sia l'esposizione in € sia il volume di pacchi resi.
* **Backtesting Zero-Shot (`13c` - `AI.EVALUATE` con `TimesFM 3.0`):** valida automaticamente l'accuratezza di TimesFM 3.0 confrontando lo storico pre-Giugno 2025 con i dati reali di Giugno–Agosto 2025 e restituendo **`MAPE = 14.49%`** (`sMAPE = 15.84%`, `MAE = €1.842,69`) in una singola query senza `CREATE MODEL`.

---

### Step 3 — Creazione Property Graph & Esplorazione Relazioni (`sql/03` e `sql/05`)

Definiamo ora il grafo `retail_fraud.fraud_graph` sopra le tabelle relazionali (zero-copy, nessuna duplicazione di dati):

```bash
bq query --location=EU --use_legacy_sql=false < sql/03_property_graph.sql
```

Ora esegui le query esplorative di grafo e di loyalty cycling contenute in [`sql/05_graph_exploration_queries.sql`](sql/05_graph_exploration_queries.sql):

```bash
bq query --location=EU --use_legacy_sql=false < sql/05_graph_exploration_queries.sql
```

* **Q1 (Condivisione Device):** mostra le coppie di account che usano lo stesso `device_id`. La maggior parte sono coppie familiari innocue, ma i device `999001` e `999002` collegano **6 account distinti** ciascuno (`9001–9006`).
* **Q2 (Connessioni Multi-Entità):** ordina le coppie di clienti per numero di entità condivise (device, indirizzo, metodo di pagamento).
* **Q3 (Loyalty Points Cycling):** individua i clienti che hanno accumulato **e riscattato** punti fedeltà su ordini successivamente resi:

```sql
SELECT r.customer_id,
       COUNT(*) AS cycled_returns,
       SUM(e.points) AS points_cycled,
       ROUND(SUM(r.refund_amount), 2) AS refunds_on_cycled_orders
FROM `retail_fraud.returns` r
JOIN `retail_fraud.loyalty_transactions` e
  ON e.order_id = r.order_id AND e.txn_type = 'EARN'
JOIN `retail_fraud.loyalty_transactions` rd
  ON rd.order_id = r.order_id AND rd.txn_type = 'REDEEM'
 AND DATE(rd.txn_ts) < r.return_date
GROUP BY 1
HAVING COUNT(*) >= 3
ORDER BY points_cycled DESC;
```
**Risultato atteso:** emergono esclusivamente gli account **`9101–9104` (Ring B)**.

---

### Step 4 — Rilevamento dei Fraud Ring: Grafo + Comportamento (`sql/04`)

Una semplice condivisione di indirizzo o device non basta (due coniugi condividono indirizzo e carta). Lo script [`sql/04_ring_detection.sql`](sql/04_ring_detection.sql) combina la **topologia del grafo** ($\ge 3$ account intorno alla stessa entità) con il **filtro comportamentale** (tasso di reso $\ge 40\%$ e almeno 3 resi) per materializzare la tabella `retail_fraud.suspicious_rings`:

```bash
bq query --location=EU --use_legacy_sql=false < sql/04_ring_detection.sql
```

Ispeziona i ring rilevati:

```sql
SELECT * FROM `retail_fraud.suspicious_rings` ORDER BY refund_exposure DESC;
```

**Checkpoint di validazione (Confronto con Ground Truth):** verifica che i 3 ring scoperti corrispondano al 100% ai ring reali con **zero falsi positivi** (nessuno dei 50 clienti alto-rendenti legittimi `4001–4050` né le famiglie vengono inclusi):

```sql
SELECT d.ring_id, gt.ring_id AS seeded_ground_truth, COUNT(*) AS members
FROM `retail_fraud.suspicious_rings` d, UNNEST(d.members) m
LEFT JOIN `retail_fraud._ground_truth_rings` gt ON gt.customer_id = m
GROUP BY 1, 2
ORDER BY 1;
```

---

### Step 5 — Generative AI sul Testo Libero: Scoring, Estrazione & Sintesi (`sql/06` → `sql/09`)

#### 5a. Creazione Modello Remoto & Scoring Batch Resiliente (`sql/06` e `sql/07`)

Crea il riferimento al modello remoto e lancia la stored procedure incrementale `retail_fraud.score_new_returns_batch()` (che usa `AI.GENERATE_BOOL` all'interno di un ciclo `REPEAT ... UNTIL` resiliente agli errori di quota HTTP 429):

```bash
bq query --location=EU --use_legacy_sql=false < sql/06_remote_model.sql
bq query --location=EU --use_legacy_sql=false < sql/07_async_scoring_batch.sql
```

Verifica i risultati del primo batch (configurato a `LIMIT 20` per velocità in aula, dando priorità agli account sospetti):

```sql
SELECT IF(gt.customer_id IS NOT NULL, 'seeded_fraud', 'benign') AS truth,
       s.is_suspicious,
       COUNT(*) AS n
FROM `retail_fraud.returns_scored` s
LEFT JOIN `retail_fraud._ground_truth_rings` gt USING (customer_id)
GROUP BY 1, 2
ORDER BY 1, 2;
```
**Risultato atteso sul primo batch da 20 righe:** `20/20` resi `seeded_fraud` vengono correttamente classificati con `is_suspicious = TRUE` (e `ai_status` vuoto).

#### 5b. Estrazione Strutturata Tipizzata dalle Note Operatore (`sql/08`)

Esegui [`sql/08_notes_extraction.sql`](sql/08_notes_extraction.sql), che campiona in una tabella temporanea `_sampled_returns` 10 note rappresentative dei membri dei ring e invoca `AI.GENERATE` con `output_schema` tipizzato:

```bash
bq query --location=EU --use_legacy_sql=false < sql/08_notes_extraction.sql
```

Visualizza i campi strutturati estratti dal testo libero:

```sql
SELECT return_id, customer_id, claimed_issue, product_condition,
       refund_pressure, coordination_signal
FROM `retail_fraud.return_notes_extracted`
ORDER BY return_id;
```

#### 5c. Generazione Dossier Investigativi per Ring (`sql/09`) & `AI.AGG` (`sql/13d`)

Esegui [`sql/09_case_summaries.sql`](sql/09_case_summaries.sql) per generare il dossier investigativo (`case_summary`) di ogni ring unendo le prove del grafo con le note testuali:

```bash
bq query --location=EU --use_legacy_sql=false < sql/09_case_summaries.sql
```

Puoi anche testare direttamente l'aggregazione semantica nativa **`AI.AGG`** (senza `STRING_AGG` manuale) dentro una clausola `GROUP BY ring_id`:

```sql
SELECT
  sr.ring_id,
  sr.n_members,
  sr.refund_exposure AS refund_exposure_eur,
  AI.AGG(
    STRUCT(r.return_reason_text AS customer_claim, r.agent_notes AS support_agent_observation),
    'Agisci come Senior Fraud Investigator. Sintetizza in 2 frasi in italiano il Modus Operandi comune emergente da questi resi e indica 1 azione immediata di mitigazione.',
    connection_id => 'eu.vertex_ai_conn',
    endpoint => 'gemini-3.8-flash'
  ) AS ai_agg_modus_operandi_it
FROM `retail_fraud.suspicious_rings` sr,
UNNEST(sr.members) AS customer_id
JOIN `retail_fraud.returns` r USING (customer_id)
GROUP BY sr.ring_id, sr.n_members, sr.refund_exposure
ORDER BY sr.refund_exposure DESC;
```

#### 5d. Ranking Semantico (`AI.SCORE`) & Scoperta di Reclami "Copia-Incolla" (`AI.SIMILARITY`) (`sql/13e` & `sql/13f`)

Nello script [`sql/13_timesfm_and_ai_agg_enhancements.sql`](sql/13_timesfm_and_ai_agg_enhancements.sql) trovi inoltre due potenti funzioni per l'investigazione sul testo:
1. **`AI.SCORE` nell'`ORDER BY` (`13e`):** ordina i resi sospetti in base al grado di **minaccia di chargeback, intimidazione legale e pressione sull'operatore** espresso in linguaggio naturale:
   ```sql
   SELECT return_id, customer_id, refund_amount, return_reason_text, agent_notes,
          ROUND(AI.SCORE(
            ('Rate the severity of chargeback threat, legal intimidation, refusal of store credit, or scripted abuse in this return interaction: ',
             return_reason_text, ' | Agent notes: ', agent_notes),
            connection_id => 'eu.vertex_ai_conn'
          ), 2) AS escalation_risk_score
   FROM (SELECT * FROM `retail_fraud.returns` WHERE customer_id >= 9000 LIMIT 10)
   ORDER BY escalation_risk_score DESC
   LIMIT 5;
   ```
2. **`AI.SIMILARITY` (`13f`):** calcola la similarità coseno (`text-embedding-005`) tra i motivi di reso per far emergere gli account formalmente distinti che usano lo **stesso copione (script)** fraudolento.

---

### Step 6 — Dashboard Unificata per il Team Antifrode (`sql/11`)

Crea la vista finale `retail_fraud.fraud_dashboard` che unisce i ring del grafo, i conteggi dei resi flaggati dall'AI e il dossier investigativo:

```bash
bq query --location=EU --use_legacy_sql=false < sql/11_fraud_dashboard.sql
```

Interroga la dashboard ordinata per esposizione finanziaria (€ a rischio):

```sql
SELECT * FROM `retail_fraud.fraud_dashboard` ORDER BY refund_exposure DESC;
```

---

### Step 7 — Test Live della Pipeline Asincrona Incrementale (`sql/12`)

In produzione una **Scheduled Query** invoca `CALL retail_fraud.score_new_returns_batch();` ogni 15 minuti: processa **esclusivamente i nuovi resi non ancora presenti in `returns_scored`**, senza mai bloccare il database transazionale né ricalcolare le righe già analizzate.

Simuliamo l'arrivo in tempo reale di **10 nuovi reclami sospetti** (`return_id >= 6000000`):

```bash
bq query --location=EU --use_legacy_sql=false < sql/12_simulate_new_returns.sql
```

Ora attiva manualmente un ciclo della pipeline asincrona:

```bash
bq query --location=EU --use_legacy_sql=false "CALL \`retail_fraud.score_new_returns_batch\`();"
```

Verifica che i 10 nuovi resi siano stati immediatamente intercettati e classificati:

```sql
SELECT COUNT(*) AS total_scored,
       COUNTIF(return_id >= 6000000) AS newly_arrived,
       COUNTIF(return_id >= 6000000 AND is_suspicious) AS newly_arrived_flagged_suspicious
FROM `retail_fraud.returns_scored`;
```
**Risultato atteso:** `total_scored = 40`, **`newly_arrived = 10`**, e le righe precedenti non sono state rielaborate.

---

### Step 8 — Bonus Retail: Arricchimento Automatico del Catalogo (`sql/10`)

Le stesse funzioni `AI.GENERATE` possono risolvere problemi retail completamente diversi, come riscrivere descrizioni di catalogo legacy criptiche (`"home itm 3 gry s/m/l no tag imp.2024..."`) in testi e-commerce pronti per la pubblicazione:

```bash
bq query --location=EU --use_legacy_sql=false < sql/10_catalog_enrichment.sql
```

Controlla il risultato:

```sql
SELECT sku, product_name, raw_description, enriched_description
FROM `retail_fraud.products_enriched`
ORDER BY product_id
LIMIT 10;
```

---

### Step 9 — Bonus Pack: BigQuery Augmented Analytics TVFs (`sql/14`)

Per completare l'indagine con le 6 nuove **Table-Valued Functions di Augmented Analytics** (`ML.DETECT_CHANGE_POINTS`, `ML.TREND`, `ML.SEASONALITY`, `AI.KEY_DRIVERS`, `AI.CAUSAL_EFFECT`, `ML.CORRELATION`), esegui:

```bash
bq query --location=EU --use_legacy_sql=false < sql/14_augmented_analytics_bonus_pack.sql
```

👉 Consulta la guida dedicata **[AUGMENTED_ANALYTICS_BONUS_PACK.md](AUGMENTED_ANALYTICS_BONUS_PACK.md)** per i dettagli sul chaining tra le funzioni e l'interpretazione dell'impatto causale netto (+€75.489).

---

## 📂 Riepilogo dei File SQL (`retail_fraud/sql/`)

| File | Ordine Consigliato | Descrizione |
|---|---|---|
| [`sql/01_customers_products.sql`](sql/01_customers_products.sql) | Step 1a | Crea lo schema `retail_fraud` (`EU`), `customers` (5.015) e `products` (500). |
| [`sql/02_orders_returns_loyalty.sql`](sql/02_orders_returns_loyalty.sql) | Step 1b | Popola `orders` (50k), `returns` (~4.400), `loyalty_*`, tabelle entità e `_ground_truth_rings`. |
| [`sql/13_timesfm_and_ai_agg_enhancements.sql`](sql/13_timesfm_and_ai_agg_enhancements.sql) | Step 2 & 5c | **TimesFM 3.0** (`AI.DETECT_ANOMALIES`, `AI.FORECAST` multivariato `target_cols`, `AI.EVALUATE`) + **`AI.AGG`**, **`AI.SCORE`**, **`AI.SIMILARITY`**. |
| [`sql/03_property_graph.sql`](sql/03_property_graph.sql) | Step 3a | `CREATE OR REPLACE PROPERTY GRAPH retail_fraud.fraud_graph`. |
| [`sql/05_graph_exploration_queries.sql`](sql/05_graph_exploration_queries.sql) | Step 3b | Query esplorative GQL (device condivisi, entità condivise, loyalty cycling). |
| [`sql/04_ring_detection.sql`](sql/04_ring_detection.sql) | Step 4 | GQL + filtro comportamentale $\rightarrow$ materializza `suspicious_rings` (con auto-fallback SQL). |
| [`sql/06_remote_model.sql`](sql/06_remote_model.sql) | Step 5a | Crea il modello remoto `retail_fraud.gemini_model` (`gemini-3.8-flash`). |
| [`sql/07_async_scoring_batch.sql`](sql/07_async_scoring_batch.sql) | Step 5a | Stored procedure `score_new_returns_batch()` con retry loop `REPEAT ... UNTIL`. |
| [`sql/08_notes_extraction.sql`](sql/08_notes_extraction.sql) | Step 5b | Estrazione strutturata da `agent_notes` con `AI.GENERATE` e `output_schema`. |
| [`sql/09_case_summaries.sql`](sql/09_case_summaries.sql) | Step 5c | Generazione dossier investigativo (`case_summaries`) per ciascun ring. |
| [`sql/11_fraud_dashboard.sql`](sql/11_fraud_dashboard.sql) | Step 6 | Crea la vista unificata `retail_fraud.fraud_dashboard`. |
| [`sql/12_simulate_new_returns.sql`](sql/12_simulate_new_returns.sql) | Step 7 | Inserisce 10 nuovi resi (`return_id >= 6000000`) per testare la pipeline incrementale. |
| [`sql/10_catalog_enrichment.sql`](sql/10_catalog_enrichment.sql) | Step 8 | Arricchisce le descrizioni legacy del catalogo prodotti (`products_enriched`). |
| [`sql/14_augmented_analytics_bonus_pack.sql`](sql/14_augmented_analytics_bonus_pack.sql) | Step 9 (Bonus) | Suite completa di 6 Augmented Analytics TVFs per Data Agents. |

---

## 💰 Note sui Costi & Pulizia Risorse (Teardown)

* Il volume dati è leggerissimo (< 100 MB) e i campionamenti (`LIMIT 20` / `_sampled_returns`) mantengono il consumo Vertex AI nell'ordine di **pochi centesimi di euro** per esecuzione completa.
* Per rimuovere tutte le risorse create alla fine del laboratorio, esegui dalla root del repository:

```bash
../cleanup_hackathon.sh -y
```
