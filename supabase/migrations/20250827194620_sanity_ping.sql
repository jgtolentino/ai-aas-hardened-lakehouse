CREATE TABLE IF NOT EXISTS scout_ci_ping (
  id bigserial primary key,
  created_at timestamptz not null default now()
);
