-- Scout Edge: Comprehensive Ingestion Dashboard and Helper Functions

-- API schema for clean function access
create schema if not exists api;

-- Helper function to get ingestion dashboard
create or replace function scout.get_ingestion_dashboard()
returns table(
    metric text,
    value text,
    details jsonb
) language sql as $$
    -- Queue status
    select 'Queue Status' as metric, 
           count(*)::text || ' files' as value,
           jsonb_build_object(
               'pending', count(*) filter (where status = 'pending'),
               'processing', count(*) filter (where status = 'processing'),
               'completed', count(*) filter (where status = 'completed'),
               'failed', count(*) filter (where status = 'failed')
           ) as details
    from scout.file_ingestion_queue
    
    union all
    
    -- Processing rate
    select 'Processing Rate (24h)' as metric,
           count(*)::text || ' files/hour' as value,
           jsonb_build_object(
               'total_files', count(*),
               'total_records', sum(records_processed),
               'avg_time_ms', round(avg(processing_time_ms))
           ) as details
    from scout.ingestion_history
    where processed_at > now() - interval '24 hours'
    
    union all
    
    -- Active triggers
    select 'Active Triggers' as metric,
           count(*)::text as value,
           jsonb_agg(jsonb_build_object(
               'name', trigger_name,
               'pattern', pattern,
               'last_triggered', last_triggered_at
           )) as details
    from scout.ingestion_triggers
    where active = true
    
    union all
    
    -- Monitored folders
    select 'Drive Folders' as metric,
           count(*)::text as value,
           jsonb_agg(jsonb_build_object(
               'path', folder_path,
               'last_scan', last_scanned_at
           )) as details
    from scout.drive_folders
    where active = true
    
    union all
    
    -- Success rate
    select 'Success Rate (7d)' as metric,
           round(100.0 * count(*) filter (where status = 'completed') / 
                 nullif(count(*), 0), 1)::text || '%' as value,
           jsonb_build_object(
               'completed', count(*) filter (where status = 'completed'),
               'failed', count(*) filter (where status = 'failed'),
               'total', count(*)
           ) as details
    from scout.ingestion_history
    where processed_at > now() - interval '7 days';
$$;

-- API wrapper for Gmail ingestion
create or replace function api.ingest_from_gmail(
    message_id text,
    subject text,
    sender text,
    attachments_json text
) returns jsonb language plpgsql as $$
declare
    v_count int;
begin
    v_count := scout.ingest_from_gmail(
        message_id, subject, sender, attachments_json::jsonb
    );
    
    return jsonb_build_object(
        'success', true,
        'files_queued', v_count,
        'message', format('%s files queued for processing', v_count)
    );
exception when others then
    return jsonb_build_object(
        'success', false,
        'error', sqlerrm
    );
end;
$$;

-- API wrapper for manual upload
create or replace function api.upload_file(
    file_name text,
    file_content text,
    store_id text default null
) returns jsonb language plpgsql as $$
declare
    v_queue_id bigint;
begin
    v_queue_id := scout.upload_file(file_name, file_content, store_id);
    
    return jsonb_build_object(
        'success', true,
        'queue_id', v_queue_id,
        'message', format('File %s queued for processing', file_name)
    );
exception when others then
    return jsonb_build_object(
        'success', false,
        'error', sqlerrm
    );
end;
$$;

-- API wrapper for batch upload
create or replace function api.batch_ingest_files(files_json text)
returns jsonb language plpgsql as $$
declare
    v_count int;
begin
    v_count := scout.batch_ingest_files(files_json::jsonb);
    
    return jsonb_build_object(
        'success', true,
        'files_queued', v_count,
        'message', format('%s files queued for processing', v_count)
    );
exception when others then
    return jsonb_build_object(
        'success', false,
        'error', sqlerrm
    );
end;
$$;

-- API wrapper for Drive ingestion
create or replace function api.ingest_from_drive(
    file_id text,
    file_name text,
    folder_path text,
    content text
) returns jsonb language plpgsql as $$
declare
    v_queue_id bigint;
begin
    v_queue_id := scout.ingest_from_drive(file_id, file_name, folder_path, content);
    
    if v_queue_id is null then
        return jsonb_build_object(
            'success', false,
            'message', 'File already processed (duplicate hash)'
        );
    end if;
    
    return jsonb_build_object(
        'success', true,
        'queue_id', v_queue_id,
        'message', format('File %s queued for processing', file_name)
    );
exception when others then
    return jsonb_build_object(
        'success', false,
        'error', sqlerrm
    );
end;
$$;

-- Process queue function for scheduled jobs
create or replace function scout.process_file_queue(p_batch_size int default 10)
returns int language plpgsql as $$
declare
    v_processed int := 0;
    i int;
begin
    for i in 1..p_batch_size loop
        exit when scout.process_next_file() is null;
        v_processed := v_processed + 1;
    end loop;
    
    return v_processed;
end;
$$;

-- Add trigger management functions
create or replace function scout.add_ingestion_trigger(
    p_name text,
    p_source_type text,
    p_pattern_type text,
    p_pattern text,
    p_file_types text[],
    p_store_id text default null,
    p_priority smallint default 5
) returns int language plpgsql as $$
declare
    v_trigger_id int;
begin
    insert into scout.ingestion_triggers (
        trigger_name, source_type, pattern_type, pattern,
        file_types, target_store_id, priority
    ) values (
        p_name, p_source_type, p_pattern_type, p_pattern,
        p_file_types, p_store_id, p_priority
    ) returning trigger_id into v_trigger_id;
    
    return v_trigger_id;
end;
$$;

-- Edge-Scout integration view
create or replace view scout.v_edge_integrated_transactions as
select 
    t.transaction_id,
    t.device_id,
    t.store_id,
    t.transaction_time,
    t.total_amount,
    t.items,
    t.confidence_score,
    'edge' as source_system
from edge.fact_edge_transactions t

union all

select 
    h.history_id as transaction_id,
    'FILE_INGEST' as device_id,
    h.store_id,
    h.processed_at as transaction_time,
    0 as total_amount,  -- Would come from processed file data
    jsonb_build_object('records', h.records_processed) as items,
    1.0 as confidence_score,
    'file' as source_system
from scout.ingestion_history h
where h.status = 'completed';

-- Comprehensive monitoring dashboard
create or replace function scout.get_system_health()
returns table(
    component text,
    status text,
    metrics jsonb
) language sql as $$
    -- File ingestion health
    select 'File Ingestion' as component,
           case 
               when count(*) filter (where status = 'failed') > 10 then 'critical'
               when count(*) filter (where status = 'pending') > 100 then 'warning'
               else 'healthy'
           end as status,
           jsonb_build_object(
               'pending', count(*) filter (where status = 'pending'),
               'failed_24h', count(*) filter (where status = 'failed' and updated_at > now() - interval '24 hours'),
               'completed_24h', count(*) filter (where status = 'completed' and processed_at > now() - interval '24 hours')
           ) as metrics
    from scout.file_ingestion_queue
    
    union all
    
    -- Edge devices health
    select 'Edge Devices' as component,
           case 
               when count(*) filter (where status = 'offline') > 1 then 'critical'
               when count(*) filter (where last_heartbeat < now() - interval '10 minutes') > 0 then 'warning'
               else 'healthy'
           end as status,
           jsonb_build_object(
               'online', count(*) filter (where status = 'online'),
               'offline', count(*) filter (where status = 'offline'),
               'total_events_24h', (select count(*) from edge.bronze_edge_events where created_at > now() - interval '24 hours')
           ) as metrics
    from edge.devices
    
    union all
    
    -- Processing performance
    select 'Processing Performance' as component,
           case 
               when avg(processing_time_ms) > 5000 then 'warning'
               when count(*) = 0 then 'critical'
               else 'healthy'
           end as status,
           jsonb_build_object(
               'avg_time_ms', round(avg(processing_time_ms)),
               'files_per_hour', round(count(*) / 24.0, 1),
               'success_rate', round(100.0 * count(*) filter (where status = 'completed') / nullif(count(*), 0), 1)
           ) as metrics
    from scout.ingestion_history
    where processed_at > now() - interval '24 hours';
$$;

-- Grant permissions for API functions
grant execute on function api.ingest_from_gmail(text, text, text, text) to anon, authenticated;
grant execute on function api.upload_file(text, text, text) to anon, authenticated;
grant execute on function api.batch_ingest_files(text) to anon, authenticated;
grant execute on function api.ingest_from_drive(text, text, text, text) to anon, authenticated;

-- Schedule processing (requires pg_cron)
-- select cron.schedule('process-file-queue', '*/5 * * * *', $$select scout.process_file_queue(10)$$);