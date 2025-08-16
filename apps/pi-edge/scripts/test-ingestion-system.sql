-- Scout Edge: Test Ingestion System

-- Test 1: Gmail attachment ingestion
select api.ingest_from_gmail(
    'msg_123456',
    'Scout Data Upload - Store Performance',
    'analytics@store.com',
    '[
        {"filename": "sales_data.json", "size": 1024, "id": "att_1"},
        {"filename": "inventory.csv", "size": 2048, "id": "att_2"},
        {"filename": "report.pdf", "size": 4096, "id": "att_3"}
    ]'
);

-- Test 2: Manual file upload
select api.upload_file(
    'manual_transactions.json',
    '{"store": "STORE_001", "date": "2025-08-15", "transactions": []}',
    'STORE_001'
);

-- Test 3: Google Drive ingestion
select api.ingest_from_drive(
    'drive_file_789',
    'pos_export_20250815.json',
    '/Scout Analytics/POS Exports',
    '{"exports": []}'
);

-- Test 4: Batch upload
select api.batch_ingest_files('[
    {"name": "batch1.json", "content": "{}", "store_id": "STORE_001"},
    {"name": "batch2.csv", "content": "id,name\\n1,test", "store_id": "STORE_002"}
]');

-- Check queue status
select * from scout.file_ingestion_queue order by created_at desc;

-- Check dashboard
select * from scout.get_ingestion_dashboard();

-- Check triggers
select * from scout.v_active_triggers;

-- Test edge event ingestion
select edge.ingest_edge_event(
    'PI5_STORE_001',
    'stt',
    '{
        "transcript": "customer bought lucky me pancit canton and nescafe coffee",
        "brands": ["Lucky Me", "Nescafe"],
        "confidence": 0.92
    }'::jsonb,
    0.92
);

-- Simulate OpenCV event
select edge.ingest_edge_event(
    'PI5_STORE_001',
    'opencv',
    '{
        "detected_brands": ["Lucky Me", "Nescafe"],
        "objects": ["noodles", "coffee"],
        "confidence": 0.88
    }'::jsonb,
    0.88
);

-- Check edge device status
select * from edge.get_device_status();

-- Check system health
select * from scout.get_system_health();