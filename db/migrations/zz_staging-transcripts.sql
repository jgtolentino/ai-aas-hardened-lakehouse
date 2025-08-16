-- Scout Edge: Structured Transcript Staging Table
-- Captures conversation turns for NLP/analytics

create schema if not exists suqi;

-- Staging table for conversation transcripts
create table if not exists suqi.staging_transcripts (
  id bigserial primary key,
  transaction_id text not null,
  t_seconds numeric not null,
  speaker text not null check (speaker in ('cust','owner','clerk','unknown')),
  text text not null,
  created_at timestamptz not null default now()
);

-- Indexes for efficient querying
create index if not exists idx_transcript_tx on suqi.staging_transcripts(transaction_id);
create index if not exists idx_transcript_created on suqi.staging_transcripts(created_at);

-- View for conversation analysis
create or replace view suqi.conversation_analytics as
select 
  t.transaction_id,
  t.store_id,
  t.ts_utc,
  count(st.id) as turn_count,
  sum(case when st.speaker = 'cust' then 1 else 0 end) as customer_turns,
  sum(case when st.speaker in ('owner','clerk') then 1 else 0 end) as staff_turns,
  max(st.t_seconds) as conversation_duration_seconds,
  string_agg(st.text, ' ' order by st.t_seconds) as full_transcript
from public.scout_gold_transactions t
left join suqi.staging_transcripts st on t.transaction_id = st.transaction_id
group by t.transaction_id, t.store_id, t.ts_utc;

-- Common phrases extraction
create or replace view suqi.common_phrases as
select 
  lower(text) as phrase,
  count(*) as occurrences,
  count(distinct transaction_id) as unique_transactions
from suqi.staging_transcripts
where speaker = 'cust'
  and length(text) > 5
group by lower(text)
having count(*) > 5
order by count(*) desc
limit 100;