-- Phase 3a: remote Gemini model (needed by AI.GENERATE_TABLE; the scalar
-- AI.GENERATE* functions call the endpoint directly via the connection).
CREATE OR REPLACE MODEL `retail_fraud.gemini_model`
REMOTE WITH CONNECTION `eu.vertex_ai_conn`
OPTIONS (endpoint = 'gemini-3.8-flash');
