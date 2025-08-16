-- Scout Edge: Comprehensive File Ingestion System
-- Supports Gmail attachments, Google Drive files, and manual uploads with auto-triggers

-- Create scout schema if not exists
create schema if not exists scout;

-- File ingestion queue table
create table if not exists scout.file_ingestion_queue (
    queue_id bigserial primary key,
    file_name text not null,
    file_type text not null check (file_type in ('json', 'csv', 'zip', 'srt', 'vtt', 'excel', 'unknown')),
    file_size bigint,
    file_hash text,
    source_type text not null check (source_type in ('gmail', 'drive', 'manual', 'api')),
    source_id text, -- Gmail message ID, Drive file ID, etc.
    source_metadata jsonb default '{}',
    store_id text,
    status text default 'pending' check (status in ('pending', 'processing', 'completed', 'failed', 'retrying')),
    priority smallint default 5 check (priority between 1 and 10),
    attempts smallint default 0,
    error_message text,
    processed_at timestamptz,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

-- Indexes for performance
create index if not exists idx_queue_status_priority on scout.file_ingestion_queue(status, priority desc, created_at);
create index if not exists idx_queue_source on scout.file_ingestion_queue(source_type, source_id);
create index if not exists idx_queue_created on scout.file_ingestion_queue(created_at);

-- Auto-trigger rules table
create table if not exists scout.ingestion_triggers (
    trigger_id serial primary key,
    trigger_name text unique not null,
    source_type text not null check (source_type in ('gmail', 'drive')),
    pattern_type text not null check (pattern_type in ('subject', 'sender', 'filename', 'folder')),
    pattern text not null,
    file_types text[] default array['json', 'csv', 'zip'],
    target_store_id text,
    priority smallint default 5,
    active boolean default true,
    created_at timestamptz default now(),
    last_triggered_at timestamptz
);

-- Insert default triggers
insert into scout.ingestion_triggers (trigger_name, source_type, pattern_type, pattern, file_types, target_store_id, priority) values
    ('Scout Data Upload', 'gmail', 'subject', 'Scout Data Upload%', array['json', 'csv', 'zip'], 'STORE_001', 3),
    ('Daily Sales Report', 'gmail', 'subject', 'Daily Sales Report%', array['csv', 'excel'], null, 4),
    ('POS Export', 'gmail', 'subject', 'POS Export%', array['json', 'zip'], 'STORE_002', 2),
    ('Transcript Files', 'gmail', 'subject', 'Transcript%', array['srt', 'vtt'], 'STORE_003', 5),
    ('Manual Upload Request', 'gmail', 'subject', 'Manual Upload Request%', array['json', 'csv', 'zip', 'excel'], 'MANUAL', 6)
on conflict (trigger_name) do nothing;

-- Google Drive monitored folders
create table if not exists scout.drive_folders (
    folder_id serial primary key,
    folder_path text unique not null,
    file_patterns text[] default array['*.json', '*.csv', '*.zip'],
    target_store_id text,
    scan_frequency_minutes int default 60,
    last_scanned_at timestamptz,
    active boolean default true,
    created_at timestamptz default now()
);

-- Insert default monitored folders
insert into scout.drive_folders (folder_path, file_patterns, target_store_id) values
    ('/Scout Analytics/Data Uploads', array['*.json', '*.csv', '*.zip'], 'STORE_001'),
    ('/Scout Analytics/POS Exports', array['*.json', '*.zip'], 'STORE_002'),
    ('/Scout Analytics/Transcripts', array['*.srt', '*.vtt'], 'STORE_003')
on conflict (folder_path) do nothing;

-- Processing history table
create table if not exists scout.ingestion_history (
    history_id bigserial primary key,
    queue_id bigint references scout.file_ingestion_queue(queue_id),
    file_name text not null,
    file_type text not null,
    source_type text not null,
    store_id text,
    records_processed int default 0,
    processing_time_ms int,
    status text not null,
    error_details jsonb,
    processed_at timestamptz default now()
);

-- Function to detect file type from extension
create or replace function scout.detect_file_type(p_filename text)
returns text language sql immutable as $$
    select case 
        when lower(p_filename) like '%.json' then 'json'
        when lower(p_filename) like '%.csv' then 'csv'
        when lower(p_filename) like '%.zip' then 'zip'
        when lower(p_filename) like '%.srt' then 'srt'
        when lower(p_filename) like '%.vtt' then 'vtt'
        when lower(p_filename) like '%.xlsx' or lower(p_filename) like '%.xls' then 'excel'
        else 'unknown'
    end;
$$;

-- Function to check if file should be auto-ingested
create or replace function scout.check_auto_trigger(
    p_source_type text,
    p_metadata jsonb
) returns record language plpgsql as $$
declare
    v_trigger record;
    v_result record;
begin
    -- Check against active triggers
    for v_trigger in 
        select * from scout.ingestion_triggers 
        where source_type = p_source_type and active = true
    loop
        if p_source_type = 'gmail' then
            if v_trigger.pattern_type = 'subject' and 
               (p_metadata->>'subject')::text like v_trigger.pattern then
                v_result := (v_trigger.trigger_id, v_trigger.target_store_id, v_trigger.priority, true);
                return v_result;
            elsif v_trigger.pattern_type = 'sender' and 
                  (p_metadata->>'sender')::text like v_trigger.pattern then
                v_result := (v_trigger.trigger_id, v_trigger.target_store_id, v_trigger.priority, true);
                return v_result;
            end if;
        elsif p_source_type = 'drive' then
            if v_trigger.pattern_type = 'filename' and 
               (p_metadata->>'filename')::text like v_trigger.pattern then
                v_result := (v_trigger.trigger_id, v_trigger.target_store_id, v_trigger.priority, true);
                return v_result;
            end if;
        end if;
    end loop;
    
    -- No trigger matched
    v_result := (null::int, null::text, 5::smallint, false);
    return v_result;
end;
$$;

-- Function to ingest file from Gmail
create or replace function scout.ingest_from_gmail(
    p_message_id text,
    p_subject text,
    p_sender text,
    p_attachments jsonb
) returns int language plpgsql as $$
declare
    v_attachment jsonb;
    v_trigger record;
    v_queue_id bigint;
    v_count int := 0;
begin
    -- Check if this email triggers auto-ingestion
    select * from scout.check_auto_trigger('gmail', jsonb_build_object(
        'subject', p_subject,
        'sender', p_sender
    )) into v_trigger;
    
    -- Process each attachment
    for v_attachment in select * from jsonb_array_elements(p_attachments)
    loop
        -- Skip if file type not supported by trigger
        if v_trigger.trigger_id is not null then
            if not scout.detect_file_type(v_attachment->>'filename') = any(
                select file_types from scout.ingestion_triggers where trigger_id = v_trigger.trigger_id
            ) then
                continue;
            end if;
        end if;
        
        -- Add to queue
        insert into scout.file_ingestion_queue (
            file_name,
            file_type,
            file_size,
            source_type,
            source_id,
            source_metadata,
            store_id,
            priority
        ) values (
            v_attachment->>'filename',
            scout.detect_file_type(v_attachment->>'filename'),
            (v_attachment->>'size')::bigint,
            'gmail',
            p_message_id,
            jsonb_build_object(
                'subject', p_subject,
                'sender', p_sender,
                'attachment_id', v_attachment->>'id'
            ),
            v_trigger.target_store_id,
            v_trigger.priority
        ) returning queue_id into v_queue_id;
        
        v_count := v_count + 1;
        
        -- Update trigger last used
        if v_trigger.trigger_id is not null then
            update scout.ingestion_triggers 
            set last_triggered_at = now() 
            where trigger_id = v_trigger.trigger_id;
        end if;
    end loop;
    
    return v_count;
end;
$$;

-- Function to ingest file from Google Drive
create or replace function scout.ingest_from_drive(
    p_file_id text,
    p_file_name text,
    p_folder_path text,
    p_file_content text
) returns bigint language plpgsql as $$
declare
    v_queue_id bigint;
    v_folder record;
    v_file_hash text;
begin
    -- Calculate file hash
    v_file_hash := encode(sha256(p_file_content::bytea), 'hex');
    
    -- Check if file already processed
    if exists (
        select 1 from scout.file_ingestion_queue 
        where file_hash = v_file_hash and status = 'completed'
    ) then
        return null;
    end if;
    
    -- Get folder configuration
    select * into v_folder 
    from scout.drive_folders 
    where folder_path = p_folder_path and active = true;
    
    -- Add to queue
    insert into scout.file_ingestion_queue (
        file_name,
        file_type,
        file_size,
        file_hash,
        source_type,
        source_id,
        source_metadata,
        store_id,
        priority
    ) values (
        p_file_name,
        scout.detect_file_type(p_file_name),
        length(p_file_content),
        v_file_hash,
        'drive',
        p_file_id,
        jsonb_build_object(
            'folder_path', p_folder_path,
            'drive_file_id', p_file_id
        ),
        v_folder.target_store_id,
        4
    ) returning queue_id into v_queue_id;
    
    -- Update folder last scanned
    if v_folder.folder_id is not null then
        update scout.drive_folders 
        set last_scanned_at = now() 
        where folder_id = v_folder.folder_id;
    end if;
    
    return v_queue_id;
end;
$$;

-- Function for manual file upload
create or replace function scout.upload_file(
    p_file_name text,
    p_file_content text,
    p_store_id text default null
) returns bigint language plpgsql as $$
declare
    v_queue_id bigint;
    v_file_hash text;
begin
    -- Calculate file hash
    v_file_hash := encode(sha256(p_file_content::bytea), 'hex');
    
    -- Add to queue with high priority
    insert into scout.file_ingestion_queue (
        file_name,
        file_type,
        file_size,
        file_hash,
        source_type,
        source_id,
        store_id,
        priority
    ) values (
        p_file_name,
        scout.detect_file_type(p_file_name),
        length(p_file_content),
        v_file_hash,
        'manual',
        'manual_' || extract(epoch from now())::text,
        p_store_id,
        2  -- High priority for manual uploads
    ) returning queue_id into v_queue_id;
    
    return v_queue_id;
end;
$$;

-- Function to process next file in queue
create or replace function scout.process_next_file()
returns bigint language plpgsql as $$
declare
    v_file record;
    v_start_time timestamptz;
    v_end_time timestamptz;
    v_records_processed int := 0;
begin
    -- Get next file to process
    select * into v_file
    from scout.file_ingestion_queue
    where status in ('pending', 'retrying')
    order by priority asc, created_at asc
    limit 1
    for update skip locked;
    
    if v_file.queue_id is null then
        return null;
    end if;
    
    -- Update status to processing
    update scout.file_ingestion_queue
    set status = 'processing',
        attempts = attempts + 1,
        updated_at = now()
    where queue_id = v_file.queue_id;
    
    v_start_time := clock_timestamp();
    
    -- Process based on file type
    begin
        case v_file.file_type
            when 'json' then
                -- Process JSON file
                v_records_processed := scout.process_json_file(v_file.queue_id);
            when 'csv' then
                -- Process CSV file
                v_records_processed := scout.process_csv_file(v_file.queue_id);
            when 'zip' then
                -- Process ZIP file
                v_records_processed := scout.process_zip_file(v_file.queue_id);
            else
                -- Unsupported type
                raise exception 'Unsupported file type: %', v_file.file_type;
        end case;
        
        v_end_time := clock_timestamp();
        
        -- Update to completed
        update scout.file_ingestion_queue
        set status = 'completed',
            processed_at = now(),
            updated_at = now()
        where queue_id = v_file.queue_id;
        
        -- Record history
        insert into scout.ingestion_history (
            queue_id, file_name, file_type, source_type, store_id,
            records_processed, processing_time_ms, status
        ) values (
            v_file.queue_id, v_file.file_name, v_file.file_type, 
            v_file.source_type, v_file.store_id, v_records_processed,
            extract(milliseconds from (v_end_time - v_start_time))::int,
            'completed'
        );
        
    exception when others then
        -- Update to failed
        update scout.file_ingestion_queue
        set status = case when attempts >= 3 then 'failed' else 'retrying' end,
            error_message = sqlerrm,
            updated_at = now()
        where queue_id = v_file.queue_id;
        
        -- Record failure
        insert into scout.ingestion_history (
            queue_id, file_name, file_type, source_type, store_id,
            status, error_details
        ) values (
            v_file.queue_id, v_file.file_name, v_file.file_type,
            v_file.source_type, v_file.store_id, 'failed',
            jsonb_build_object('error', sqlerrm, 'state', sqlstate)
        );
        
        return null;
    end;
    
    return v_file.queue_id;
end;
$$;

-- Placeholder functions for file processing (to be implemented based on your data schema)
create or replace function scout.process_json_file(p_queue_id bigint)
returns int language plpgsql as $$
begin
    -- TODO: Implement JSON processing logic
    -- This should parse JSON and insert into appropriate tables
    return 0;
end;
$$;

create or replace function scout.process_csv_file(p_queue_id bigint)
returns int language plpgsql as $$
begin
    -- TODO: Implement CSV processing logic
    -- This should parse CSV and insert into appropriate tables
    return 0;
end;
$$;

create or replace function scout.process_zip_file(p_queue_id bigint)
returns int language plpgsql as $$
begin
    -- TODO: Implement ZIP processing logic
    -- This should extract files and process each one
    return 0;
end;
$$;

-- Function to batch ingest multiple files
create or replace function scout.batch_ingest_files(p_files jsonb)
returns int language plpgsql as $$
declare
    v_file jsonb;
    v_count int := 0;
begin
    for v_file in select * from jsonb_array_elements(p_files)
    loop
        perform scout.upload_file(
            v_file->>'name',
            v_file->>'content',
            v_file->>'store_id'
        );
        v_count := v_count + 1;
    end loop;
    
    return v_count;
end;
$$;

-- Monitoring views
create or replace view scout.v_ingestion_queue_status as
select 
    status,
    count(*) as file_count,
    min(created_at) as oldest_file,
    max(created_at) as newest_file,
    avg(attempts) as avg_attempts
from scout.file_ingestion_queue
group by status;

create or replace view scout.v_ingestion_performance as
select 
    date_trunc('hour', processed_at) as hour,
    source_type,
    count(*) as files_processed,
    sum(records_processed) as total_records,
    avg(processing_time_ms) as avg_processing_ms,
    count(*) filter (where status = 'completed') as successful,
    count(*) filter (where status = 'failed') as failed
from scout.ingestion_history
where processed_at > now() - interval '24 hours'
group by 1, 2
order by 1 desc, 2;

create or replace view scout.v_active_triggers as
select 
    t.trigger_name,
    t.source_type,
    t.pattern_type,
    t.pattern,
    t.file_types,
    t.priority,
    t.last_triggered_at,
    count(q.queue_id) as files_triggered
from scout.ingestion_triggers t
left join scout.file_ingestion_queue q on q.source_metadata->>'trigger_id' = t.trigger_id::text
where t.active = true
group by t.trigger_id, t.trigger_name, t.source_type, t.pattern_type, 
         t.pattern, t.file_types, t.priority, t.last_triggered_at
order by t.priority asc;