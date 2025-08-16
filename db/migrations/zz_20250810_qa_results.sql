create table if not exists qa_runs (
  id bigint generated always as identity primary key,
  flow_id text not null,
  browser text not null,
  status text check (status in ('passed','failed')) not null,
  logs jsonb not null,
  started_at timestamptz not null default now()
);

create table if not exists qa_findings (
  id bigint generated always as identity primary key,
  run_id bigint references qa_runs(id) on delete cascade,
  severity text check (severity in ('low','medium','high')) not null,
  title text not null,
  details jsonb,
  created_at timestamptz not null default now()
);
EOF < /dev/null