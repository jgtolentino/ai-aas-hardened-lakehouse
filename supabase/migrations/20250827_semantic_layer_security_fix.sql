-- Enforce SECURITY INVOKER and correct grants
-- canonical scout functions
ALTER FUNCTION scout.semantic_query(text[], jsonb, text[], text[]) SECURITY INVOKER;
ALTER FUNCTION scout.semantic_calculate(text) SECURITY INVOKER;
ALTER FUNCTION scout.semantic_suggest(jsonb) SECURITY INVOKER;  -- if created with jsonb default
ALTER FUNCTION scout.semantic_test(uuid) SECURITY INVOKER;

REVOKE ALL ON FUNCTION scout.semantic_query(text[], jsonb, text[], text[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION scout.semantic_calculate(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION scout.semantic_suggest(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION scout.semantic_test(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION scout.semantic_query(text[], jsonb, text[], text[]) TO authenticated;
GRANT EXECUTE ON FUNCTION scout.semantic_calculate(text) TO authenticated;
GRANT EXECUTE ON FUNCTION scout.semantic_suggest(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION scout.semantic_test(uuid) TO authenticated;

-- create stable API schema shims exposed via PostgREST
CREATE SCHEMA IF NOT EXISTS api;

CREATE OR REPLACE FUNCTION api.semantic_query(object_names text[], filters jsonb DEFAULT '{}'::jsonb, metrics text[] DEFAULT '{}', group_by text[] DEFAULT '{}')
RETURNS jsonb LANGUAGE sql SECURITY INVOKER AS $
  SELECT scout.semantic_query(object_names, filters, metrics, group_by);
$;

CREATE OR REPLACE FUNCTION api.semantic_calculate(nl_query text)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER AS $
  SELECT scout.semantic_calculate(nl_query);
$;

CREATE OR REPLACE FUNCTION api.semantic_suggest(schema jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER AS $
  SELECT scout.semantic_suggest(schema);
$;

CREATE OR REPLACE FUNCTION api.semantic_test(model_id uuid)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER AS $
  SELECT scout.semantic_test(model_id);
$;

REVOKE ALL ON FUNCTION api.semantic_query(text[], jsonb, text[], text[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION api.semantic_calculate(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION api.semantic_suggest(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION api.semantic_test(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION api.semantic_query(text[], jsonb, text[], text[]) TO authenticated;
GRANT EXECUTE ON FUNCTION api.semantic_calculate(text) TO authenticated;
GRANT EXECUTE ON FUNCTION api.semantic_suggest(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION api.semantic_test(uuid) TO authenticated;