# Walkthrough Passo-Passo (Lab II) — NovaHome Product Review Intelligence

**Ambiente Target:** Progetto Qwiklabs / GCP vuoto (Location: **EU**)  
**Verticale:** Manufacturing (Piccoli Elettrodomestici)  
**Dataset BigQuery:** `mfg_quality_demo`  
**Connection Vertex AI:** `eu.vertex_ai_conn` (`gemini-3.8-flash`)

---

## 🎯 Scenario di Business

**NovaHome Appliances** produce bollitori elettrici (`KTL-100`, `KTL-200`), macchine da caffè (`CM-350`), frullatori (`BLD-220`), tostapane (`TST-140`) e friggitrici ad aria (`AFR-500`). I clienti pubblicano migliaia di recensioni non strutturate su Amazon, siti dei rivenditori, app mobile ed email di supporto.

Il team di **Quality Engineering** vuole scoprire — *senza leggere manualmente le recensioni* — se i reclami indicano un vero difetto di fabbricazione e, in caso affermativo, **quale lotto di componenti (`lot_id`) e quale macchinario di stabilimento (`machine_id`) sono responsabili**.

### La Soluzione in BigQuery
Le funzioni di AI generativa di BigQuery ([`AI.GENERATE`](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/bigqueryml-syntax-ai-generate), `AI.IF`, `AI.CLASSIFY`, `AI.GENERATE_INT`, `AI.AGG`) trasformano il testo libero delle recensioni in segnali di qualità tipizzati e strutturati **direttamente dentro il data warehouse**, in modalità asincrona tramite una stored procedure schedulata. Successivamente, normali query SQL e la funzione **`AI.KEY_DRIVERS`** incrociano tali segnali con la **Distinta Base (Bill of Materials - BOM)** dello stabilimento per isolare i lotti e i macchinari colpevoli.

Il laboratorio affronta esplicitamente due requisiti fondamentali di produzione:
1. **Ottimizzazione dei Costi ([Model Distillation](https://docs.cloud.google.com/bigquery/docs/optimize-ai-functions)):** utilizzo di `optimization_mode => 'MINIMIZE_COST'` per `AI.IF` e `AI.CLASSIFY` (Step 2).
2. **Resilienza agli Errori di Quota ([Retry Pattern](https://docs.cloud.google.com/bigquery/docs/iterate-generate-text-calls)):** ciclo `REPEAT ... UNTIL` integrato nella stored procedure `enrich_new_reviews()` per riprovare solo le righe che incontrano errori temporanei di rate-limit senza ri-fatturare le righe già elaborate (Step 3).

---

## 🏗️ Architettura & Modello Dati

```
 Feed Recensioni       ┌────────────────────────── BigQuery (EU) ──────────────────────────┐
 (Amazon, App,   ───▶  │ product_reviews (testo libero non strutturato)                    │
 Email Supporto)       │        │                                                          │
                       │        │  esecuzione asincrona / incrementale (ogni 6h)           │
                       │        ▼                                                          │
                       │ CALL enrich_new_reviews()                                         │
                       │   AI.GENERATE(output_schema => sentiment, defect_category, ...)   │──▶ Vertex AI
                       │   └─ retry loop: rielabora solo le righe con errore quota 429     │    Gemini 3.8 Flash
                       │        ▼                                                          │
                       │ review_insights (tabella strutturata tipizzata)                   │
                       │        │ join: batches → bill of materials → component lots       │
                       │        ▼            → machines + AI.KEY_DRIVERS                   │
                       │ v_component_lot_defect_rates → Root Cause + AI Executive Brief    │
                       └───────────────────────────────────────────────────────────────────┘
```

| Tabella | Contenuto |
|---|---|
| `products` | 6 SKU (bollitori, macchina da caffè, frullatore, tostapane, friggitrice ad aria) |
| `machines` | 8 macchinari di fabbrica (assemblaggio, calibrazione termica, stampaggio, sigillatura…) |
| `component_lots` | 13 lotti di componenti (resistenze termiche, termostati, motori, guarnizioni…), ciascuno lavorato da un macchinario |
| `production_batches` | 10 lotti di produzione finiti; il numero di serie del cliente mappa su un `batch_id` |
| `batch_components` | Distinta Base (BOM): quali `lot_id` di componenti sono stati montati in ciascun `batch_id` |
| `product_reviews` | 60 recensioni non strutturate dei clienti associate ai batch di produzione |
| `review_insights` | **Output AI**: sentiment, flag difetto, categoria, componente sospetto, gravità (1–5), sintesi |

**La storia nascosta nei dati:** il lotto di resistenze termiche **`HE-4471`** (fornitore *ThermoCore*) è stato calibrato sulla stazione **`CAL-02`**, la cui manutenzione è scaduta da mesi (`2025-01-17`). I batch assemblati con quel lotto generano un'ondata di recensioni *"non scalda più / acqua tiepida"*. Un lotto di guarnizioni (**`GSK-770`**) causa inoltre una serie minore di reclami per perdite d'acqua sulle macchine da caffè.

---

## 🛠️ Step 0 — Setup Iniziale in Ambiente Qwiklabs Vuoto

Se hai già eseguito `./init_hackathon_student.sh` durante il Lab I nello stesso progetto Qwiklabs, **il tuo ambiente e i dati base del Lab II sono già pronti** e puoi saltare direttamente allo **Step 1**.

Se invece parti da un progetto Qwiklabs completamente vuoto, apri **Google Cloud Shell**, clona il repository ed esegui lo script di bootstrap:

```bash
git clone https://github.com/malagoli/applied-ai-2026-10.git
cd applied-ai-2026-10
chmod +x init_hackathon_student.sh
./init_hackathon_student.sh
```

*(In alternativa, se preferisci eseguire i singoli comandi manuali in un progetto vuoto:)*

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

---

## 🚀 Guida Operativa Passo-Passo

Entra nella cartella del **Lab II**:

```bash
cd product_analytics
```

Tutti gli script si trovano in `sql/` e possono essere eseguiti sia via Cloud Shell con:

```bash
bq query --use_legacy_sql=false --location=EU < sql/<nome_script>.sql
```
sia copiando le query SQL direttamente nell'editor della **Console Web di BigQuery**.

---

### Step 1 — Creazione Dataset e Caricamento Dati ERP + Recensioni (`sql/01_setup_dataset_and_data.sql`)

Se non hai già eseguito `./init_hackathon_student.sh`, crea lo schema `mfg_quality_demo` (in location `EU`) e carica le tabelle di fabbrica e le 60 recensioni:

```bash
bq query --use_legacy_sql=false --location=EU < sql/01_setup_dataset_and_data.sql
```

Verifica in BigQuery le prime recensioni grezze:

```sql
SELECT review_id, sku, batch_id, rating, source, review_text
FROM `mfg_quality_demo.product_reviews`
ORDER BY review_id
LIMIT 10;
```

---

### Step 2 — Triage Ad-Hoc, Distillazione Costi & Ranking Semantico `AI.SCORE` (`sql/02_quick_triage.sql`)

Una singola query SQL, senza alcun deployment di modelli, permette a Gemini di analizzare e ordinare ogni riga con quattro funzioni scalari:
* **`AI.IF`** — *"Questa recensione descrive un difetto fisico/funzionale del prodotto (escludendo spedizione, prezzo o gusti personali)?"* $\rightarrow$ `BOOL`
* **`AI.CLASSIFY`** — *"In quale categoria ricade il problema?"* (`heating`, `motor`, `leak_seal`, `electronics`, `housing_cosmetic`, `none`) $\rightarrow$ `STRING`
* **`AI.GENERATE_INT`** — *"Qual è la gravità da 1 a 5?"* $\rightarrow$ `INT64`
* **`AI.SCORE`** — *"Ordina le recensioni per urgenza di rischio sicurezza fisica (incendio elettrico, odore di bruciato, perdita d'acqua vicino alla presa)"* $\rightarrow$ `FLOAT64` direttamente nella clausola `ORDER BY`!

Esegui lo script:

```bash
bq query --use_legacy_sql=false --location=EU < sql/02_quick_triage.sql
```

Oppure esegui direttamente in Console:

```sql
SELECT
  r.review_id,
  r.sku,
  r.rating,
  LEFT(r.review_text, 80) AS review_snippet,
  AI.IF(
    ('Does this product review describe a malfunction or physical defect of the product itself (not shipping, packaging, price or personal preference)? Review: ', r.review_text),
    connection_id     => 'eu.vertex_ai_conn',
    optimization_mode => 'MINIMIZE_COST'
  ) AS is_defect_report,
  AI.CLASSIFY(
    r.review_text,
    categories        => ['heating', 'motor', 'leak_seal', 'electronics', 'housing_cosmetic', 'none'],
    connection_id     => 'eu.vertex_ai_conn',
    optimization_mode => 'MINIMIZE_COST'
  ) AS defect_category,
  AI.GENERATE_INT(
    ('Rate the severity of the problem described in this review from 1 (cosmetic/no problem) to 5 (safety hazard or total failure). Review: ', r.review_text),
    connection_id => 'eu.vertex_ai_conn',
    endpoint      => 'gemini-3.8-flash'
  ).result AS severity
FROM `mfg_quality_demo.product_reviews` AS r
ORDER BY r.review_id
LIMIT 10;
```

**Cosa osservare:**
* Una recensione a 5 stelle (`R-0006`) e una lamentela sul cavo troppo corto (`R-0008`) ricevono entrambe `is_defect_report = FALSE`, mentre i reclami *"stopped heating after two weeks"* (`R-0001`..`R-0005`) vengono classificati come `TRUE` / `heating` con gravità `4–5`.
* La seconda query dello script (**`2b` con `AI.SCORE`**) fa emergere immediatamente in cima i reclami ad alto rischio sicurezza come `R-0030` (*"Water everywhere on the counter, nearly reached the outlet. This is a safety issue"*) e `R-0036` (*"smell something burning"*).
* **Come funziona `optimization_mode => 'MINIMIZE_COST'`:** Su tabelle di grandi dimensioni ($\ge 3.000$ righe), BigQuery invia solo un campione di righe all'LLM, addestra automaticamente dietro le quinte un modello locale leggero basato sugli embedding del testo, ne valida la qualità e serve la maggior parte della tabella dal modello distillato locale abbattendo costi e latenza. Sotto le 3.000 righe (come le 60 di questa demo), BigQuery effettua automaticamente il fallback trasparente sull'LLM. *(Nota: quando si usa `optimization_mode` non va specificato `endpoint`).*

---

### Step 3 — Pipeline Asincrona di Arricchimento & Resilienza alla Quota (`sql/03_async_enrichment_pipeline.sql`)

In produzione non si ricalcolano le recensioni ad ogni query: si usa una stored procedure incrementale **`mfg_quality_demo.enrich_new_reviews()`** che:
1. Effettua un `LEFT JOIN ... WHERE i.review_id IS NULL` tra `product_reviews` e `review_insights` per processare **solo le recensioni non ancora analizzate**.
2. Invoca `AI.GENERATE` con **`output_schema`** (`sentiment STRING, is_defect_report BOOL, defect_category STRING, affected_component STRING, severity INT64, summary STRING`) ottenendo uno `STRUCT` SQL già validato e tipizzato (nessun parsing JSON o regex fragile).
3. **Gestisce automaticamente gli errori di quota (HTTP 429):** quando una chiamata incontra un limite di rate su Vertex AI, BigQuery non fallisce la query ma scrive `A retryable error occurred: ...` nella colonna `status`. Il ciclo `REPEAT ... UNTIL` cancella e riprova **solo le righe con errore retryable** fino a `max_attempts = 3`, senza mai ri-fatturare le righe andate a buon fine:

```sql
REPEAT
  DELETE FROM `mfg_quality_demo.review_insights`
  WHERE ai_status LIKE '%A retryable error occurred%';

  INSERT INTO `mfg_quality_demo.review_insights`
  SELECT ... AI.GENERATE(...) ...
  FROM `mfg_quality_demo.product_reviews` r
  LEFT JOIN `mfg_quality_demo.review_insights` i USING (review_id)
  WHERE i.review_id IS NULL;

  SET attempts = attempts + 1;
  SET retryable_rows = (
    SELECT COUNT(*) FROM `mfg_quality_demo.review_insights`
    WHERE ai_status LIKE '%A retryable error occurred%'
  );
UNTIL retryable_rows = 0 OR attempts >= max_attempts
END REPEAT;
```

Esegui lo script (che crea la tabella `review_insights`, crea la procedura `enrich_new_reviews()` e ne lancia il primo ciclo completo sulle 60 recensioni):

```bash
bq query --use_legacy_sql=false --location=EU < sql/03_async_enrichment_pipeline.sql
```

Verifica che tutte le 60 recensioni siano state arricchite senza errori residui:

```sql
SELECT COUNT(*) AS total_enriched,
       COUNTIF(ai_status IS NOT NULL AND ai_status != '') AS failed_rows,
       COUNTIF(is_defect_report) AS total_defects_found
FROM `mfg_quality_demo.review_insights`;
```

---

### Step 4 — Root-Cause Analysis: Dalle Recensioni al Macchinario di Fabbrica (`sql/04_root_cause_analysis.sql`)

Ora che il testo libero è strutturato in `review_insights`, usiamo SQL standard per unire il campo `affected_component` ipotizzato dall'AI con la **Distinta Base (`batch_components` $\rightarrow$ `component_lots` $\rightarrow$ `machines`)**.

Esegui [`sql/04_root_cause_analysis.sql`](sql/04_root_cause_analysis.sql), che crea la vista `mfg_quality_demo.v_component_lot_defect_rates` ed esegue 3 query diagnostiche:

```bash
bq query --use_legacy_sql=false --location=EU < sql/04_root_cause_analysis.sql
```

#### Risultati Chiave:
1. **Classifica per Lotto di Componenti (`4a`):**

| `lot_id` | `component_type` | `supplier` | `installed_by_machine_id` | Recensioni Esposte | Recensioni Difettose | Implication Rate | Gravità Media |
|---|---|---|---|---|---|---|---|
| **`HE-4471`** | `heating_element` | `ThermoCore` | **`CAL-02`** | 22 | 17 | **0.77 (77%)** | **4.5** |
| **`GSK-770`** | `gasket_seal` | `FlexiSeal` | `SEAL-01` | 12 | 8 | **0.67 (67%)** | 3.9 |
| `HE-4472` | `heating_element` | `ThermoCore` | `CAL-01` | 11 | 1 | 0.09 (9%) | 2.0 |
| `HE-4398` | `heating_element` | `Calorix` | `CAL-01` | 18 | 0 | 0.00 (0%) | 0.0 |

2. **Il "Control Check" Scientifico (`4c`):**
   Confrontando i 3 lotti di `heating_element`, due provengono dallo **stesso identico fornitore (`ThermoCore`)**: `HE-4471` e `HE-4472`. Eppure solo il lotto **`HE-4471` calibrato sulla stazione `CAL-02`** presenta un tasso di guasto del **77%** (contro il 9% su `CAL-01`). Controllando la tabella `machines`, scopriamo che **`CAL-02` non riceve manutenzione dal `2025-01-17`**! Non è un difetto di progettazione del bollitore né del fornitore, ma una deriva di calibrazione del macchinario `CAL-02`.

---

### Step 5 — `AI.KEY_DRIVERS`, `AI.AGG`, Semantic `JOIN ON AI.IF`, `AI.SIMILARITY` & `TimesFM 3.0` (`sql/07_key_drivers_and_ai_agg_enhancements.sql`)

Lo script [`sql/07_key_drivers_and_ai_agg_enhancements.sql`](sql/07_key_drivers_and_ai_agg_enhancements.sql) mostra 7 pattern avanzati di Applied AI e Time-Series Foundation Models in BigQuery:

```bash
bq query --use_legacy_sql=false --location=EU < sql/07_key_drivers_and_ai_agg_enhancements.sql
```

1. **7a. Scoperta Automatica dei Driver (`AI.KEY_DRIVERS`):** in ~0.5 secondi individua automaticamente il segmento `["component_type=heating_element", "supplier=ThermoCore"]` con un incremento relativo del **+1600%** dei difetti su `CAL-02`.
2. **7b. Aggregazione Semantica Multi-Riga (`AI.AGG`):** genera direttamente dentro `GROUP BY p.sku, p.product_name` il bollettino tecnico in italiano per il team R&D di ciascun prodotto.
3. **7c. Join Semantico Relazionale (`JOIN ... ON AI.IF(...)`):** unisce una tabella di **Bollettini Tecnici dei Fornitori (`engineering_bulletins`)** direttamente con il testo libero delle recensioni (`product_reviews`) usando `AI.IF` come condizione di `JOIN`, senza alcuna chiave esterna comune:
   ```sql
   SELECT b.bulletin_id, b.component_family, r.review_id, r.sku, r.batch_id
   FROM engineering_bulletins b
   JOIN sample_reviews r
     ON AI.IF(
       ('Does this customer review describe the exact technical failure symptom in the engineering bulletin? Review: ',
        r.review_text, ' | Engineering Bulletin: ', b.bulletin_symptom),
       connection_id => 'eu.vertex_ai_conn'
     );
   ```
4. **7d. Ricerca per Similarità Semantica (`AI.SIMILARITY`):** data una segnalazione critica, calcola la cosine similarity con `text-embedding-005` per trovare tutti i reclami gemelli nel catalogo anche quando usano parole completamente diverse.
5. **7e. Rilevamento Anomalie con `TimesFM 3.0` (`AI.DETECT_ANOMALIES`):** intercetta automaticamente in zero-shot (`model => 'TimesFM 3.0'`) i giorni di fine Luglio / inizio Agosto 2025 (`2025-07-27`, `2025-07-28`, `2025-08-01` con `prob = 1.000`, `2025-08-02` con `prob = 0.999`) in cui i reclami difettosi superano la banda predittiva in seguito alla distribuzione dei lotti `HE-4471`.
6. **7f. Forecasting Multivariato con Covariate in `TimesFM 3.0` (`AI.FORECAST`):** utilizza i nuovi parametri esclusivi di **TimesFM 3.0** (`target_cols => ['defect_count', 'avg_severity']`, `past_covariate_cols => ['total_reviews']`) per prevedere simultaneamente il numero di difetti giornalieri e la gravità media per i successivi 5 giorni.
7. **7g. Backtesting Zero-Shot con `TimesFM 3.0` (`AI.EVALUATE`):** certifica l'errore medio assoluto (`MAE = 1.17`, `RMSE = 1.49`) del modello `TimesFM 3.0` sulla serie storica dei difetti senza bisogno di `CREATE MODEL`.

---

### Step 6 — Generazione Automatica dell'Executive Briefing (`sql/05_executive_summary.sql`)

Chiudiamo il cerchio passando i dati aggregati della vista `v_component_lot_defect_rates` e le date di manutenzione di `machines` a `AI.GENERATE` per redigere il memo esecutivo per l'Head of Quality:

```bash
bq query --use_legacy_sql=false --location=EU < sql/05_executive_summary.sql
```

**Risultato atteso:** Gemini produce un briefing di max 250 parole che nomina esplicitamente il lotto **`HE-4471`**, il fornitore **`ThermoCore`** e la stazione **`CAL-02`** (citando la manutenzione ferma al `2025-01-17` e il 77% di difettosità) e raccomanda tre azioni immediate: quarantena dei lotti processati su `CAL-02`, ricalibrazione immediata della stazione e verifica congiunta sul lotto di guarnizioni `GSK-770`.

---

### Step 7 — Simulazione Live: Arrivo di Nuove Recensioni (`sql/06_simulate_new_reviews.sql`)

Verifichiamo infine il comportamento incrementale della pipeline asincrona inserendo **3 nuove recensioni** (`R-0061`, `R-0062`, `R-0063`):

```bash
bq query --use_legacy_sql=false --location=EU < sql/06_simulate_new_reviews.sql
```

Lo script mostra che le 3 nuove recensioni sono presenti in `product_reviews` ma non ancora in `review_insights` (sono in backlog). Ora invoca la stored procedure:

```bash
bq query --use_legacy_sql=false --location=EU "CALL \`mfg_quality_demo.enrich_new_reviews\`();"
```

**Cosa succede:** grazie all'anti-join incrementale (`WHERE i.review_id IS NULL`), BigQuery invia a Gemini **esclusivamente le 3 nuove recensioni** (le 60 precedenti non vengono toccate né ri-fatturate!). Rilanciando la query sulla vista `v_component_lot_defect_rates`, i conteggi del lotto `HE-4471` e `GSK-770` si aggiornano istantaneamente:

```sql
SELECT lot_id, component_type, supplier, installed_by_machine_id,
       reviews_on_batches_using_lot, implicating_defect_reviews, implication_rate
FROM `mfg_quality_demo.v_component_lot_defect_rates`
ORDER BY implication_rate DESC, implicating_defect_reviews DESC;
```

---

## 💰 Note sui Costi & Pulizia Risorse (Teardown)

* Ogni esecuzione completa del Lab II analizza ~63 recensioni brevi con Gemini 3.8 Flash, con un costo inferiore a **pochi centesimi di euro**.
* Per eliminare tutti i dataset e le connessioni al termine dell'Hackathon, esegui dalla root del repository:

```bash
../cleanup_hackathon.sh -y
```
