-- =============================================================================
-- NovaHome Appliances — Product Review Intelligence demo
-- Step 1: dataset, tables and sample data
--
-- Run with:  bq query --use_legacy_sql=false --location=EU < sql/01_setup_dataset_and_data.sql
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS `mfg_quality_demo`
  OPTIONS (
    location = 'EU',
    description = 'Demo: analyze unstructured product reviews with BigQuery generative AI and trace defects back to production machines and component lots'
  );

-- ---------------------------------------------------------------------------
-- Product catalog
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE `mfg_quality_demo.products` (
  sku          STRING NOT NULL,
  product_name STRING,
  category     STRING,
  launch_date  DATE
);

INSERT INTO `mfg_quality_demo.products` VALUES
  ('KTL-100', 'AquaBoil Electric Kettle 1.7L',   'kettle',       DATE '2024-03-01'),
  ('KTL-200', 'AquaBoil Smart Kettle',           'kettle',       DATE '2025-05-15'),
  ('CM-350',  'BrewMaster Drip Coffee Maker',    'coffee_maker', DATE '2023-11-10'),
  ('BLD-220', 'VortexBlend Pro Blender',         'blender',      DATE '2024-08-01'),
  ('TST-140', 'CrispToast 4-Slice Toaster',      'toaster',      DATE '2023-06-20'),
  ('AFR-500', 'AirCrisp XL Air Fryer',           'air_fryer',    DATE '2025-02-05');

-- ---------------------------------------------------------------------------
-- Factory machines
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE `mfg_quality_demo.machines` (
  machine_id            STRING NOT NULL,
  machine_name          STRING,
  machine_type          STRING,
  production_line       STRING,
  last_maintenance_date DATE
);

INSERT INTO `mfg_quality_demo.machines` VALUES
  ('ASM-01',  'Final assembly robot A',            'assembly',            'Line A', DATE '2025-05-20'),
  ('ASM-02',  'Final assembly robot B',            'assembly',            'Line B', DATE '2025-04-12'),
  ('WND-01',  'Motor winding station',             'motor_winding',       'Line A', DATE '2025-06-01'),
  ('CAL-01',  'Thermostat calibration station A',  'thermal_calibration', 'Line A', DATE '2025-05-28'),
  ('CAL-02',  'Thermostat calibration station B',  'thermal_calibration', 'Line B', DATE '2025-01-17'),  -- overdue maintenance
  ('MLD-01',  'Injection molding press',           'molding',             'Shared', DATE '2025-06-10'),
  ('SEAL-01', 'Gasket seating press',              'sealing',             'Shared', DATE '2025-03-02'),
  ('PCK-01',  'Packaging line',                    'packaging',           'Shared', DATE '2025-06-15');

-- ---------------------------------------------------------------------------
-- Component lots: each lot of parts is installed/processed by one machine
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE `mfg_quality_demo.component_lots` (
  lot_id                  STRING NOT NULL,
  component_type          STRING,
  supplier                STRING,
  installed_by_machine_id STRING,
  received_date           DATE
);

INSERT INTO `mfg_quality_demo.component_lots` VALUES
  ('HE-4471',  'heating_element', 'ThermoCore', 'CAL-02', DATE '2025-05-25'),  -- suspect lot
  ('HE-4472',  'heating_element', 'ThermoCore', 'CAL-01', DATE '2025-05-25'),
  ('HE-4398',  'heating_element', 'Calorix',    'CAL-01', DATE '2025-05-02'),
  ('TH-2210',  'thermostat',      'SwissTherm', 'CAL-02', DATE '2025-05-28'),
  ('TH-2211',  'thermostat',      'SwissTherm', 'CAL-01', DATE '2025-05-28'),
  ('MT-9090',  'motor',           'Dynamotor',  'WND-01', DATE '2025-05-30'),
  ('MT-9091',  'motor',           'Dynamotor',  'WND-01', DATE '2025-06-25'),
  ('GSK-770',  'gasket_seal',     'FlexiSeal',  'SEAL-01', DATE '2025-05-20'),  -- mildly problematic
  ('GSK-771',  'gasket_seal',     'FlexiSeal',  'SEAL-01', DATE '2025-06-18'),
  ('HSG-501',  'plastic_housing', 'PolyForm',   'MLD-01', DATE '2025-05-15'),
  ('HSG-502',  'plastic_housing', 'PolyForm',   'MLD-01', DATE '2025-06-12'),
  ('CTL-310',  'control_board',   'OmniLogic',  'ASM-01', DATE '2025-05-22'),
  ('CTL-311',  'control_board',   'OmniLogic',  'ASM-02', DATE '2025-05-22');

-- ---------------------------------------------------------------------------
-- Production batches (a customer's serial number maps to one batch)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE `mfg_quality_demo.production_batches` (
  batch_id        STRING NOT NULL,
  sku             STRING,
  production_date DATE,
  production_line STRING,
  units_produced  INT64
);

INSERT INTO `mfg_quality_demo.production_batches` VALUES
  ('B-2506-01', 'KTL-100', DATE '2025-06-02', 'Line A', 4200),
  ('B-2506-02', 'KTL-100', DATE '2025-06-09', 'Line B', 4600),
  ('B-2506-03', 'CM-350',  DATE '2025-06-05', 'Line A', 3100),
  ('B-2506-04', 'BLD-220', DATE '2025-06-11', 'Line A', 2800),
  ('B-2507-05', 'KTL-200', DATE '2025-07-01', 'Line B', 3900),
  ('B-2507-06', 'TST-140', DATE '2025-07-03', 'Line A', 5000),
  ('B-2507-07', 'AFR-500', DATE '2025-07-08', 'Line B', 2400),
  ('B-2507-08', 'CM-350',  DATE '2025-07-10', 'Line B', 3300),
  ('B-2507-09', 'BLD-220', DATE '2025-07-15', 'Line A', 2900),
  ('B-2507-10', 'KTL-100', DATE '2025-07-20', 'Line B', 4400);

-- ---------------------------------------------------------------------------
-- Bill of materials per batch: which component lots went into which batch
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE `mfg_quality_demo.batch_components` (
  batch_id STRING NOT NULL,
  lot_id   STRING NOT NULL
);

INSERT INTO `mfg_quality_demo.batch_components` VALUES
  ('B-2506-01', 'HE-4472'), ('B-2506-01', 'TH-2211'), ('B-2506-01', 'HSG-501'), ('B-2506-01', 'CTL-310'),
  ('B-2506-02', 'HE-4471'), ('B-2506-02', 'TH-2210'), ('B-2506-02', 'HSG-501'), ('B-2506-02', 'CTL-311'),
  ('B-2506-03', 'HE-4398'), ('B-2506-03', 'TH-2211'), ('B-2506-03', 'GSK-770'), ('B-2506-03', 'HSG-502'), ('B-2506-03', 'CTL-310'),
  ('B-2506-04', 'MT-9090'), ('B-2506-04', 'GSK-771'), ('B-2506-04', 'HSG-501'), ('B-2506-04', 'CTL-310'),
  ('B-2507-05', 'HE-4471'), ('B-2507-05', 'TH-2210'), ('B-2507-05', 'HSG-502'), ('B-2507-05', 'CTL-311'),
  ('B-2507-06', 'HE-4472'), ('B-2507-06', 'HSG-501'), ('B-2507-06', 'CTL-310'),
  ('B-2507-07', 'HE-4398'), ('B-2507-07', 'MT-9091'), ('B-2507-07', 'HSG-502'), ('B-2507-07', 'CTL-311'),
  ('B-2507-08', 'HE-4398'), ('B-2507-08', 'TH-2210'), ('B-2507-08', 'GSK-770'), ('B-2507-08', 'HSG-502'), ('B-2507-08', 'CTL-311'),
  ('B-2507-09', 'MT-9091'), ('B-2507-09', 'GSK-771'), ('B-2507-09', 'HSG-501'), ('B-2507-09', 'CTL-310'),
  ('B-2507-10', 'HE-4471'), ('B-2507-10', 'TH-2211'), ('B-2507-10', 'HSG-501'), ('B-2507-10', 'CTL-311');

-- ---------------------------------------------------------------------------
-- Unstructured customer reviews (batch_id decoded from the serial number the
-- customer registered / printed on the unit)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE `mfg_quality_demo.product_reviews` (
  review_id   STRING NOT NULL,
  sku         STRING,
  batch_id    STRING,
  review_date DATE,
  rating      INT64,
  source      STRING,
  review_text STRING
);

INSERT INTO `mfg_quality_demo.product_reviews` VALUES
  -- ===== Batch B-2506-02 (KTL-100, heating element lot HE-4471) =====
  ('R-0001', 'KTL-100', 'B-2506-02', DATE '2025-06-28', 1, 'amazon',        'Worked fine for exactly two weeks, then it just stopped heating. The light comes on, you hear a faint click, and the water stays cold. Total waste of money.'),
  ('R-0002', 'KTL-100', 'B-2506-02', DATE '2025-07-02', 2, 'amazon',        'Takes almost 15 minutes to get water anywhere near boiling. My old kettle did it in 3. Something is definitely wrong with the heating on this one.'),
  ('R-0003', 'KTL-100', 'B-2506-02', DATE '2025-07-05', 1, 'retailer_site', 'DO NOT BUY. Kettle died after 10 days. No heat at all, just a blinking light. Returning it.'),
  ('R-0004', 'KTL-100', 'B-2506-02', DATE '2025-07-08', 1, 'support_email', 'Hello, I purchased the AquaBoil kettle on June 12th, serial NB-B250602-0441. Since yesterday it only produces lukewarm water even after running a full cycle twice. I descaled it as per the manual, no change. Please advise on warranty replacement.'),
  ('R-0005', 'KTL-100', 'B-2506-02', DATE '2025-07-11', 2, 'amazon',        'Water never gets past warm. tested with a thermometer, tops out at 70C. defective heating element i guess. disappointed because the design is really nice.'),
  ('R-0006', 'KTL-100', 'B-2506-02', DATE '2025-07-13', 5, 'amazon',        'Love the look of this kettle, matches my kitchen perfectly. Boils fast and the lid opens smoothly. Very happy so far after one week!'),
  ('R-0007', 'KTL-100', 'B-2506-02', DATE '2025-07-16', 1, 'retailer_site', 'Second unit with the same problem!! First one stopped heating after 2 weeks, the replacement is now doing the exact same thing. Water stays cold, switch clicks off after a minute. There must be a bad production run.'),
  ('R-0008', 'KTL-100', 'B-2506-02', DATE '2025-07-19', 3, 'amazon',        'Kettle works but the power cord is shorter than I expected. Also wish the handle was a bit bigger. Heats fine though.'),

  -- ===== Batch B-2507-05 (KTL-200, heating element lot HE-4471) =====
  ('R-0009', 'KTL-200', 'B-2507-05', DATE '2025-07-18', 1, 'app',           'Smart kettle, dumb heater. The app connects fine but the kettle itself stopped warming water after 12 days. Error E4 on the display.'),
  ('R-0010', 'KTL-200', 'B-2507-05', DATE '2025-07-21', 2, 'amazon',        'The temperature never reaches what I set. I select 100 and it stops at like 75. Tried resetting, same thing. The heating element seems too weak.'),
  ('R-0011', 'KTL-200', 'B-2507-05', DATE '2025-07-23', 1, 'support_email', 'Ticket: my AquaBoil Smart Kettle (bought July 5) no longer heats. App shows "heating" but water is stone cold after 20 minutes. Serial NB-B250705-1877. I want a refund, this is the second NovaHome product that failed on me this month.'),
  ('R-0012', 'KTL-200', 'B-2507-05', DATE '2025-07-25', 4, 'app',           'Really slick product, scheduling from the phone is great. Took a star off because the lid feels flimsy, but heating is quick and quiet.'),
  ('R-0013', 'KTL-200', 'B-2507-05', DATE '2025-07-27', 1, 'amazon',        'Dead after two weeks. Wont heat at all anymore. Judging by other reviews I am not the only one. Skip this one until they fix whatever is wrong.'),
  ('R-0014', 'KTL-200', 'B-2507-05', DATE '2025-07-29', 2, 'retailer_site', 'Water comes out lukewarm no matter the setting. Fine for green tea I guess, useless for anything else. Contacting support.'),

  -- ===== Batch B-2507-10 (KTL-100, heating element lot HE-4471) =====
  ('R-0015', 'KTL-100', 'B-2507-10', DATE '2025-07-28', 1, 'amazon',        'Brand new out of the box and it barely warms the water. 45 minutes and still not boiling. Clearly defective.'),
  ('R-0016', 'KTL-100', 'B-2507-10', DATE '2025-07-30', 2, 'amazon',        'Heats very slowly and shuts itself off before boiling. My previous AquaBoil from last year was perfect, this new one is a downgrade. Quality control issue?'),
  ('R-0017', 'KTL-100', 'B-2507-10', DATE '2025-08-01', 1, 'support_email', 'The kettle I received a week ago (serial NB-B250720-0092) has stopped heating entirely. The switch clicks off immediately. Requesting replacement under warranty.'),
  ('R-0018', 'KTL-100', 'B-2507-10', DATE '2025-08-02', 5, 'retailer_site', 'Third AquaBoil in the family, bought this one for the office. Fast, quiet, looks great. No complaints.'),

  -- ===== Batch B-2506-01 (KTL-100, good heating lot HE-4472) =====
  ('R-0019', 'KTL-100', 'B-2506-01', DATE '2025-06-20', 5, 'amazon',        'Excellent kettle. Boils 1.7L in about 4 minutes, auto shutoff works, no plastic smell. Would buy again.'),
  ('R-0020', 'KTL-100', 'B-2506-01', DATE '2025-06-25', 4, 'amazon',        'Good value. A little loud when it gets close to boiling but nothing unreasonable. Heats fast and evenly.'),
  ('R-0021', 'KTL-100', 'B-2506-01', DATE '2025-07-03', 5, 'retailer_site', 'Bought as a gift for my parents, they use it daily and love it. Sturdy and quick.'),
  ('R-0022', 'KTL-100', 'B-2506-01', DATE '2025-07-14', 2, 'amazon',        'The box arrived crushed and the kettle had a scratch on the side. Works fine but the packaging needs work. Seller replaced it quickly at least.'),
  ('R-0023', 'KTL-100', 'B-2506-01', DATE '2025-07-22', 4, 'app',           'Does what a kettle should. Wish it had a keep-warm mode like the smart version, but zero problems in a month of heavy use.'),

  -- ===== Batch B-2506-03 (CM-350, gasket lot GSK-770) =====
  ('R-0024', 'CM-350', 'B-2506-03', DATE '2025-06-22', 2, 'amazon',        'Coffee tastes great BUT the machine leaks water from underneath every single brew. I have to keep a towel under it. Checked the tank, it is seated fine — the leak comes from the bottom seam.'),
  ('R-0025', 'CM-350', 'B-2506-03', DATE '2025-06-27', 1, 'retailer_site', 'Puddle of water under the machine every morning. After a week the leak got worse and now it drips even when idle. Returning.'),
  ('R-0026', 'CM-350', 'B-2506-03', DATE '2025-07-01', 4, 'amazon',        'Solid coffee maker for the price. Brews a full carafe in 6 minutes. The carafe lid is a little awkward to pour with, minor gripe.'),
  ('R-0027', 'CM-350', 'B-2506-03', DATE '2025-07-06', 2, 'support_email', 'My BrewMaster (serial NB-B250605-2210) is leaking from the base near the hot plate. About a tablespoon of water per brew. Is this covered by warranty? It started around the third week of use.'),
  ('R-0028', 'CM-350', 'B-2506-03', DATE '2025-07-12', 5, 'amazon',        'Replaced a 10 year old machine with this one. Hotter coffee, faster brew, easy to clean. Very happy.'),
  ('R-0029', 'CM-350', 'B-2506-03', DATE '2025-07-18', 3, 'amazon',        'Decent machine but there is a slow drip from the water reservoir gasket, maybe one small puddle a week. Not enough to return it, but watch out.'),

  -- ===== Batch B-2507-08 (CM-350, gasket lot GSK-770) =====
  ('R-0030', 'CM-350', 'B-2507-08', DATE '2025-07-24', 1, 'amazon',        'Leaked from day one. Water everywhere on the counter, nearly reached the outlet. This is a safety issue, not just an annoyance.'),
  ('R-0031', 'CM-350', 'B-2507-08', DATE '2025-07-28', 2, 'retailer_site', 'Second BrewMaster with a leaky seal around the tank. The first one I exchanged did the same. Love the coffee, hate the puddles.'),
  ('R-0032', 'CM-350', 'B-2507-08', DATE '2025-07-31', 5, 'amazon',        'No issues at all, three weeks in. Programmable timer is accurate and the coffee is hot. Recommended.'),
  ('R-0033', 'CM-350', 'B-2507-08', DATE '2025-08-02', 4, 'app',           'Good machine. The drip stop works well and cleaning is simple. Took one star because the water level window fogs up.'),

  -- ===== Batch B-2506-04 (BLD-220, motor lot MT-9090) =====
  ('R-0034', 'BLD-220', 'B-2506-04', DATE '2025-06-25', 5, 'amazon',        'This blender is a beast. Crushes ice like nothing, smoothies are perfectly smooth. Loud, but that is expected with this power.'),
  ('R-0035', 'BLD-220', 'B-2506-04', DATE '2025-07-02', 4, 'amazon',        'Great power and the jar feels premium. The lid is a tight fit which is good for safety but annoying to remove.'),
  ('R-0036', 'BLD-220', 'B-2506-04', DATE '2025-07-09', 2, 'retailer_site', 'After a month the motor started making a grinding noise and I can smell something burning when it runs longer than 30 seconds. Not normal for a product this new.'),
  ('R-0037', 'BLD-220', 'B-2506-04', DATE '2025-07-15', 5, 'app',           'Use it every morning for protein shakes. Fast, easy to clean, no complaints whatsoever.'),
  ('R-0038', 'BLD-220', 'B-2506-04', DATE '2025-07-21', 3, 'amazon',        'Works well but it is REALLY loud, like jet engine loud. My kid covers his ears. Blends great though.'),

  -- ===== Batch B-2507-09 (BLD-220, motor lot MT-9091) =====
  ('R-0039', 'BLD-220', 'B-2507-09', DATE '2025-07-26', 5, 'amazon',        'Second Vortex blender I own. Consistent, powerful, and the new jar design pours much better. Top marks.'),
  ('R-0040', 'BLD-220', 'B-2507-09', DATE '2025-07-30', 4, 'retailer_site', 'Very good blender. The preset buttons are handy. Rubber feet slide a little on a wet counter, thats my only note.'),
  ('R-0041', 'BLD-220', 'B-2507-09', DATE '2025-08-01', 1, 'amazon',        'Arrived with a cracked jar. Blender itself seems fine with the replacement jar the seller sent, but the unboxing experience was terrible.'),

  -- ===== Batch B-2507-06 (TST-140, good heating lot HE-4472) =====
  ('R-0042', 'TST-140', 'B-2507-06', DATE '2025-07-12', 5, 'amazon',        'Even toasting on all four slots, bagel mode actually works. Best toaster I have owned.'),
  ('R-0043', 'TST-140', 'B-2507-06', DATE '2025-07-17', 4, 'amazon',        'Toasts evenly and quickly. The crumb tray is easy to empty. Slightly wider footprint than expected.'),
  ('R-0044', 'TST-140', 'B-2507-06', DATE '2025-07-23', 3, 'retailer_site', 'Does the job. The lever feels a bit cheap and the chrome finish shows fingerprints, but toast comes out perfect.'),
  ('R-0045', 'TST-140', 'B-2507-06', DATE '2025-07-29', 5, 'app',           'Simple, fast, reliable. Exactly what a toaster should be.'),

  -- ===== Batch B-2507-07 (AFR-500, heating lot HE-4398, motor MT-9091) =====
  ('R-0046', 'AFR-500', 'B-2507-07', DATE '2025-07-20', 5, 'amazon',        'Air fryer heats up fast and the basket is genuinely XL, fits a whole chicken. Fries come out crispy every time.'),
  ('R-0047', 'AFR-500', 'B-2507-07', DATE '2025-07-24', 4, 'amazon',        'Great results, easy controls. The fan is a bit noisy on max but nothing unusual for an air fryer.'),
  ('R-0048', 'AFR-500', 'B-2507-07', DATE '2025-07-27', 2, 'retailer_site', 'The nonstick coating on the basket started peeling after two weeks of normal use. Cooking performance is fine but I do not want coating flakes in my food.'),
  ('R-0049', 'AFR-500', 'B-2507-07', DATE '2025-07-31', 5, 'app',           'Replaced my oven for most meals honestly. Even cooking, quick preheat, love it.'),
  ('R-0050', 'AFR-500', 'B-2507-07', DATE '2025-08-02', 4, 'amazon',        'Works as advertised. Manual could be better — the preset table is confusing. Food comes out great.'),

  -- ===== A few more mixed reviews to add realistic noise =====
  ('R-0051', 'KTL-100', 'B-2506-02', DATE '2025-07-20', 1, 'app',           'Update to my earlier review: support sent a replacement and THAT one also stopped heating within days. Three strikes. Something is systematically broken with these kettles.'),
  ('R-0052', 'KTL-200', 'B-2507-05', DATE '2025-07-31', 3, 'amazon',        'App pairing took forever and dropped twice. Kettle heats okay so far, but the software needs work.'),
  ('R-0053', 'KTL-100', 'B-2507-10', DATE '2025-08-02', 2, 'amazon',        'Takes twice as long to boil as advertised. 8+ minutes for a full tank. Not defective exactly, just underpowered or something wrong with the element.'),
  ('R-0054', 'CM-350',  'B-2507-08', DATE '2025-08-01', 2, 'support_email', 'There is water pooling under my week-old BrewMaster after every brew cycle, serial NB-B250710-0523. Photos attached. Please arrange a replacement.'),
  ('R-0055', 'TST-140', 'B-2507-06', DATE '2025-08-01', 4, 'amazon',        'Good toaster, uneven browning only on the thickest bagel setting. Otherwise flawless for a month.'),
  ('R-0056', 'BLD-220', 'B-2507-09', DATE '2025-08-02', 5, 'retailer_site', 'Gifted to my sister, she loves it. Powerful and the presets take the guesswork out.'),
  ('R-0057', 'KTL-100', 'B-2506-01', DATE '2025-07-30', 5, 'amazon',        'Two months of daily use, still perfect. Fast boil, no smells, no drama.'),
  ('R-0058', 'KTL-200', 'B-2507-05', DATE '2025-08-02', 1, 'retailer_site', 'Heating element gave out on day 16. The app cheerfully says "your water is ready" while the water is cold. Comedy and tragedy in one product.'),
  ('R-0059', 'AFR-500', 'B-2507-07', DATE '2025-08-01', 3, 'amazon',        'Cooks well but the door hinge squeaks loudly. A drop of oil fixed it but you should not need to service a brand new appliance.'),
  ('R-0060', 'CM-350',  'B-2506-03', DATE '2025-07-25', 1, 'amazon',        'Leak started small, now the machine drips constantly from the base gasket. Ruined the wood counter finish. Expected better from NovaHome.');
