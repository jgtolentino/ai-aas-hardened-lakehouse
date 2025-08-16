-- Scout Edge: Edge Device Infrastructure for Raspberry Pi Fleet
-- Supports STT (Speech-to-Text) and OpenCV brand detection

-- Create edge schema
create schema if not exists edge;

-- Edge devices registry
create table if not exists edge.devices (
    device_id text primary key,
    device_name text not null,
    device_type text default 'raspberry_pi_5',
    store_id text not null,
    location jsonb,
    capabilities text[] default array['stt', 'opencv', 'motion'],
    firmware_version text,
    last_heartbeat timestamptz,
    status text default 'offline' check (status in ('online', 'offline', 'maintenance')),
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

-- Insert initial devices
insert into edge.devices (device_id, device_name, store_id, location, capabilities) values
    ('PI5_STORE_001', 'Scout Edge Alpha', 'STORE_001', '{"lat": 14.5995, "lng": 120.9842, "store": "SM Manila"}'::jsonb, array['stt', 'opencv']),
    ('PI5_STORE_002', 'Scout Edge Beta', 'STORE_002', '{"lat": 14.6090, "lng": 121.0222, "store": "Robinsons Galleria"}'::jsonb, array['stt', 'opencv']),
    ('PI5_STORE_003', 'Scout Edge Gamma', 'STORE_003', '{"lat": 14.5547, "lng": 121.0244, "store": "Ayala Center"}'::jsonb, array['stt', 'opencv', 'motion'])
on conflict (device_id) do nothing;

-- Bronze layer for raw edge events
create table if not exists edge.bronze_edge_events (
    event_id bigserial primary key,
    device_id text not null references edge.devices(device_id),
    event_type text not null check (event_type in ('stt', 'opencv', 'motion', 'heartbeat', 'error')),
    event_data jsonb not null,
    confidence numeric(3,2),
    timestamp timestamptz not null,
    processed boolean default false,
    created_at timestamptz default now()
);

-- Indexes for performance
create index if not exists idx_edge_events_device_time on edge.bronze_edge_events(device_id, timestamp desc);
create index if not exists idx_edge_events_type on edge.bronze_edge_events(event_type, processed);
create index if not exists idx_edge_events_created on edge.bronze_edge_events(created_at) where not processed;

-- Silver layer for processed transactions
create table if not exists edge.fact_edge_transactions (
    transaction_id bigserial primary key,
    device_id text not null references edge.devices(device_id),
    store_id text not null,
    transaction_time timestamptz not null,
    customer_id text,
    items jsonb not null default '[]',
    total_amount numeric(10,2),
    payment_method text,
    stt_transcript text,
    opencv_brands text[],
    confidence_score numeric(3,2),
    processing_time_ms int,
    source_events bigint[],
    created_at timestamptz default now()
);

-- SKU enrichment table
create table if not exists edge.sku_catalog (
    sku_id serial primary key,
    brand_name text not null,
    product_name text not null,
    barcode text unique,
    opencv_labels text[],
    stt_keywords text[],
    unit_price numeric(10,2),
    category text,
    active boolean default true,
    created_at timestamptz default now()
);

-- Insert sample PH brands
insert into edge.sku_catalog (brand_name, product_name, opencv_labels, stt_keywords, unit_price, category) values
    ('Lucky Me', 'Pancit Canton Original', array['lucky me', 'lucky', 'pancit'], array['lucky me', 'pancit canton'], 15.00, 'Noodles'),
    ('Nescafe', '3in1 Original', array['nescafe', 'coffee'], array['nescafe', 'coffee', 'three in one'], 8.00, 'Beverages'),
    ('San Miguel', 'Pale Pilsen', array['san miguel', 'beer'], array['san miguel', 'beer', 'pale pilsen'], 65.00, 'Beverages'),
    ('Century', 'Corned Tuna', array['century', 'tuna'], array['century tuna', 'corned tuna'], 35.00, 'Canned Goods'),
    ('Argentina', 'Corned Beef', array['argentina', 'beef'], array['argentina', 'corned beef'], 45.00, 'Canned Goods'),
    ('Kopiko', 'Brown Coffee', array['kopiko', 'coffee'], array['kopiko', 'brown coffee'], 7.50, 'Beverages'),
    ('Rebisco', 'Crackers', array['rebisco', 'crackers'], array['rebisco', 'skyflakes', 'crackers'], 8.00, 'Snacks')
on conflict (barcode) do nothing;

-- Device health metrics
create table if not exists edge.device_health (
    health_id bigserial primary key,
    device_id text not null references edge.devices(device_id),
    cpu_temp numeric(4,1),
    cpu_usage numeric(3,1),
    memory_usage numeric(3,1),
    disk_usage numeric(3,1),
    network_latency_ms int,
    error_count int default 0,
    warnings jsonb,
    measured_at timestamptz default now()
);

-- Function to ingest edge event
create or replace function edge.ingest_edge_event(
    p_device_id text,
    p_event_type text,
    p_event_data jsonb,
    p_confidence numeric default null
) returns bigint language plpgsql as $$
declare
    v_event_id bigint;
begin
    -- Update device heartbeat
    update edge.devices
    set last_heartbeat = now(),
        status = 'online',
        updated_at = now()
    where device_id = p_device_id;
    
    -- Insert event
    insert into edge.bronze_edge_events (
        device_id, event_type, event_data, confidence, timestamp
    ) values (
        p_device_id, p_event_type, p_event_data, p_confidence, now()
    ) returning event_id into v_event_id;
    
    -- Trigger processing for transaction synthesis
    if p_event_type in ('stt', 'opencv') then
        perform edge.try_synthesize_transaction(p_device_id);
    end if;
    
    return v_event_id;
end;
$$;

-- Function to synthesize transactions from events
create or replace function edge.try_synthesize_transaction(p_device_id text)
returns void language plpgsql as $$
declare
    v_stt_event record;
    v_opencv_event record;
    v_store_id text;
    v_items jsonb := '[]'::jsonb;
    v_brands text[] := '{}';
    v_total numeric := 0;
begin
    -- Get store ID
    select store_id into v_store_id
    from edge.devices where device_id = p_device_id;
    
    -- Look for recent unprocessed STT event
    select * into v_stt_event
    from edge.bronze_edge_events
    where device_id = p_device_id
      and event_type = 'stt'
      and not processed
      and timestamp > now() - interval '5 minutes'
    order by timestamp desc
    limit 1;
    
    if v_stt_event.event_id is null then
        return;
    end if;
    
    -- Look for corresponding OpenCV event within 30 seconds
    select * into v_opencv_event
    from edge.bronze_edge_events
    where device_id = p_device_id
      and event_type = 'opencv'
      and not processed
      and abs(extract(epoch from (timestamp - v_stt_event.timestamp))) < 30
    order by abs(extract(epoch from (timestamp - v_stt_event.timestamp)))
    limit 1;
    
    -- Extract brands from events
    if v_stt_event.event_data ? 'brands' then
        v_brands := array(select jsonb_array_elements_text(v_stt_event.event_data->'brands'));
    end if;
    
    if v_opencv_event.event_id is not null and v_opencv_event.event_data ? 'detected_brands' then
        v_brands := v_brands || array(select jsonb_array_elements_text(v_opencv_event.event_data->'detected_brands'));
    end if;
    
    -- Build items from detected brands
    v_items := edge.build_items_from_brands(v_brands);
    
    -- Calculate total
    select sum((item->>'price')::numeric) into v_total
    from jsonb_array_elements(v_items) as item;
    
    -- Create transaction
    insert into edge.fact_edge_transactions (
        device_id,
        store_id,
        transaction_time,
        items,
        total_amount,
        stt_transcript,
        opencv_brands,
        confidence_score,
        source_events
    ) values (
        p_device_id,
        v_store_id,
        v_stt_event.timestamp,
        v_items,
        coalesce(v_total, 0),
        v_stt_event.event_data->>'transcript',
        v_brands,
        coalesce(v_stt_event.confidence, 0.8),
        array[v_stt_event.event_id, v_opencv_event.event_id]
    );
    
    -- Mark events as processed
    update edge.bronze_edge_events
    set processed = true
    where event_id in (v_stt_event.event_id, v_opencv_event.event_id);
end;
$$;

-- Function to build items from detected brands
create or replace function edge.build_items_from_brands(p_brands text[])
returns jsonb language sql as $$
    select coalesce(
        jsonb_agg(
            jsonb_build_object(
                'sku_id', sku_id,
                'brand', brand_name,
                'product', product_name,
                'quantity', 1,
                'price', unit_price,
                'category', category
            )
        ),
        '[]'::jsonb
    )
    from edge.sku_catalog
    where brand_name = any(p_brands)
       or brand_name ilike any(
           select '%' || brand || '%' from unnest(p_brands) as brand
       );
$$;

-- Monitoring functions
create or replace function edge.get_device_status()
returns table(
    device_id text,
    device_name text,
    store_id text,
    status text,
    last_heartbeat timestamptz,
    events_24h bigint,
    transactions_24h bigint
) language sql as $$
    select 
        d.device_id,
        d.device_name,
        d.store_id,
        d.status,
        d.last_heartbeat,
        (select count(*) from edge.bronze_edge_events e 
         where e.device_id = d.device_id 
         and e.created_at > now() - interval '24 hours') as events_24h,
        (select count(*) from edge.fact_edge_transactions t 
         where t.device_id = d.device_id 
         and t.created_at > now() - interval '24 hours') as transactions_24h
    from edge.devices d
    order by d.device_id;
$$;

-- Edge analytics view
create or replace view edge.v_hourly_metrics as
select 
    date_trunc('hour', transaction_time) as hour,
    store_id,
    count(*) as transaction_count,
    sum(total_amount) as revenue,
    avg(confidence_score) as avg_confidence,
    count(distinct device_id) as active_devices
from edge.fact_edge_transactions
where transaction_time > now() - interval '7 days'
group by 1, 2;

-- Real-time dashboard view
create or replace view edge.v_realtime_activity as
select 
    e.device_id,
    d.device_name,
    d.store_id,
    e.event_type,
    e.event_data,
    e.confidence,
    e.timestamp,
    case 
        when e.timestamp > now() - interval '1 minute' then 'active'
        when e.timestamp > now() - interval '5 minutes' then 'recent'
        else 'idle'
    end as activity_status
from edge.bronze_edge_events e
join edge.devices d on e.device_id = d.device_id
where e.timestamp > now() - interval '1 hour'
order by e.timestamp desc;