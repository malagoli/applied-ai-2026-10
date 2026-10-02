# BigQuery Applied AI & Agentic Data Cloud — Catalogo Funzionalità & Use Case Verticali

**Target Platform:** Google Cloud BigQuery + Vertex AI (`gemini-3.8-flash`, `text-embedding-005`, `TimesFM 3.0`, `ISO GQL Property Graph`)
**Verticali Coperti:** `Banking / Finance` · `Retail & Consumer` · `Pharma & Life Sciences` · `Manufacturing` · `Public Sector` · `Telco & Media`

---

## Parte 1: Panoramica Generale delle Funzionalità

### 1. Dal Data Warehouse Passivo all'Agentic Data Cloud
BigQuery unifica in un unico motore SQL serverless cinque paradigmi storicamente separati:
1. **Generative & Semantic SQL (`Gemini 3.8 Flash`):** `AI.IF`, `AI.CLASSIFY`, `AI.SCORE`, `AI.GENERATE`, `AI.GENERATE_BOOL/INT/DOUBLE`, `AI.AGG` — per filtrare, classificare, ordinare, estrarre schemi strutturati, eseguire join semantici e sintetizzare testi direttamente in SQL, con distillazione automatica dei modelli (`optimization_mode => 'MINIMIZE_COST'`).
2. **Vector & Similarity SQL (`text-embedding-005`):** `AI.SIMILARITY` — per calcolare la cosine similarity tra testi al volo (Zero-DDL), senza pipeline di chunking o indici vettoriali pre-costruiti.
3. **Zero-Shot Time-Series Foundation Models (`TimesFM 3.0`):** `AI.FORECAST` (univariato e multivariato con `target_cols` e covariate `past_covariate_cols`), `AI.DETECT_ANOMALIES`, `AI.EVALUATE` — per prevedere serie storiche, intercettare anomalie e certificare il backtesting (MAE, RMSE, MAPE) in pochi secondi senza `CREATE MODEL`.
4. **Augmented Analytics & Causal TVFs:** `AI.KEY_DRIVERS`, `AI.CAUSAL_EFFECT`, `ML.DETECT_CHANGE_POINTS`, `ML.TREND`, `ML.SEASONALITY`, `ML.CORRELATION` — funzioni tabellari statistiche e Bayesiane per root-cause analysis, inferenza causale controfattuale, cambi di regime e decomposizione.
5. **Native Graph Analytics (`ISO/IEC 39075 GQL`):** `CREATE PROPERTY GRAPH` & `GRAPH_TABLE` — per scoprire anelli di frode, genealogia di lotti e dipendenze di rete multi-hop sulle tabelle relazionali esistenti a zero copie fisiche.

### 2. Matrice Sinottica delle 16 Funzionalità

| # | Funzione SQL | Famiglia | Motore / Modello | Scopo Principale | Riferimento nei Laboratori |
|---|---|---|---|---|---|
| **01** | `AI.IF` | Generative SQL (Booleano) | `Gemini 3.8 Flash · MINIMIZE_COST` | Valuta una condizione in linguaggio naturale su testo o dati multimodali restituendo un BOOL direttamente in W... | Lab II (02_quick_triage.sql & 07_key_drivers_and_ai_agg_enhancements.sql): filtro recensioni difettose e Semantic JOIN tra bollettini tecnici e reclami. |
| **02** | `AI.CLASSIFY` | Generative SQL (Tassonomico) | `Gemini 3.8 Flash · MINIMIZE_COST` | Assegna ogni record non strutturato a una categoria esatta scelta da un array predefinito, senza esempi di add... | Lab II (02_quick_triage.sql): classificazione istantanea dei difetti in ['heating_failure', 'water_leak', 'electrical_fault', 'mechanical_wear', 'cosmetic']. |
| **03** | `AI.SCORE` | Generative SQL (Ranking) | `Gemini 3.8 Flash (Managed Scoring)` | Assegna un punteggio numerico continuo (FLOAT64) a ogni riga in base a una rubrica qualitativa espressa in lin... | Lab I (13_timesfm_and_ai_agg_enhancements.sql) & Lab II (02_quick_triage.sql): ranking per minaccia chargeback (score 5.0) e rischio sicurezza elettrica/incendio. |
| **04** | `AI.GENERATE` | Generative SQL (Structured Output & Text) | `Gemini 3.8 Flash · output_schema` | Trasforma testo libero o oggetti multimodali in uno STRUCT tipizzato BigQuery conforme a output_schema (oppure... | Lab I (08_notes_extraction.sql, 09_case_summaries.sql, 10_catalog_enrichment.sql) & Lab II (03_async_enrichment_pipeline.sql, 05_executive_summary.sql). |
| **05** | `AI.GENERATE_BOOL` | Generative SQL (Scalare Tipizzato) | `Gemini 3.8 Flash · Stored Procedure Batch` | Famiglia di funzioni scalari (AI.GENERATE_BOOL, AI.GENERATE_INT, AI.GENERATE_DOUBLE) che restituiscono un sing... | Lab I (07_async_scoring_batch.sql & 12_simulate_new_returns.sql): scoring incrementale con ciclo REPEAT...UNTIL che intercetta 10/10 nuovi resi fraudolenti. |
| **06** | `AI.AGG` | Generative SQL (Semantic Aggregate) | `Gemini 3.8 Flash (1M Token Context)` | Funzione di aggregazione nativa SQL (come SUM o COUNT) che combina centinaia o migliaia di testi all'interno d... | Lab I (13_timesfm_and_ai_agg_enhancements.sql) & Lab II (07_key_drivers_and_ai_agg_enhancements.sql): sintesi Modus Operandi per Fraud Ring e Quality Brief per SKU. |
| **07** | `AI.SIMILARITY` | Vector & Embedding SQL | `Vertex AI text-embedding-005` | Genera al volo gli embedding vettoriali dei due testi tramite text-embedding-005 e restituisce la similarità c... | Lab I (13_timesfm_and_ai_agg_enhancements.sql) & Lab II (07_key_drivers_and_ai_agg_enhancements.sql): caccia a script fraudolenti (0.840) e ricerca reclami gemelli (0.870). |
| **08** | `AI.FORECAST` | Time-Series Foundation Model | `Google Research TimesFM 3.0 (Multivariate)` | Proietta nel futuro serie storiche univariate (data_col) o multivariate correlate (target_cols + past_covariat... | Lab I (13_timesfm_and_ai_agg_enhancements.sql) & Lab II (07_key_drivers_and_ai_agg_enhancements.sql): forecast multivariato di rimborsi/resi e difetti giornalieri con TimesFM 3.0. |
| **09** | `AI.DETECT_ANOMALIES` | Time-Series Foundation Model | `Google Research TimesFM 3.0 (Zero-Shot)` | Confronta una finestra storica di baseline con una finestra di ispezione usando TimesFM 3.0, calcolando i limi... | Lab I (13_timesfm_and_ai_agg_enhancements.sql) & Lab II (07_key_drivers_and_ai_agg_enhancements.sql): rileva le settimane di attacco di Ring C (p=0.973) e il picco di guasti dopo l'ingresso di HE-4471. |
| **10** | `AI.EVALUATE` | Time-Series Foundation Model (Governance) | `Google Research TimesFM 3.0 (Zero-Shot Eval)` | Valida scientificamente l'accuratezza previsiva zero-shot di TimesFM 3.0 su una finestra di holdout storica, c... | Lab I (13_timesfm_and_ai_agg_enhancements.sql) & Lab II (07_key_drivers_and_ai_agg_enhancements.sql): certifica TimesFM 3.0 sui resi (MAPE = 14.49%) e sul volume giornaliero di recensioni. |
| **11** | `AI.KEY_DRIVERS` | Augmented Analytics TVF | `BigQuery Automated Contribution Engine` | Esplora automaticamente tutte le combinazioni dimensionali (singole e incrociate) per isolare i segmenti che s... | Lab I (14_augmented_analytics_bonus_pack.sql) & Lab II (07_key_drivers_and_ai_agg_enhancements.sql): isola ['component_type=heating_element', 'supplier=ThermoCore']. |
| **12** | `AI.CAUSAL_EFFECT` | Augmented Analytics TVF (Causal AI) | `Bayesian Structural Time-Series (Counterfactual)` | Stima l'effetto causale netto di un evento o intervento costruendo un controfattuale sintetico Bayesiano di ci... | Lab I (14_augmented_analytics_bonus_pack.sql): quantifica l'impatto netto dell'ondata di frode dal 15 Nov 2025 in +€75.489 (+19.9% sul controfattuale). |
| **13** | `ML.DETECT_CHANGE_POINTS` | Augmented Analytics TVF (Time-Series) | `BigQuery Structural Break Detection` | Scansiona una serie storica per individuare automaticamente i punti esatti in cui il livello medio o il regime... | Lab I (14_augmented_analytics_bonus_pack.sql): individua autonomamente il cambio di regime nei rimborsi giornalieri (media salita a €1.805/giorno, picco €2.714). |
| **14** | `ML.TREND & ML.SEASONALITY` | Augmented Analytics TVFs (Decomposition) | `BigQuery Time-Series Decomposition Engine` | Decompongono qualsiasi serie storica nella sua traiettoria secolare di fondo (ML.TREND, con proiezione futura ... | Lab I (14_augmented_analytics_bonus_pack.sql): separa il trend di crescita dei resi (€1.762/gg) dal ciclo settimanale (+€1.95 il martedì vs -€2.03 il mercoledì). |
| **15** | `ML.CORRELATION` | Augmented Analytics TVF (Statistica) | `BigQuery Statistical Correlation Engine` | Calcola automaticamente i coefficienti di correlazione lineare (Pearson) o di rango (Spearman) tra una variabi... | Lab I (14_augmented_analytics_bonus_pack.sql): dimostra su 5.015 clienti che i resi correlano fortemente con i rimborsi (0.852) ma debolmente con gli ordini (0.290). |
| **16** | `PROPERTY GRAPH & GQL` | Native ISO/IEC 39075 GQL Graph | `BigQuery Property Graph (Zero-Copy)` | Definisce una vista a grafo zero-copy sopra le normali tabelle relazionali BigQuery e permette di interrogarla... | Lab I (03_property_graph.sql, 04_ring_detection.sql, 05_graph_exploration_queries.sql): scopre i 3 Fraud Ring (RING-1, RING-2, RING-3) e il Loyalty Laundering. |

---

## Parte 2: Declinazione per Funzione & 6 Verticali d'Industria

### Slide 6: `AI.IF` — AI.IF — Filtro Semantico & Semantic Join
* **Categoria:** Generative SQL (Booleano)  |  **Motore:** `Gemini 3.8 Flash · MINIMIZE_COST`
* **Descrizione Generale:** Valuta una condizione in linguaggio naturale su testo o dati multimodali restituendo un BOOL direttamente in WHERE, SELECT o nella clausola ON di un JOIN semantico. Con optimization_mode => 'MINIMIZE_COST', BigQuery distilla automaticamente un modello leggero riducendo costi e latenza su milioni di righe.
* **Sintassi SQL di Riferimento:**
  ```sql
  WHERE AI.IF(('Condition: ', col), connection_id => 'eu.vertex_ai_conn', optimization_mode => 'MINIMIZE_COST')  |  JOIN t2 ON AI.IF(...)
  ```
* **Utilizzo nel Workshop:** Lab II (02_quick_triage.sql & 07_key_drivers_and_ai_agg_enhancements.sql): filtro recensioni difettose e Semantic JOIN tra bollettini tecnici e reclami.

| Verticale | Use Case Specifico | Dati / Input | Azione SQL & Impatto di Business |
|---|---|---|---|
| **Banking / Finance** | **Screening AML & Pagamenti Sospetti** | Causali bonifici SWIFT, note compliance e liste sanzioni. | Filtra causali ambigue che mascherano triangolazioni off-shore e fa Semantic JOIN tra alert AML e normative. |
| **Retail & Consumer** | **Moderazione Resi & Policy Match** | Motivazioni di reso clienti, note magazzino e policy di garanzia. | Isola i reclami che indicano merce contraffatta o usata (wardrobing) e unisce semanticamente resi e clausole fornitore. |
| **Pharma & Life Sciences** | **Farmacovigilanza & Eventi Avversi** | Diari clinici dei pazienti, segnalazioni mediche e foglietti illustrativi. | Filtra in tempo reale le note che descrivono reazioni avverse gravi (SAE) e le incrocia con i rischi noti per principio attivo. |
| **Manufacturing** | **Correlazione Bollettini Tecnici (CAPA)** | Recensioni post-vendita, ticket assistenza e Engineering Bulletins. | Esegue JOIN semantico (ON AI.IF) tra sintomi descritti dai clienti ('acqua tiepida a 70°C') e difetti noti di fabbrica. |
| **Public Sector** | **Ammissibilità Bandi & Triage Esposti** | Domande di contributo PNRR, PEC dei cittadini e requisiti di bando. | Verifica automaticamente in WHERE se la descrizione del progetto soddisfa i criteri di ammissibilità normativa. |
| **Telco & Media** | **Filtro Disservizi Critici & SLA B2B** | Trascrizioni chiamate 187/191, ticket NOC e contratti SLA enterprise. | Individua reclami che implicano isolamento totale di sede o minaccia AGCOM/Corecom, attivando fast-track. |

---

### Slide 7: `AI.CLASSIFY` — AI.CLASSIFY — Tassonomia Zero-Shot Multi-Classe
* **Categoria:** Generative SQL (Tassonomico)  |  **Motore:** `Gemini 3.8 Flash · MINIMIZE_COST`
* **Descrizione Generale:** Assegna ogni record non strutturato a una categoria esatta scelta da un array predefinito, senza esempi di addestramento (zero-shot). Utilizzabile direttamente in SELECT e GROUP BY per costruire cubi OLAP su dati testuali liberi.
* **Sintassi SQL di Riferimento:**
  ```sql
  AI.CLASSIFY(text_col, categories => ['cat_A', 'cat_B', 'cat_C'], connection_id => 'eu.vertex_ai_conn', optimization_mode => 'MINIMIZE_COST')
  ```
* **Utilizzo nel Workshop:** Lab II (02_quick_triage.sql): classificazione istantanea dei difetti in ['heating_failure', 'water_leak', 'electrical_fault', 'mechanical_wear', 'cosmetic'].

| Verticale | Use Case Specifico | Dati / Input | Azione SQL & Impatto di Business |
|---|---|---|---|
| **Banking / Finance** | **Routing Reclami & Dispute Carte** | Ticket home banking, moduli di chargeback e PEC reclami. | Classifica in ['frode_non_autorizzata', 'doppia_contabilizzazione', 'merce_non_consegnata', 'errore_ATM'] per smistamento. |
| **Retail & Consumer** | **Categorizzazione Motivi di Reso** | Testo libero dei resi e-commerce e chat customer care. | Raggruppa in ['taglia_errata', 'difetto_fabbrica', 'danneggiato_corriere', 'ripensamento', 'sospetto_wardrobing']. |
| **Pharma & Life Sciences** | **Triage Medical Information & Trial** | Quesiti di medici/pazienti e note di arruolamento trial clinici. | Smista le richieste in ['posologia', 'interazione_farmacologica', 'evento_avverso', 'difetto_packaging', 'off_label']. |
| **Manufacturing** | **Tassonomia Guasti sul Campo** | Log tecnici di manutenzione, ticket garanzia e recensioni clienti. | Classifica i guasti per famiglia tecnica ('deriva_termica', 'perdita_idraulica', 'usura_meccanica', 'corto_elettrico'). |
| **Public Sector** | **Smistamento Automatico PEC & URP** | Flussi PEC in ingresso, segnalazioni civiche e istanze FOIA. | Instrada al dipartimento competente: ['tributi_imu', 'edilizia_urbanistica', 'anagrafe', 'manutenzione_stradale', 'contenzioso']. |
| **Telco & Media** | **Root-Cause Ticket di Rete & Churn** | Note di contatto call center e feedback di disdetta (churn survey). | Classifica in ['copertura_5G_assente', 'degrado_fibra_FTTH', 'contestazione_fattura', 'offerta_competitor', 'guasto_modem']. |

---

### Slide 8: `AI.SCORE` — AI.SCORE — Scoring Semantico & Ranking Dinamico
* **Categoria:** Generative SQL (Ranking)  |  **Motore:** `Gemini 3.8 Flash (Managed Scoring)`
* **Descrizione Generale:** Assegna un punteggio numerico continuo (FLOAT64) a ogni riga in base a una rubrica qualitativa espressa in linguaggio naturale. Ideale in ORDER BY per ordinare code di lavoro, prioritizzare escalation e filtrare i casi a maggior rischio.
* **Sintassi SQL di Riferimento:**
  ```sql
  SELECT *, AI.SCORE(('Rate severity from 1 to 5: ', text_col), connection_id => 'eu.vertex_ai_conn') AS risk_score ORDER BY risk_score DESC
  ```
* **Utilizzo nel Workshop:** Lab I (13_timesfm_and_ai_agg_enhancements.sql) & Lab II (02_quick_triage.sql): ranking per minaccia chargeback (score 5.0) e rischio sicurezza elettrica/incendio.

| Verticale | Use Case Specifico | Dati / Input | Azione SQL & Impatto di Business |
|---|---|---|---|
| **Banking / Finance** | **Prioritizzazione Alert Antiriciclaggio** | Narrativa SAR (Suspicious Activity Report) e note KYC. | Assegna uno score 1-100 di urgenza investigativa in base a indicatori di evasione sanzioni o PEP exposure. |
| **Retail & Consumer** | **Escalation Minacce Chargeback & VIP** | Conversazioni chat, email di reclamo e note dell'operatore. | Ordina la coda antifrode per aggressività, minaccia legale/chargeback o comportamento da script organizzato. |
| **Pharma & Life Sciences** | **Gravità Clinica Segnalazioni Pazienti** | Descrizioni spontanee di sintomi post-somministrazione. | Valuta la criticità clinica (ospedalizzazione, pericolo di vita, reazione anafilattica) per revisione medica immediata. |
| **Manufacturing** | **Safety & Fire Hazard Triage** | Recensioni consumatori e report di assistenza tecnica. | Assegna il punteggio massimo (5/5) a segnalazioni con fumo, scintille, odore di bruciato o perdite vicino a prese elettriche. |
| **Public Sector** | **Urgenza Interventi Protezione Civile** | Segnalazioni cittadini, chiamate di emergenza e verbali ispettivi. | Ordina le richieste di intervento per pericolo per l'incolumità pubblica (cedimenti strutturali, allagamenti, scuole). |
| **Telco & Media** | **Propensione al Churn da Sentiment** | Trascrizioni chiamate di supporto e reclami social/app. | Calcola un punteggio di frustrazione e intenzione di migrazione operatore per innescare retention immediata. |

---

### Slide 9: `AI.GENERATE` — AI.GENERATE — Estrazione Strutturata & Dossier
* **Categoria:** Generative SQL (Structured Output & Text)  |  **Motore:** `Gemini 3.8 Flash · output_schema`
* **Descrizione Generale:** Trasforma testo libero o oggetti multimodali in uno STRUCT tipizzato BigQuery conforme a output_schema (oppure genera report narrativi). Converte istantaneamente note, contratti e recensioni in colonne SQL interrogabili con JOIN e aggregazioni.
* **Sintassi SQL di Riferimento:**
  ```sql
  AI.GENERATE(prompt => ..., connection_id => 'eu.vertex_ai_conn', endpoint => 'gemini-3.8-flash', output_schema => 'field1 STRING, field2 BOOL')
  ```
* **Utilizzo nel Workshop:** Lab I (08_notes_extraction.sql, 09_case_summaries.sql, 10_catalog_enrichment.sql) & Lab II (03_async_enrichment_pipeline.sql, 05_executive_summary.sql).

| Verticale | Use Case Specifico | Dati / Input | Azione SQL & Impatto di Business |
|---|---|---|---|
| **Banking / Finance** | **Parsing Contratti di Mutuo & Bilanci** | Delibere di credito, perizie immobiliari e note integrative. | Estrae output_schema => 'covenant_type STRING, max_ltv FLOAT64, guarantor_required BOOL, risk_clause STRING'. |
| **Retail & Consumer** | **Estrazione Segnali Frode & Catalogo** | Note degli agenti sui resi e descrizioni merceologiche. | Estrae claimed_issue, product_condition, refund_pressure, coordination_signal e arricchisce il catalogo con return_risk. |
| **Pharma & Life Sciences** | **Strutturazione Cartelle Cliniche (EHR)** | Referti di dimissione ospedaliera e note oncologiche. | Estrae primary_diagnosis, biomarker_status, dosage_mg, adverse_event_grade, follow_up_days in colonne analitiche. |
| **Manufacturing** | **Estrazione Sintomi & Lotti da Recensioni** | Recensioni e-commerce, email di garanzia e log di riparazione. | Estrae is_defect_report BOOL, defect_category STRING, failure_mode STRING, suspected_component STRING, severity STRING. |
| **Public Sector** | **Estrazione Dati da Atti & Determinazioni** | Delibere comunali, bandi di gara e verbali di accertamento. | Estrae cig_code STRING, importo_euro FLOAT64, ente_beneficiario STRING, scadenza_giorni INT64, obbligo_pnrr BOOL. |
| **Telco & Media** | **Analisi Strutturata Chiamate & Field Log** | Trascrizioni IVR/call center e note dei tecnici on-site. | Estrae fault_location, cpe_model, promised_compensation_eur, technician_dispatch_needed BOOL, sentiment_score INT64. |

---

### Slide 10: `AI.GENERATE_BOOL` — AI.GENERATE_BOOL / INT / DOUBLE — Scalari Tipizzati
* **Categoria:** Generative SQL (Scalare Tipizzato)  |  **Motore:** `Gemini 3.8 Flash · Stored Procedure Batch`
* **Descrizione Generale:** Famiglia di funzioni scalari (AI.GENERATE_BOOL, AI.GENERATE_INT, AI.GENERATE_DOUBLE) che restituiscono un singolo valore primitivo tipizzato più lo stato diagnostico (ai.result, ai.status). Ideali in Stored Procedure incrementali con retry automatico su errori 429.
* **Sintassi SQL di Riferimento:**
  ```sql
  AI.GENERATE_BOOL(prompt => CONCAT('Is this return abusive? ', notes), connection_id => 'eu.vertex_ai_conn', endpoint => 'gemini-3.8-flash')
  ```
* **Utilizzo nel Workshop:** Lab I (07_async_scoring_batch.sql & 12_simulate_new_returns.sql): scoring incrementale con ciclo REPEAT...UNTIL che intercetta 10/10 nuovi resi fraudolenti.

| Verticale | Use Case Specifico | Dati / Input | Azione SQL & Impatto di Business |
|---|---|---|---|
| **Banking / Finance** | **Validazione Automatica KYC / KYB** | Documenti camerali, dichiarazioni antiriciclaggio e note analista. | Restituisce is_high_risk_entity BOOL e estimated_annual_turnover DOUBLE in pipeline notturne di onboarding. |
| **Retail & Consumer** | **Scoring Asincrono Resi E-Commerce** | Coda resi giornalieri (return_reason_text + agent_notes). | Popola la tabella returns_scored con is_suspicious BOOL e gestisce automaticamente i picchi di traffico post-Black Friday. |
| **Pharma & Life Sciences** | **Controllo Eleggibilità Pazienti Trial** | Criteri di inclusione/esclusione e anamnesi testuale del paziente. | Valuta is_eligible BOOL e months_since_diagnosis INT64 su migliaia di profili candidati allo studio clinico. |
| **Manufacturing** | **Gate Automatico di Richiamo (RMA)** | Moduli RMA dei distributori e descrizioni guasto in garanzia. | Determina is_warranty_covered BOOL e estimated_repair_hours DOUBLE prima di autorizzare la sostituzione. |
| **Public Sector** | **Controllo Conformità Formale Pratiche** | Allegati testuali di pratiche edilizie (SCIA/CILA) e appalti. | Restituisce is_compliant BOOL e missing_documents_count INT64 per pre-istruttoria automatizzata. |
| **Telco & Media** | **Qualifica Automatica Lead & Indennizzi** | Richieste di rimborso SLA e note commerciali B2B. | Valuta is_sla_breach_valid BOOL e recommended_credit_eur DOUBLE nella coda di billing assurance. |

---

### Slide 11: `AI.AGG` — AI.AGG — Aggregazione Semantica in GROUP BY
* **Categoria:** Generative SQL (Semantic Aggregate)  |  **Motore:** `Gemini 3.8 Flash (1M Token Context)`
* **Descrizione Generale:** Funzione di aggregazione nativa SQL (come SUM o COUNT) che combina centinaia o migliaia di testi all'interno di ciascuna partizione GROUP BY sfruttando l'ampia finestra di contesto di Gemini, senza dover concatenare manualmente stringhe con STRING_AGG.
* **Sintassi SQL di Riferimento:**
  ```sql
  SELECT group_col, AI.AGG(STRUCT(col1, col2), 'Synthesize common pattern and 1 action', connection_id => 'eu.vertex_ai_conn') GROUP BY group_col
  ```
* **Utilizzo nel Workshop:** Lab I (13_timesfm_and_ai_agg_enhancements.sql) & Lab II (07_key_drivers_and_ai_agg_enhancements.sql): sintesi Modus Operandi per Fraud Ring e Quality Brief per SKU.

| Verticale | Use Case Specifico | Dati / Input | Azione SQL & Impatto di Business |
|---|---|---|---|
| **Banking / Finance** | **Dossier Investigativo per Rete AML** | Tutte le transazioni e note di un cluster di conti sospetti (GROUP BY ring_id). | Genera la narrativa SAR pronta per UIF/Banca d'Italia sintetizzando il pattern di riciclaggio dell'intero gruppo. |
| **Retail & Consumer** | **Sintesi Modus Operandi Fraud Ring** | Motivazioni di reso e note operatore raggruppate per ring_id o SKU. | Produce in 2 frasi il Modus Operandi (es. Empty-Box, Wardrobing, Loyalty Cycling) e l'azione di blocco immediata. |
| **Pharma & Life Sciences** | **Sintesi Sicurezza per Lotto / Studio** | Segnalazioni di farmacovigilanza raggruppate per principio attivo o sito. | Riassume il profilo di tollerabilità emergente e le raccomandazioni per il Data Safety Monitoring Board. |
| **Manufacturing** | **Bollettino Qualità per SKU e Fornitore** | Tutte le recensioni difettose raggruppate per sku o lot_id. | Genera una sintesi ingegneristica del sintomo dominante (es. perdita guarnizione base CM-350) e il pezzo da ispezionare. |
| **Public Sector** | **Sintesi Consultazioni Pubbliche & URP** | Migliaia di osservazioni di cittadini/imprese raggruppate per tema o municipio. | Produce il report esecutivo delle criticità territoriali più segnalate per la Giunta o il Ministero. |
| **Telco & Media** | **Post-Mortem Outage per Cella / Area** | Ticket di disservizio e log tecnici raggruppati per cell_tower_id o provincia. | Sintetizza l'impatto percepito dai clienti e la causa tecnica prevalente per la cabina di regia NOC. |

---

### Slide 12: `AI.SIMILARITY` — AI.SIMILARITY — Cosine Similarity Zero-DDL
* **Categoria:** Vector & Embedding SQL  |  **Motore:** `Vertex AI text-embedding-005`
* **Descrizione Generale:** Genera al volo gli embedding vettoriali dei due testi tramite text-embedding-005 e restituisce la similarità coseno (-1.0 a 1.0) in una singola espressione SQL, senza dover creare tabelle di embedding o indici vettoriali dedicati.
* **Sintassi SQL di Riferimento:**
  ```sql
  AI.SIMILARITY(content1 => col_a, content2 => 'Reference text', connection_id => 'eu.vertex_ai_conn', endpoint => 'text-embedding-005')
  ```
* **Utilizzo nel Workshop:** Lab I (13_timesfm_and_ai_agg_enhancements.sql) & Lab II (07_key_drivers_and_ai_agg_enhancements.sql): caccia a script fraudolenti (0.840) e ricerca reclami gemelli (0.870).

| Verticale | Use Case Specifico | Dati / Input | Azione SQL & Impatto di Business |
|---|---|---|---|
| **Banking / Finance** | **Phishing & Script di Social Engineering** | Messaggi di contestazione bonifici istantanei vs template di truffa noti. | Individua con score > 0.85 i reclami generati dallo stesso script di social engineering (Authorized Push Payment fraud). |
| **Retail & Consumer** | **Anti-Copycat & Scripted Refund Claims** | Motivazioni di reso clienti vs archetipo di reclamo fraudolento noto. | Smaschera account formalmente indipendenti che usano variazioni parafrasate dello stesso copione 'pacco vuoto'. |
| **Pharma & Life Sciences** | **Ricerca Casi Clinici Simili** | Note cliniche di un paziente complesso vs database di casi rari risolti. | Recupera i casi storici con sintomatologia semanticamente più vicina anche quando cambia la terminologia medica. |
| **Manufacturing** | **Ricerca Reclami Gemelli per Difetto** | Descrizione di un nuovo guasto vs archivio storico di 100k recensioni/ticket. | Trova istantaneamente tutti i casi analoghi ('smette di scaldare dopo 2 settimane') per misurare l'ampiezza del lotto. |
| **Public Sector** | **Deduplicazione Segnalazioni & Precedenti** | Nuovo ricorso amministrativo o quesito fiscale vs banca dati pareri/sentenze. | Identifica i precedenti giurisprudenziali o le risposte interpello semanticamente sovrapponibili. |
| **Telco & Media** | **Matching Ticket NOC & Incidenti Storici** | Descrizione sintomo di rete attuale vs Knowledge Base di post-mortem. | Suggerisce al tecnico il workaround applicato sull'incidente storico con similarità semantica più elevata. |

---

### Slide 13: `AI.FORECAST` — AI.FORECAST — Previsione Zero-Shot TimesFM 3.0
* **Categoria:** Time-Series Foundation Model  |  **Motore:** `Google Research TimesFM 3.0 (Multivariate)`
* **Descrizione Generale:** Proietta nel futuro serie storiche univariate (data_col) o multivariate correlate (target_cols + past_covariate_cols / future_covariate_cols) invocando il Foundation Model pre-addestrato TimesFM 3.0. Zero CREATE MODEL, risultati in ~2 secondi.
* **Sintassi SQL di Riferimento:**
  ```sql
  SELECT * FROM AI.FORECAST(TABLE metrics, model => 'TimesFM 3.0', target_cols => ['metric_a', 'metric_b'], past_covariate_cols => ['cov'], timestamp_col => 'ts', horizon => 8)
  ```
* **Utilizzo nel Workshop:** Lab I (13_timesfm_and_ai_agg_enhancements.sql) & Lab II (07_key_drivers_and_ai_agg_enhancements.sql): forecast multivariato di rimborsi/resi e difetti giornalieri con TimesFM 3.0.

| Verticale | Use Case Specifico | Dati / Input | Azione SQL & Impatto di Business |
|---|---|---|---|
| **Banking / Finance** | **Previsione Liquidità ATM & Flussi Cassa** | Serie storica prelievi/versamenti giornalieri per filiale e sportello ATM. | Prevede il fabbisogno di contante a 14 giorni con intervallo al 95%, ottimizzando i costi di trasporto valori. |
| **Retail & Consumer** | **Forecast Domanda & Esposizione Resi** | Vendite e rimborsi settimanali per categoria merceologica e canale. | Stima congiuntamente volumi di reso ed esposizione € (target_cols) e il fabbisogno logistico di reverse supply chain. |
| **Pharma & Life Sciences** | **Domanda Farmaci Stagionali & Vaccini** | Dispensazioni settimanali per regione e classe terapeutica (ATC). | Prevede i picchi di richiesta a 8-12 settimane per prevenire carenze di stock (drug shortages) negli ospedali. |
| **Manufacturing** | **Previsione Fabbisogno Ricambi & Difetti** | Difetti giornalieri, recensioni critiche e volume totale per linea prodotto. | Proietta congiuntamente difetti e reclami critici usando il volume vendite come covariata (past_covariate_cols). |
| **Public Sector** | **Pianificazione Accessi PS e Sportelli** | Serie storica giornaliera di accessi PS, prenotazioni CUP e pratiche. | Prevede i volumi di accesso nelle 4 settimane successive per dimensionare turni medici e sportelli al cittadino. |
| **Telco & Media** | **Capacity Planning Traffico 5G / Fibra** | Throughput orario/settimanale (Gbps) per cella radio e nodo ottico. | Individua in anticipo i nodi che supereranno l'80% di capacità entro 8 settimane per pianificare gli upgrade. |

---

### Slide 14: `AI.DETECT_ANOMALIES` — AI.DETECT_ANOMALIES — Anomalie Zero-Shot TimesFM 3.0
* **Categoria:** Time-Series Foundation Model  |  **Motore:** `Google Research TimesFM 3.0 (Zero-Shot)`
* **Descrizione Generale:** Confronta una finestra storica di baseline con una finestra di ispezione usando TimesFM 3.0, calcolando i limiti attesi (lower_bound, upper_bound) e la probabilità di anomalia (anomaly_probability) senza addestrare modelli ARIMA dedicati.
* **Sintassi SQL di Riferimento:**
  ```sql
  SELECT * FROM AI.DETECT_ANOMALIES(TABLE baseline_hist, TABLE target_window, model => 'TimesFM 3.0', data_col => 'val', timestamp_col => 'ts', anomaly_prob_threshold => 0.80)
  ```
* **Utilizzo nel Workshop:** Lab I (13_timesfm_and_ai_agg_enhancements.sql) & Lab II (07_key_drivers_and_ai_agg_enhancements.sql): rileva le settimane di attacco di Ring C (p=0.973) e il picco di guasti dopo l'ingresso di HE-4471.

| Verticale | Use Case Specifico | Dati / Input | Azione SQL & Impatto di Business |
|---|---|---|---|
| **Banking / Finance** | **Rilevamento Spike Frodi Carte & Bonifici** | Volumi orari di transazioni e-commerce per merchant o corridoio estero. | Intercetta attacchi BIN/carding o anomalie di esfiltrazione fondi non appena superano la banda predittiva TimesFM 3.0. |
| **Retail & Consumer** | **Allerta Precoce Ondate di Abuso Resi** | Rimborsi settimanali per categoria prodotto, corriere o CAP. | Isola in pochi secondi le settimane in cui un anello organizzato colpisce l'elettronica d'alto valore (p > 0.95). |
| **Pharma & Life Sciences** | **Sorveglianza Sindromica & Cold-Chain** | Telemetria temperatura frigo-emoteche e volumi di vendita antipiretici. | Segnala escursioni termiche anomale nella catena del freddo o focolai epidemici nascenti a livello provinciale. |
| **Manufacturing** | **Anomalie Scarti di Linea & Reclami** | Tasso giornaliero di reclami difettosi e assorbimento elettrico stazioni (CAL-02). | Rileva l'impennata di guasti sul campo dopo il 16 luglio (lotto HE-4471) rispetto alla baseline di inizio mese. |
| **Public Sector** | **Monitoraggio Spesa Pubblica & Consumi** | Fatturazione mensile per capitolo di spesa, ASL o utenze edifici pubblici. | Segnala automaticamente picchi anomali di spesa farmaceutica convenzionata o perdite occulte nelle reti idriche. |
| **Telco & Media** | **Degrado Cella & Picchi di Chiamate** | Tasso di caduta chiamata (Drop Call Rate) e latenza per stazione radio base. | Identifica celle con degrado anomalo post-aggiornamento firmware prima dell'apertura massiva di ticket clienti. |

---

### Slide 15: `AI.EVALUATE` — AI.EVALUATE — Backtesting & Validazione TimesFM 3.0
* **Categoria:** Time-Series Foundation Model (Governance)  |  **Motore:** `Google Research TimesFM 3.0 (Zero-Shot Eval)`
* **Descrizione Generale:** Valida scientificamente l'accuratezza previsiva zero-shot di TimesFM 3.0 su una finestra di holdout storica, calcolando MAE, MSE, RMSE, MAPE e sMAPE in una sola query SQL. Essenziale per la Model Governance prima di mettere i forecast in produzione.
* **Sintassi SQL di Riferimento:**
  ```sql
  SELECT mean_absolute_error, root_mean_squared_error, mean_absolute_percentage_error FROM AI.EVALUATE(TABLE train_split, TABLE actuals_split, model => 'TimesFM 3.0', data_col => 'v', timestamp_col => 'ts')
  ```
* **Utilizzo nel Workshop:** Lab I (13_timesfm_and_ai_agg_enhancements.sql) & Lab II (07_key_drivers_and_ai_agg_enhancements.sql): certifica TimesFM 3.0 sui resi (MAPE = 14.49%) e sul volume giornaliero di recensioni.

| Verticale | Use Case Specifico | Dati / Input | Azione SQL & Impatto di Business |
|---|---|---|---|
| **Banking / Finance** | **Model Risk Management (SR 11-7 / EBA)** | Storico flussi di tesoreria e split di validazione out-of-time. | Certifica trimestralmente MAPE e RMSE dei modelli di liquidità per gli audit interni e di vigilanza bancaria. |
| **Retail & Consumer** | **Benchmarking Accuratezza Demand Plan** | Vendite storiche vs finestra di test pre-stagione saldi. | Misura il MAPE per singola categoria e negozio per calibrare le scorte di sicurezza (safety stock) in modo oggettivo. |
| **Pharma & Life Sciences** | **Validazione Arruolamento Trial Clinici** | Curva storica di reclutamento pazienti vs mesi di holdout. | Verifica l'affidabilità delle proiezioni di chiusura studio clinico prima di allocare nuovi centri ospedalieri. |
| **Manufacturing** | **Certificazione Piani S&OP e Qualità** | Storico giornaliero volumi recensioni/ticket e consumi ricambi su holdout. | Quantifica l'errore medio assoluto (MAE = 0.72 recensioni/giorno) per validare i modelli di qualità post-vendita. |
| **Public Sector** | **Validazione Stime Gettito & Bilancio** | Serie storiche entrate tributarie/tariffe vs consuntivo trimestrale. | Documenta con metriche trasparenti (MAPE/sMAPE) l'attendibilità delle proiezioni di bilancio preventivo. |
| **Telco & Media** | **Audit Previsioni Traffico & Roaming** | Traffico storico pre-estate vs consuntivo mesi estivi. | Valuta la precisione del modello zero-shot sulle località turistiche ad alta variabilità stagionale. |

---

### Slide 16: `AI.KEY_DRIVERS` — AI.KEY_DRIVERS — Root-Cause & Contribution Analysis
* **Categoria:** Augmented Analytics TVF  |  **Motore:** `BigQuery Automated Contribution Engine`
* **Descrizione Generale:** Esplora automaticamente tutte le combinazioni dimensionali (singole e incrociate) per isolare i segmenti che spiegano statisticamente la variazione di una metrica tra un gruppo di interesse e il gruppo di riferimento (lift relativo e differenza inattesa).
* **Sintassi SQL di Riferimento:**
  ```sql
  SELECT * FROM AI.KEY_DRIVERS(TABLE joined_data, metric_col => 'defect_metric', dimension_cols => ['component_type', 'supplier'], interest_label_col => 'is_suspect')
  ```
* **Utilizzo nel Workshop:** Lab I (14_augmented_analytics_bonus_pack.sql) & Lab II (07_key_drivers_and_ai_agg_enhancements.sql): isola ['component_type=heating_element', 'supplier=ThermoCore'].

| Verticale | Use Case Specifico | Dati / Input | Azione SQL & Impatto di Business |
|---|---|---|---|
| **Banking / Finance** | **Driver di Deterioramento Credito (NPL)** | Portafoglio prestiti con dimensioni: settore ATECO, area geografica, canale, rating. | Isola in un secondo quale combinazione (es. micro-imprese edilizia Nord-Ovest) guida l'aumento dei default. |
| **Retail & Consumer** | **Analisi Cause Picco Resi & Calo Margine** | Transazioni con dimensioni: categoria, brand, corriere, metodo pagamento, segmento. | Scopre automaticamente i segmenti che trainano l'anomalia di rimborso durante il picco di Q4. |
| **Pharma & Life Sciences** | **Cause di Scostamento Resa Bioreattori** | Lotti produttivi con dimensioni: fornitore eccipienti, linea, turno, impianto. | Identifica il fattore combinato che riduce la purezza o la resa chimica di un principio attivo. |
| **Manufacturing** | **Root-Cause Difettosità Componenti (BOM)** | Join tra recensioni AI, distinta base (BOM), lotti fornitori e macchine. | Dimostra matematicamente che l'impennata dei guasti (+1600%) dipende da heating_element + ThermoCore su CAL-02. |
| **Public Sector** | **Determinanti Tempi di Attesa Sanità / PA** | Tempi di erogazione prestazioni per ASL, specialità, fascia oraria, distretto. | Individua i colli di bottiglia specifici che spiegano l'allungamento delle liste d'attesa regionali. |
| **Telco & Media** | **Driver di Degrado NPS & Disdette Fibra** | Sondaggi NPS e disdette per tecnologia (FTTH/FTTC), vendor ONT, regione, piano. | Isola la combinazione esatta (es. specifico firmware router + area metropolitana) responsabile del calo NPS. |

---

### Slide 17: `AI.CAUSAL_EFFECT` — AI.CAUSAL_EFFECT — Inferenza Causale Bayesiana
* **Categoria:** Augmented Analytics TVF (Causal AI)  |  **Motore:** `Bayesian Structural Time-Series (Counterfactual)`
* **Descrizione Generale:** Stima l'effetto causale netto di un evento o intervento costruendo un controfattuale sintetico Bayesiano di ciò che sarebbe accaduto in assenza dell'evento. Restituisce impatto assoluto, lift relativo, p-value e probabilità causale.
* **Sintassi SQL di Riferimento:**
  ```sql
  SELECT prob_causal_effect, p_value, absolute_effect, relative_effect FROM AI.CAUSAL_EFFECT(TABLE ts, data_col => 'y', timestamp_col => 'ts', intervention_timestamp => TIMESTAMP '2025-11-15')
  ```
* **Utilizzo nel Workshop:** Lab I (14_augmented_analytics_bonus_pack.sql): quantifica l'impatto netto dell'ondata di frode dal 15 Nov 2025 in +€75.489 (+19.9% sul controfattuale).

| Verticale | Use Case Specifico | Dati / Input | Azione SQL & Impatto di Business |
|---|---|---|---|
| **Banking / Finance** | **Impatto Netto Regole Antifrode / 3DS** | Serie storica frodi e conversioni prima e dopo il rilascio di una regola 3D Secure. | Misura il risparmio netto di frodi evitato al netto del trend stagionale dei pagamenti digitali. |
| **Retail & Consumer** | **Danno Netto Frodi vs Lift Promozionale** | Serie storica rimborsi o ricavi con timestamp di inizio campagna o attacco. | Separa la fisiologica crescita del Black Friday dal danno causale puro (+€75.489) generato dai fraud ring. |
| **Pharma & Life Sciences** | **Efficacia Campagne Aderenza Terapeutica** | Tasso di rinnovo prescrizioni prima e dopo il lancio di un programma di supporto. | Quantifica l'incremento reale di aderenza terapeutica attribuibile al programma paziente (p-value e lift %). |
| **Manufacturing** | **Impatto Ricalibrazione Linea Produttiva** | Tasso di difettosità giornaliero prima e dopo la manutenzione straordinaria. | Certifica la riduzione causale degli scarti post-intervento tecnico sulla stazione di assemblaggio. |
| **Public Sector** | **Valutazione Impatto Politiche Pubbliche** | Incidentalità stradale o tempi di pagamento PA prima e dopo una riforma. | Fornisce alla Corte dei Conti / decisori la misura rigorosa dell'effetto netto dell'intervento normativo. |
| **Telco & Media** | **Ritorno Netto Campagne Retention 5G** | ARPU e tasso di churn prima e dopo l'attivazione dell'upgrade automatico 5G. | Quantifica i ricavi incrementali netti generati dall'iniziativa rispetto alla baseline controfattuale. |

---

### Slide 18: `ML.DETECT_CHANGE_POINTS` — ML.DETECT_CHANGE_POINTS — Rotture di Regime
* **Categoria:** Augmented Analytics TVF (Time-Series)  |  **Motore:** `BigQuery Structural Break Detection`
* **Descrizione Generale:** Scansiona una serie storica per individuare automaticamente i punti esatti in cui il livello medio o il regime statistico subisce un cambiamento strutturale persistente (step change), restituendo durata e statistiche di ciascun regime.
* **Sintassi SQL di Riferimento:**
  ```sql
  SELECT begin_timestamp, end_timestamp, metrics.avg, metrics.max FROM ML.DETECT_CHANGE_POINTS(TABLE daily_series, data_col => 'val', timestamp_col => 'dt')
  ```
* **Utilizzo nel Workshop:** Lab I (14_augmented_analytics_bonus_pack.sql): individua autonomamente il cambio di regime nei rimborsi giornalieri (media salita a €1.805/giorno, picco €2.714).

| Verticale | Use Case Specifico | Dati / Input | Azione SQL & Impatto di Business |
|---|---|---|---|
| **Banking / Finance** | **Cambio di Regime Spread & Volumi** | Serie storiche di volumi transati, tassi di default o costi di raccolta. | Individua la data esatta in cui il mercato o il portafoglio crediti è entrato in un nuovo regime di rischio. |
| **Retail & Consumer** | **Inizio Silenzioso di un Attacco** | Rimborsi giornalieri o tasso di reso per centro logistico. | Trova il giorno preciso in cui la baseline dei resi si è spostata verso l'alto, anche senza un singolo spike estremo. |
| **Pharma & Life Sciences** | **Drift di Processo nei Lotti Farmaceutici** | Parametri continui di fermentazione, pH o pressione nelle camere bianche. | Identifica il momento esatto in cui il processo produttivo ha subito uno shift di baseline (process drift). |
| **Manufacturing** | **Degrado post-Cambio Lotto o Utensile** | Vibrazioni, temperature di saldatura o difettosità giornaliera di fabbrica. | Rivela che il regime di guasto è cambiato esattamente il giorno di introduzione del lotto HE-4471. |
| **Public Sector** | **Cambi di Regime in Servizi e Spesa** | Domande di servizi sociali, consumi energetici comunali o accessi portali. | Evidenzia discontinuità strutturali permanenti nei bisogni dei cittadini per riallocare i budget. |
| **Telco & Media** | **Step-Change di Latenza post-Routing** | Latenza media RTT e packet loss sui collegamenti di backbone IP. | Individua il timestamp esatto in cui un cambio di configurazione BGP ha innalzato stabilmente la latenza. |

---

### Slide 19: `ML.TREND & ML.SEASONALITY` — ML.TREND & ML.SEASONALITY — Decomposizione
* **Categoria:** Augmented Analytics TVFs (Decomposition)  |  **Motore:** `BigQuery Time-Series Decomposition Engine`
* **Descrizione Generale:** Decompongono qualsiasi serie storica nella sua traiettoria secolare di fondo (ML.TREND, con proiezione futura e correzione degli step-change) e nelle componenti cicliche settimanali/annuali (ML.SEASONALITY), isolando il segnale vero dal rumore.
* **Sintassi SQL di Riferimento:**
  ```sql
  SELECT * FROM ML.TREND(TABLE ts, data_col => 'v', timestamp_col => 'dt', horizon => 7, adjust_step_changes => TRUE)  |  ML.SEASONALITY(...)
  ```
* **Utilizzo nel Workshop:** Lab I (14_augmented_analytics_bonus_pack.sql): separa il trend di crescita dei resi (€1.762/gg) dal ciclo settimanale (+€1.95 il martedì vs -€2.03 il mercoledì).

| Verticale | Use Case Specifico | Dati / Input | Azione SQL & Impatto di Business |
|---|---|---|---|
| **Banking / Finance** | **Ciclo Stipendi vs Trend Impieghi** | Flussi di cassa sui conti correnti e volumi di spesa carte di credito. | Separa la stagionalità mensile (giorno 27 / scadenze fiscali) dal trend reale di crescita o contrazione dei consumi. |
| **Retail & Consumer** | **Staffing Magazzino Resi vs Trend** | Arrivi giornalieri di pacchi resi nei centri di distribuzione. | Quantifica l'effetto giorno-della-settimana per pianificare i turni e isola il trend strutturale di lungo periodo. |
| **Pharma & Life Sciences** | **Stagionalità Patologie vs Trend Cronico** | Prescrizioni farmaceutiche giornaliere/settimanali per area terapeutica. | Depura le vendite dall'effetto stagionale invernale/allergico per misurare la crescita organica della quota di mercato. |
| **Manufacturing** | **Cicli Turni di Fabbrica vs Usura Macchina** | Scarti di produzione e consumi energetici per giorno e turno. | Distingue l'oscillazione fisiologica di avvio settimana (lunedì mattina) dal trend di deterioramento meccanico. |
| **Public Sector** | **Flussi Pendolari vs Trend Demografico** | Passaggi ZTL, trasporti pubblici e produzione rifiuti urbani. | Separa i cicli settimanali/estivi dalla tendenza strutturale di lungo periodo per il piano urbano della mobilità. |
| **Telco & Media** | **Profilo Settimanale Traffico Mobile** | Traffico voce/dati per cella tra giorni feriali e weekend. | Isola la componente ciclica pendolare dal trend di crescita strutturale del consumo video in 5G. |

---

### Slide 20: `ML.CORRELATION` — ML.CORRELATION — Correlazione Multivariata
* **Categoria:** Augmented Analytics TVF (Statistica)  |  **Motore:** `BigQuery Statistical Correlation Engine`
* **Descrizione Generale:** Calcola automaticamente i coefficienti di correlazione lineare (Pearson) o di rango (Spearman) tra una variabile target e una lista di feature numeriche, restituendo una tabella ordinata pronta per feature selection e diagnostica.
* **Sintassi SQL di Riferimento:**
  ```sql
  SELECT * FROM ML.CORRELATION(TABLE metrics, target_col => 'total_returns', target_correlation_cols => ['total_orders', 'total_refunds'])
  ```
* **Utilizzo nel Workshop:** Lab I (14_augmented_analytics_bonus_pack.sql): dimostra su 5.015 clienti che i resi correlano fortemente con i rimborsi (0.852) ma debolmente con gli ordini (0.290).

| Verticale | Use Case Specifico | Dati / Input | Azione SQL & Impatto di Business |
|---|---|---|---|
| **Banking / Finance** | **Feature Selection per Credit Scoring** | Variabili comportamentali di conto: saldo medio, scoperti, bonifici, insoluti. | Identifica rapidamente quali indicatori hanno la correlazione più forte con la probabilità di insolvenza a 12 mesi. |
| **Retail & Consumer** | **Diagnostica dei Serial Returners** | Metriche per cliente: ordini totali, resi, valore rimborsato, sconti, punti fedeltà. | Dimostra che i truffatori non sono semplicemente i clienti che comprano di più (r=0.29), ma profili mirati ad alto rimborso. |
| **Pharma & Life Sciences** | **Correlazione Biomarker & Risposta Clinica** | Parametri ematochimici, dosaggio, età, BMI vs riduzione del marcatore di malattia. | Individua i parametri fisiologici più correlati all'efficacia terapeutica nei dati Real-World Evidence (RWE). |
| **Manufacturing** | **Parametri di Processo vs Difettosità** | Temperatura, pressione, velocità linea, umidità vs tasso di difettosità lotto. | Isola il parametro fisico di macchina più correlato alla rottura precoce del componente sul campo. |
| **Public Sector** | **Indicatori Socio-Economici & Riscossione** | Dati catastali, consumi utenze, reddito dichiarato vs tasso di riscossione. | Evidenzia le variabili territoriali più correlate al divario di adempimento spontaneo o alla domanda di welfare. |
| **Telco & Media** | **Qualità di Rete (QoS) vs Churn** | Jitter, packet loss, velocità media, numero ticket vs tasso di disdetta. | Quantifica quale metrica tecnica di rete impatta maggiormente sulla perdita di clienti residenziali. |

---

### Slide 21: `PROPERTY GRAPH & GQL` — CREATE PROPERTY GRAPH & GQL — Graph Analytics
* **Categoria:** Native ISO/IEC 39075 GQL Graph  |  **Motore:** `BigQuery Property Graph (Zero-Copy)`
* **Descrizione Generale:** Definisce una vista a grafo zero-copy sopra le normali tabelle relazionali BigQuery e permette di interrogarla con lo standard internazionale ISO GQL (GRAPH_TABLE). Scopre anelli, catene multi-hop e relazioni nascoste senza duplicare dati o gestire database a grafo esterni.
* **Sintassi SQL di Riferimento:**
  ```sql
  CREATE OR REPLACE PROPERTY GRAPH fraud_graph NODE TABLES (...) EDGE TABLES (...)  |  FROM GRAPH_TABLE(fraud_graph MATCH (c1:Customer)-[:USES_DEVICE]->(d)<-[:USES_DEVICE]-(c2:Customer) ...)
  ```
* **Utilizzo nel Workshop:** Lab I (03_property_graph.sql, 04_ring_detection.sql, 05_graph_exploration_queries.sql): scopre i 3 Fraud Ring (RING-1, RING-2, RING-3) e il Loyalty Laundering.

| Verticale | Use Case Specifico | Dati / Input | Azione SQL & Impatto di Business |
|---|---|---|---|
| **Banking / Finance** | **Reti di Riciclaggio (AML) & Mule Accounts** | Conti correnti, bonifici istantanei, dispositivi mobile, indirizzi IP e beneficiari. | Scopre anelli circolari di smurfing/layering a 3-5 salti (Conto A → Conto B → Conto C → Conto A) e device condivisi. |
| **Retail & Consumer** | **Fraud Ring Resi & Loyalty Laundering** | Clienti, ordini, resi, carte di pagamento, indirizzi, device e trasferimenti punti. | Smaschera gruppi organizzati che condividono un singolo indirizzo/device e trasferiscono punti fedeltà verso account 'puliti'. |
| **Pharma & Life Sciences** | **Tracciabilità Catena di Fornitura & Trial** | Fornitori materie prime, lotti intermedi, stabilimenti, distributori e ospedali. | Ricostruisce in un istante il grafo d'impatto multi-livello (genealogy) di un eccipiente contaminato lungo tutta la rete. |
| **Manufacturing** | **Esplosione BOM Multi-Livello** | Fornitori sub-tier, lotti componenti, sotto-assiemi, macchine, lotti finiti e SKU. | Attraversa il grafo Fornitore → Lotto → Macchina → Batch → Prodotto per isolare tutti gli SKU esposti a un pezzo difettoso. |
| **Public Sector** | **Anticorruzione Appalti & Conflitti** | Partecipanti a gare pubbliche, soci, amministratori, partecipazioni incrociate e subappalti. | Rileva cartelli societari e legami familiari/societari occulti a più salti tra aggiudicatari e subappaltatori. |
| **Telco & Media** | **Topologia di Rete & Propagazione Guasti** | Centrali ottiche, router core, ponti radio, celle 5G e clienti enterprise collegati. | Calcola l'analisi di impatto (blast radius) a valle di un guasto su un nodo di trasporto condiviso. |

---
