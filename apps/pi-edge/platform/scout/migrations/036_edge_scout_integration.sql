-- Scout Edge: Integration Bridge Between Edge and Scout Schemas

-- Unified analytics view combining all data sources
create or replace view scout.v_unified_analytics as
with edge_data as (
    select 
        date_trunc('hour', transaction_time) as hour,
        store_id,
        'edge' as source,
        count(*) as transaction_count,
        sum(total_amount) as revenue,
        avg(confidence_score) as avg_confidence,
        count(distinct device_id) as unique_sources
    from edge.fact_edge_transactions
    where transaction_time > now() - interval '7 days'
    group by 1, 2
),
file_data as (
    select 
        date_trunc('hour', processed_at) as hour,
        coalesce(store_id, 'UNKNOWN') as store_id,
        'file' as source,
        count(*) as transaction_count,
        sum(records_processed) as revenue, -- placeholder
        1.0 as avg_confidence,
        count(distinct source_type) as unique_sources
    from scout.ingestion_history
    where processed_at > now() - interval '7 days'
      and status = 'completed'
    group by 1, 2
),
scraper_data as (
    select 
        date_trunc('hour', observed_at) as hour,
        'CATALOG' as store_id,
        'scraper' as source,
        count(*) as transaction_count,
        sum(list_price) as revenue,
        1.0 as avg_confidence,
        count(distinct source_id) as unique_sources
    from scout.master_items
    where observed_at > now() - interval '7 days'
    group by 1
)
select * from edge_data
union all
select * from file_data
union all
select * from scraper_data
order by hour desc, store_id, source;

-- Edge transaction enrichment with Scout data
create or replace function scout.enrich_edge_transaction(p_transaction_id bigint)
returns jsonb language plpgsql as $$
declare
    v_transaction record;
    v_enriched jsonb;
    v_item jsonb;
    v_enriched_items jsonb := '[]'::jsonb;
begin
    -- Get transaction
    select * into v_transaction
    from edge.fact_edge_transactions
    where transaction_id = p_transaction_id;
    
    if not found then
        return null;
    end if;
    
    -- Enrich each item
    for v_item in select * from jsonb_array_elements(v_transaction.items)
    loop
        -- Add enrichment data
        v_item := v_item || jsonb_build_object(
            'catalog_match', (
                select row_to_json(m.*)
                from scout.master_items m
                where m.brand_name = v_item->>'brand'
                limit 1
            ),
            'price_history', (
                select jsonb_agg(jsonb_build_object(
                    'date', observed_at,
                    'price', list_price
                ))
                from scout.master_items
                where brand_name = v_item->>'brand'
                  and product_name = v_item->>'product'
                  and observed_at > now() - interval '30 days'
            )
        );
        
        v_enriched_items := v_enriched_items || v_item;
    end loop;
    
    -- Build enriched transaction
    v_enriched := jsonb_build_object(
        'transaction_id', v_transaction.transaction_id,
        'device_id', v_transaction.device_id,
        'store_id', v_transaction.store_id,
        'transaction_time', v_transaction.transaction_time,
        'original_items', v_transaction.items,
        'enriched_items', v_enriched_items,
        'total_amount', v_transaction.total_amount,
        'confidence_score', v_transaction.confidence_score,
        'enrichment_timestamp', now()
    );
    
    return v_enriched;
end;
$$;

-- Real-time pipeline monitoring
create or replace function scout.get_edge_pipeline_status()
returns table(
    metric text,
    value numeric,
    unit text,
    status text
) language sql as $$
    select 'Edge Events/Hour' as metric,
           count(*)::numeric as value,
           'events' as unit,
           case when count(*) = 0 then 'critical'
                when count(*) < 10 then 'warning'
                else 'healthy' end as status
    from edge.bronze_edge_events
    where created_at > now() - interval '1 hour'
    
    union all
    
    select 'Edge Transactions/Hour',
           count(*)::numeric,
           'transactions',
           case when count(*) = 0 then 'warning' else 'healthy' end
    from edge.fact_edge_transactions
    where created_at > now() - interval '1 hour'
    
    union all
    
    select 'Average Confidence',
           round(avg(confidence_score)::numeric, 2),
           'score',
           case when avg(confidence_score) < 0.7 then 'warning' else 'healthy' end
    from edge.fact_edge_transactions
    where created_at > now() - interval '24 hours'
    
    union all
    
    select 'Devices Online',
           count(*)::numeric,
           'devices',
           case when count(*) < 2 then 'critical' else 'healthy' end
    from edge.devices
    where status = 'online'
    
    union all
    
    select 'Processing Lag',
           extract(epoch from (now() - max(timestamp)))::numeric,
           'seconds',
           case when extract(epoch from (now() - max(timestamp))) > 300 then 'warning' else 'healthy' end
    from edge.bronze_edge_events;
$$;

-- Store performance comparison
create or replace view scout.v_store_performance as
select 
    s.store_id,
    s.store_name,
    coalesce(e.edge_transactions, 0) as edge_transactions,
    coalesce(e.edge_revenue, 0) as edge_revenue,
    coalesce(f.file_records, 0) as file_records,
    coalesce(e.avg_confidence, 0) as avg_confidence,
    case 
        when e.last_transaction is null then 'No data'
        when e.last_transaction < now() - interval '1 hour' then 'Inactive'
        else 'Active'
    end as status
from (
    select distinct store_id, store_id as store_name 
    from edge.devices
) s
left join (
    select 
        store_id,
        count(*) as edge_transactions,
        sum(total_amount) as edge_revenue,
        avg(confidence_score) as avg_confidence,
        max(transaction_time) as last_transaction
    from edge.fact_edge_transactions
    where transaction_time > now() - interval '24 hours'
    group by store_id
) e on s.store_id = e.store_id
left join (
    select 
        store_id,
        sum(records_processed) as file_records
    from scout.ingestion_history
    where processed_at > now() - interval '24 hours'
      and store_id is not null
    group by store_id
) f on s.store_id = f.store_id;

-- Alert function for low confidence transactions
create or replace function scout.check_confidence_alerts()
returns table(
    alert_type text,
    severity text,
    details jsonb
) language sql as $$
    select 'Low Confidence Transactions' as alert_type,
           'warning' as severity,
           jsonb_build_object(
               'count', count(*),
               'avg_confidence', round(avg(confidence_score)::numeric, 2),
               'affected_stores', array_agg(distinct store_id)
           ) as details
    from edge.fact_edge_transactions
    where confidence_score < 0.7
      and transaction_time > now() - interval '1 hour'
    having count(*) > 5
    
    union all
    
    select 'Device Offline' as alert_type,
           'critical' as severity,
           jsonb_build_object(
               'devices', array_agg(device_id),
               'last_seen', min(last_heartbeat)
           ) as details
    from edge.devices
    where status = 'offline'
      or last_heartbeat < now() - interval '10 minutes'
    having count(*) > 0
    
    union all
    
    select 'High File Queue' as alert_type,
           'warning' as severity,
           jsonb_build_object(
               'pending_files', count(*),
               'oldest_file', min(created_at)
           ) as details
    from scout.file_ingestion_queue
    where status = 'pending'
    having count(*) > 50;
$$;

-- Grant permissions
grant select on scout.v_unified_analytics to anon, authenticated;
grant select on scout.v_store_performance to anon, authenticated;
grant execute on function scout.enrich_edge_transaction(bigint) to anon, authenticated;
grant execute on function scout.get_edge_pipeline_status() to anon, authenticated;
grant execute on function scout.check_confidence_alerts() to anon, authenticated;