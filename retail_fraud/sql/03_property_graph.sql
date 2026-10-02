-- Phase 2a: BigQuery property graph over customers and the entities they share.
-- Fraud rings reveal themselves as multiple accounts connected to the same
-- device / shipping address / payment method.

CREATE OR REPLACE PROPERTY GRAPH `retail_fraud.fraud_graph`
  NODE TABLES (
    `retail_fraud.customers` AS customers KEY (customer_id) LABEL Customer,
    `retail_fraud.devices` AS devices KEY (device_id) LABEL Device,
    `retail_fraud.addresses` AS addresses KEY (address_id) LABEL Address,
    `retail_fraud.payment_methods` AS payment_methods KEY (payment_method_id) LABEL PaymentMethod
  )
  EDGE TABLES (
    `retail_fraud.customer_devices` AS customer_devices KEY (customer_id, device_id)
      SOURCE KEY (customer_id) REFERENCES customers (customer_id)
      DESTINATION KEY (device_id) REFERENCES devices (device_id)
      LABEL USES_DEVICE,
    `retail_fraud.customer_addresses` AS customer_addresses KEY (customer_id, address_id)
      SOURCE KEY (customer_id) REFERENCES customers (customer_id)
      DESTINATION KEY (address_id) REFERENCES addresses (address_id)
      LABEL SHIPS_TO,
    `retail_fraud.customer_payments` AS customer_payments KEY (customer_id, payment_method_id)
      SOURCE KEY (customer_id) REFERENCES customers (customer_id)
      DESTINATION KEY (payment_method_id) REFERENCES payment_methods (payment_method_id)
      LABEL PAYS_WITH
  );
