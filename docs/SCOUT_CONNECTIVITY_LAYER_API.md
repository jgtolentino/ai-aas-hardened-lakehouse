# 🔗 Scout Connectivity Layer API Documentation (Production-Ready)

**Complete API guide for Scout v5.2 Edge Device Monitoring, inspired by QIAsphere IoT architecture.**

## 🚀 Quick Start

### Base URL
```
https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/
```

### Authentication Headers
```bash
# For all edge device requests
curl -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
     -H "Authorization: Bearer <device_service_token>" \
     -H "Content-Type: application/json"
```

**⚠️ Important**: Edge devices use service role tokens, while dashboard users use regular JWT tokens.

---

## 🔐 Authentication & Schema Headers

### Schema Headers for Connectivity Layer

The Scout Connectivity Layer operates within the `scout` schema with specific access patterns:

| Operation | Header | Purpose | Example |
|-----------|--------|---------|---------|
| **Device Health Read** | `Accept-Profile: scout` | Read device metrics and status | `GET /edge_health` |
| **Device Registration** | `Content-Profile: scout` | Register new edge devices | `POST /edge_devices` |
| **Alert Management** | `Accept-Profile: scout` | Query active alerts | `GET /alerts` |
| **Health Updates** | `Content-Profile: scout` | Submit telemetry data | `POST /edge_health` |

### Authentication Flow for Edge Devices

**Device Registration & Token Exchange:**
```bash
# 1. Register device with MAC address
curl -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
     -H "Authorization: Bearer <service_role_token>" \
     -H "Content-Profile: scout" \
     -H "Content-Type: application/json" \
     -X POST \
     -d '{
       "device_name": "Store-001-POS-Terminal",
       "device_type": "raspberry_pi_5",
       "store_id": "store_123",
       "mac_address": "aa:bb:cc:dd:ee:ff",
       "device_config": {
         "heartbeat_interval": 30,
         "sync_interval": 300,
         "alert_thresholds": {
           "cpu_warning": 70,
           "cpu_critical": 90,
           "memory_warning": 75,
           "memory_critical": 90
         }
       }
     }' \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/rpc/fn_register_edge_device"

# 2. Subsequent health updates use device-specific token
curl -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
     -H "Authorization: Bearer <device_token>" \
     -H "Content-Profile: scout" \
     -H "Content-Type: application/json" \
     -X POST \
     -d '{
       "device_id": "dev_uuid_here",
       "health_data": {
         "cpu_usage": 45.2,
         "memory_usage": 68.1,
         "disk_usage": 23.5,
         "temperature": 42.1,
         "uptime_seconds": 86400,
         "latency_ms": 25,
         "wifi_signal": -45,
         "detection_accuracy": 0.94,
         "transactions_today": 127,
         "queue_size": 3
       }
     }' \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/rpc/fn_update_device_health"
```

**Dashboard Authentication (Store Managers):**
```bash
# Store managers see only their store's devices
curl -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
     -H "Authorization: Bearer <user_jwt_token>" \
     -H "Accept-Profile: scout" \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/v_device_dashboard?store_id=eq.store_123"
```

---

## 📊 Pagination & Count for Device Data

### Real-time Device Health (Large Datasets)

```bash
# Get first 20 health records with total count
curl -H "Range: 0-19" \
     -H "Prefer: count=exact" \
     -H "Accept-Profile: scout" \
     -H "Authorization: Bearer <token>" \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/edge_health?order=timestamp.desc"

# Response includes:
# Content-Range: 0-19/15420 (showing 20 of 15,420 health records)
```

### Sync Logs Pagination

```bash
# Get sync logs for last 24 hours with pagination
curl -H "Range: 0-49" \
     -H "Prefer: count=estimated" \
     -H "Accept-Profile: scout" \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/sync_logs?sync_started=gte.2025-08-23T00:00:00Z&order=sync_started.desc"
```

### Alert History Pagination

```bash
# Get resolved alerts with count
curl -H "Range: 0-29" \
     -H "Prefer: count=exact" \
     -H "Accept-Profile: scout" \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/alerts?status=eq.resolved&order=resolved_at.desc"
```

**JavaScript Pagination for Device Dashboard:**
```javascript
async function getDeviceHealthHistory(deviceId, page = 0, pageSize = 50) {
  const start = page * pageSize;
  const end = start + pageSize - 1;
  
  const response = await fetch(`${baseURL}/edge_health`, {
    headers: {
      'apikey': ANON_KEY,
      'Authorization': `Bearer ${userToken}`,
      'Accept-Profile': 'scout',
      'Range': `${start}-${end}`,
      'Prefer': 'count=exact'
    },
    method: 'GET'
  });
  
  const healthData = await response.json();
  const contentRange = response.headers.get('Content-Range');
  const totalCount = parseInt(contentRange.split('/')[1]);
  
  return {
    healthRecords: healthData,
    totalCount,
    currentPage: page,
    hasNextPage: (start + pageSize) < totalCount,
    avgCpuUsage: healthData.reduce((sum, h) => sum + h.cpu_usage, 0) / healthData.length
  };
}
```

---

## 🔍 Filtering Cheatsheet for IoT Data

### Device Status Filtering

| Filter | Example | Description |
|--------|---------|-------------|
| Device Type | `?device_type=eq.raspberry_pi_5` | Filter by hardware type |
| Online Status | `?is_active=eq.true&last_checkin=gte.2025-08-24T00:00:00Z` | Active devices only |
| Health Status | `?status=in.(healthy,warning)` | Exclude critical devices |
| Store Location | `?store_id=eq.store_123` | Single store devices |
| Multiple Stores | `?store_id=in.(store_123,store_456,store_789)` | Multi-store view |

### Time-Based Health Filtering

```bash
# Health records from last hour
?timestamp=gte.2025-08-24T09:00:00Z&timestamp=lt.2025-08-24T10:00:00Z

# Critical alerts from today
?created_at=gte.2025-08-24T00:00:00Z&severity=eq.critical&status=eq.active

# Devices with high CPU usage
?cpu_usage=gte.80&timestamp=gte.2025-08-24T09:00:00Z

# Sync failures in last 24 hours
?sync_started=gte.2025-08-23T00:00:00Z&success=eq.false&retry_count=gte.3
```

### Advanced IoT Filtering

```bash
# Devices with poor connectivity
?network_latency_ms=gte.100&wifi_signal_strength=lte.-70

# Low battery devices (if applicable)
?device_config->>battery_level=lt.20

# Devices needing firmware updates
?firmware_version=neq.v2.1.0&is_active=eq.true

# Brand detection accuracy issues
?brand_detection_accuracy=lt.0.85&transactions_processed_today=gt.10

# Temperature alerts for specific device types
?device_type=eq.raspberry_pi_5&temperature_celsius=gte.60
```

### Complex Multi-Condition Filtering

```bash
# Problematic devices: offline OR high resource usage OR low accuracy
?or=(last_checkin.lt.2025-08-24T08:00:00Z,and(cpu_usage.gte.85,memory_usage.gte.85),brand_detection_accuracy.lt.0.80)

# Store health summary: active devices with recent data
?and=(is_active.eq.true,last_checkin.gte.2025-08-24T08:00:00Z,store_id.eq.store_123)

# Sync issues: multiple failures or long duration
?and=(success.eq.false,or(retry_count.gte.3,duration_ms.gte.30000))
```

---

## 🔄 RPC Functions for Connectivity Layer

### Uniform Naming Convention

All Connectivity Layer RPC functions follow: `fn_<domain>_<action>`

#### Device Management Functions
```bash
# Device lifecycle management
POST /rpc/fn_device_register          # Register new edge device
POST /rpc/fn_device_update_health     # Submit health telemetry  
POST /rpc/fn_device_heartbeat         # Simple keepalive ping
POST /rpc/fn_device_sync_config       # Update device configuration
POST /rpc/fn_device_firmware_update   # Trigger firmware update
```

#### Health Monitoring Functions  
```bash
# System health analysis
POST /rpc/fn_health_get_dashboard     # Get store health overview
POST /rpc/fn_health_trend_analysis    # Health metrics over time
POST /rpc/fn_health_predict_failure   # Predictive maintenance alerts
POST /rpc/fn_health_resource_optimize # Resource usage optimization
```

#### Alert Management Functions
```bash
# Alert lifecycle and notifications
POST /rpc/fn_alert_create_custom      # Create custom alert rules
POST /rpc/fn_alert_acknowledge        # Mark alert as acknowledged
POST /rpc/fn_alert_resolve            # Resolve alert with notes
POST /rpc/fn_alert_escalate          # Escalate unresolved alerts
POST /rpc/fn_alert_notify_manager     # Send notification to store manager
```

#### Sync & Communication Functions
```bash
# Data synchronization management
POST /rpc/fn_sync_initiate_full       # Start full data sync
POST /rpc/fn_sync_retry_failed        # Retry failed sync operations
POST /rpc/fn_sync_get_status          # Get sync status for device
POST /rpc/fn_sync_cleanup_logs        # Archive old sync logs
```

### RPC Request Examples

**Device Health Dashboard:**
```bash
curl -X POST \
     -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
     -H "Authorization: Bearer <user_jwt_token>" \
     -H "Content-Profile: scout" \
     -H "Content-Type: application/json" \
     -d '{
       "store_id": "store_123",
       "time_range": "24h",
       "include_metrics": ["cpu", "memory", "connectivity", "alerts"],
       "group_by": "device_type"
     }' \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/rpc/fn_health_get_dashboard"
```

**Predictive Failure Analysis:**
```bash
curl -X POST \
     -H "Content-Profile: scout" \
     -H "Content-Type: application/json" \
     -d '{
       "device_id": "dev_uuid_here",
       "prediction_window": "7d",
       "include_recommendations": true,
       "alert_threshold": 0.8
     }' \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/rpc/fn_health_predict_failure"
```

**Custom Alert Creation:**
```bash
curl -X POST \
     -H "Content-Profile: scout" \
     -H "Content-Type: application/json" \
     -d '{
       "alert_name": "High Transaction Failure Rate",
       "device_id": "dev_uuid_here",
       "condition": {
         "metric": "transaction_success_rate",
         "operator": "lt",
         "threshold": 0.95,
         "duration": "5m"
       },
       "severity": "warning",
       "notification_channels": ["push", "email"],
       "auto_resolve": true
     }' \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/rpc/fn_alert_create_custom"
```

---

## ✏️ Write Operations for Edge Devices

### Device Registration with Content-Profile

**Register Raspberry Pi 5 with full config:**
```bash
curl -X POST \
     -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
     -H "Authorization: Bearer <service_role_token>" \
     -H "Content-Profile: scout" \
     -H "Content-Type: application/json" \
     -H "Prefer: return=representation" \
     -d '{
       "device_name": "Sari-Sari-Store-POS-01",
       "device_type": "raspberry_pi_5",
       "store_id": "store_456",
       "mac_address": "b8:27:eb:12:34:56",
       "ip_address": "192.168.1.100",
       "firmware_version": "v2.1.0",
       "device_config": {
         "heartbeat_interval": 30,
         "sync_interval": 300,
         "health_report_interval": 60,
         "alert_thresholds": {
           "cpu_warning": 75,
           "cpu_critical": 90,
           "memory_warning": 80,
           "memory_critical": 95,
           "disk_warning": 85,
           "disk_critical": 95,
           "temperature_warning": 65,
           "temperature_critical": 75
         },
         "features": {
           "brand_detection": true,
           "inventory_tracking": true,
           "price_monitoring": true,
           "customer_analytics": false
         }
       }
     }' \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/edge_devices"
```

### Bulk Health Data Submission

**Submit multiple health records:**
```bash
curl -X POST \
     -H "Content-Profile: scout" \
     -H "Content-Type: application/json" \
     -H "Prefer: return=minimal" \
     -d '[
       {
         "device_id": "dev_uuid_1",
         "timestamp": "2025-08-24T10:15:00Z",
         "cpu_usage": 45.2,
         "memory_usage": 68.1,
         "disk_usage": 23.5,
         "temperature_celsius": 42.1,
         "uptime_seconds": 86400,
         "network_latency_ms": 25,
         "wifi_signal_strength": -45,
         "is_online": true,
         "brand_detection_accuracy": 0.94,
         "transactions_processed_today": 127,
         "queue_size": 3,
         "status": "healthy"
       },
       {
         "device_id": "dev_uuid_2", 
         "timestamp": "2025-08-24T10:15:00Z",
         "cpu_usage": 82.7,
         "memory_usage": 91.3,
         "disk_usage": 67.8,
         "temperature_celsius": 58.4,
         "uptime_seconds": 172800,
         "network_latency_ms": 78,
         "wifi_signal_strength": -62,
         "is_online": true,
         "brand_detection_accuracy": 0.87,
         "transactions_processed_today": 89,
         "queue_size": 12,
         "status": "warning"
       }
     ]' \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/edge_health"
```

### UPSERT Device Configuration

**Update device config with conflict resolution:**
```bash
curl -X POST \
     -H "Content-Profile: scout" \
     -H "Content-Type: application/json" \
     -H "Prefer: resolution=merge-duplicates,return=representation" \
     -H "On-Conflict: device_id" \
     -d '{
       "device_id": "dev_uuid_here",
       "device_name": "Updated-Store-POS-Terminal",
       "firmware_version": "v2.2.0",
       "device_config": {
         "heartbeat_interval": 15,
         "sync_interval": 180,
         "alert_thresholds": {
           "cpu_warning": 70,
           "cpu_critical": 85
         },
         "features": {
           "brand_detection": true,
           "inventory_tracking": true,
           "price_monitoring": true,
           "customer_analytics": true,
           "predictive_maintenance": true
         }
       },
       "updated_at": "2025-08-24T10:30:00Z"
     }' \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/edge_devices"
```

### Alert Management Updates

**Acknowledge and resolve alerts:**
```bash
curl -X PATCH \
     -H "Content-Profile: scout" \
     -H "Content-Type: application/json" \
     -H "Prefer: return=representation" \
     -d '{
       "status": "acknowledged",
       "acknowledged_at": "2025-08-24T10:30:00Z",
       "acknowledged_by": "user_uuid_here"
     }' \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/alerts?id=eq.alert_uuid&status=eq.active"

# Resolve with resolution notes
curl -X PATCH \
     -H "Content-Profile: scout" \
     -H "Content-Type: application/json" \
     -d '{
       "status": "resolved",
       "resolved_at": "2025-08-24T10:45:00Z",
       "resolved_by": "user_uuid_here",
       "resolution_notes": "Restarted device service, CPU usage normalized. Updated monitoring thresholds."
     }' \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/alerts?id=eq.alert_uuid"
```

---

## 🔄 Realtime Subscriptions for IoT Monitoring

### Prerequisites for IoT Realtime

1. **Enable Realtime** on connectivity tables in Supabase dashboard:
   - `scout.edge_devices`
   - `scout.edge_health`
   - `scout.alerts`
   - `scout.sync_logs`

2. **Configure RLS policies** for realtime access:
```sql
-- Allow store managers to subscribe to their store's device updates
CREATE POLICY "realtime_device_access" ON scout.edge_devices
    FOR SELECT USING (
        store_id IN (
            SELECT store_id FROM scout.user_store_access 
            WHERE user_id = auth.uid()
        )
    );
```

3. **Install Supabase JS client** for dashboard applications

### Real-time Device Health Monitoring

```javascript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'https://cxzllzyxwpyptfretryc.supabase.co',
  'your-anon-key'
)

class ConnectivityMonitor {
  constructor(storeId) {
    this.storeId = storeId;
    this.subscriptions = [];
    this.setupRealtimeSubscriptions();
  }

  setupRealtimeSubscriptions() {
    // Monitor device health updates
    const healthSubscription = supabase
      .channel('device_health_monitor')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'scout',
          table: 'edge_health',
          filter: `device_id=in.(${this.getDeviceIds().join(',')})`
        },
        (payload) => {
          this.handleHealthUpdate(payload.new);
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'UPDATE', 
          schema: 'scout',
          table: 'edge_devices',
          filter: `store_id=eq.${this.storeId}`
        },
        (payload) => {
          this.handleDeviceUpdate(payload.new);
        }
      )
      .subscribe();

    // Monitor new alerts
    const alertSubscription = supabase
      .channel('alert_monitor')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'scout',
          table: 'alerts',
          filter: `store_id=eq.${this.storeId}`
        },
        (payload) => {
          this.handleNewAlert(payload.new);
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'scout', 
          table: 'alerts',
          filter: `store_id=eq.${this.storeId}`
        },
        (payload) => {
          this.handleAlertStatusChange(payload.new, payload.old);
        }
      )
      .subscribe();

    // Monitor sync operations
    const syncSubscription = supabase
      .channel('sync_monitor')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'scout',
          table: 'sync_logs',
          filter: `success=eq.false` // Only failed syncs
        },
        (payload) => {
          this.handleSyncFailure(payload.new);
        }
      )
      .subscribe();

    this.subscriptions.push(healthSubscription, alertSubscription, syncSubscription);
  }

  handleHealthUpdate(healthData) {
    // Update real-time dashboard
    this.updateDeviceHealthDisplay(healthData);
    
    // Check for threshold violations
    if (healthData.cpu_usage > 90 || healthData.memory_usage > 90) {
      this.showCriticalAlert({
        type: 'resource_critical',
        deviceId: healthData.device_id,
        metrics: {
          cpu: healthData.cpu_usage,
          memory: healthData.memory_usage
        }
      });
    }
    
    // Update health trend charts
    this.updateHealthTrends(healthData.device_id, healthData);
  }

  handleNewAlert(alert) {
    // Show real-time notification
    this.showNotification({
      title: alert.title,
      message: alert.message,
      severity: alert.severity,
      deviceId: alert.device_id
    });
    
    // Update alert counter
    this.incrementAlertCount(alert.severity);
    
    // Add to alert list
    this.addToAlertList(alert);
    
    // Trigger sound/vibration for critical alerts
    if (alert.severity === 'critical') {
      this.triggerCriticalAlertSound();
    }
  }

  handleDeviceUpdate(device) {
    // Update device status in UI
    this.updateDeviceStatus(device.device_id, {
      isOnline: device.last_checkin > new Date(Date.now() - 5 * 60 * 1000),
      lastSeen: device.last_checkin,
      firmwareVersion: device.firmware_version
    });
  }

  handleSyncFailure(syncLog) {
    // Show sync failure notification
    this.showSyncFailureAlert({
      deviceId: syncLog.device_id,
      errorCode: syncLog.error_code,
      errorMessage: syncLog.error_message,
      retryCount: syncLog.retry_count
    });
  }

  cleanup() {
    this.subscriptions.forEach(sub => sub.unsubscribe());
  }
}
```

### Device-Specific Realtime Subscriptions

```javascript
// Subscribe to specific device health
const deviceHealthSub = supabase
  .channel('device_specific_health')
  .on(
    'postgres_changes',
    {
      event: '*', // All events
      schema: 'scout',
      table: 'edge_health',
      filter: 'device_id=eq.dev_uuid_here'
    },
    (payload) => {
      if (payload.eventType === 'INSERT') {
        updateHealthChart(payload.new);
      }
    }
  )
  .subscribe();

// Subscribe to store-wide connectivity changes
const storeConnectivitySub = supabase
  .channel('store_connectivity')
  .on(
    'postgres_changes',
    {
      event: 'UPDATE',
      schema: 'scout',
      table: 'edge_devices', 
      filter: 'store_id=eq.store_123'
    },
    (payload) => {
      // Device came online/offline
      const isOnline = payload.new.last_checkin > new Date(Date.now() - 5 * 60 * 1000);
      updateDeviceConnectionStatus(payload.new.device_id, isOnline);
    }
  )
  .subscribe();
```

---

## ❌ Error Handling & Troubleshooting for IoT

### Common IoT-Specific Errors

| Status | Description | IoT Context | Solution |
|--------|-------------|-------------|----------|
| `400` | Bad Request | Invalid device health data format | Validate JSON schema |
| `401` | Unauthorized | Device token expired/invalid | Re-authenticate device |
| `403` | Forbidden | Device not authorized for store | Check device-store mapping |
| `404` | Not Found | Device ID not registered | Register device first |
| `409` | Conflict | Duplicate MAC address registration | Check existing devices |
| `422` | Unprocessable | Health metrics out of valid range | Validate sensor readings |
| `429` | Too Many Requests | Device sending data too frequently | Implement rate limiting |
| `500` | Internal Error | Database connection issues | Check connectivity |

### Detailed IoT Error Responses

**Device Registration Conflict:**
```json
{
  "code": "23505",
  "message": "duplicate key value violates unique constraint \"edge_devices_mac_address_key\"",
  "details": "Key (mac_address)=(aa:bb:cc:dd:ee:ff) already exists.",
  "hint": "Check if device is already registered or use UPSERT"
}
```

**Health Data Validation Error:**
```json
{
  "code": "23514", 
  "message": "new row for relation \"edge_health\" violates check constraint \"edge_health_cpu_usage_check\"",
  "details": "Failing row contains (cpu_usage: 150.0)",
  "hint": "CPU usage must be between 0 and 100"
}
```

**RLS Permission Error:**
```json
{
  "code": "42501",
  "message": "permission denied for table edge_devices",
  "details": "Device token does not have access to this store",
  "hint": "Verify device is registered to correct store_id"
}
```

### IoT-Specific Troubleshooting Scenarios

#### 1. Device Can't Register
**Symptoms:** 403/404 errors on device registration

**Diagnosis:**
```bash
# Check if MAC address already exists
curl -H "Accept-Profile: scout" \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/edge_devices?mac_address=eq.aa:bb:cc:dd:ee:ff"

# Verify store exists
curl -H "Accept-Profile: scout" \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/dim_stores?store_id=eq.store_123"
```

**Solutions:**
- Use UPSERT instead of INSERT
- Verify store_id is valid
- Check service role token permissions

#### 2. Health Data Rejected
**Symptoms:** 422 validation errors

**Common Validation Issues:**
```javascript
// ❌ Invalid health data
{
  cpu_usage: 150.0,        // Must be 0-100
  memory_usage: -10.5,     // Must be positive
  wifi_signal_strength: 50 // Must be -100 to 0
}

// ✅ Valid health data
{
  cpu_usage: 85.2,
  memory_usage: 67.8, 
  disk_usage: 45.1,
  temperature_celsius: 42.5,
  uptime_seconds: 86400,
  network_latency_ms: 25,
  wifi_signal_strength: -45,
  brand_detection_accuracy: 0.94
}
```

#### 3. Realtime Subscription Fails
**Symptoms:** No real-time updates received

**Diagnosis:**
```sql
-- Check RLS policies
SELECT schemaname, tablename, policyname, cmd, qual 
FROM pg_policies 
WHERE tablename IN ('edge_devices', 'edge_health', 'alerts');

-- Verify user has store access
SELECT * FROM scout.user_store_access WHERE user_id = auth.uid();
```

**Solutions:**
- Enable Realtime on tables in Supabase dashboard
- Check RLS policies allow realtime access
- Verify user authentication status

#### 4. High Alert Volume
**Symptoms:** Too many alerts being generated

**Alert Deduplication:**
```sql
-- Check for duplicate alerts
SELECT alert_type, device_id, COUNT(*) 
FROM scout.alerts 
WHERE status = 'active' 
  AND created_at > NOW() - INTERVAL '1 hour'
GROUP BY alert_type, device_id 
HAVING COUNT(*) > 1;

-- Resolve duplicate alerts
UPDATE scout.alerts 
SET status = 'suppressed'
WHERE id IN (
  SELECT id FROM (
    SELECT id, ROW_NUMBER() OVER (
      PARTITION BY alert_type, device_id 
      ORDER BY created_at DESC
    ) as rn
    FROM scout.alerts 
    WHERE status = 'active'
  ) t WHERE rn > 1
);
```

### Device Debugging Utilities

**Health Check Script for Devices:**
```bash
#!/bin/bash
# device-health-check.sh

DEVICE_ID="dev_uuid_here"
BASE_URL="https://cxzllzyxwpyptfretryc.supabase.co/rest/v1"

echo "🔍 Device Health Check for $DEVICE_ID"
echo "=================================="

# 1. Check device registration
echo "1. Device Registration:"
curl -s -H "Accept-Profile: scout" \
  "$BASE_URL/edge_devices?device_id=eq.$DEVICE_ID&select=device_name,is_active,last_checkin"

# 2. Latest health metrics
echo -e "\n2. Latest Health Metrics:"
curl -s -H "Accept-Profile: scout" \
  "$BASE_URL/edge_health?device_id=eq.$DEVICE_ID&order=timestamp.desc&limit=1"

# 3. Active alerts
echo -e "\n3. Active Alerts:"
curl -s -H "Accept-Profile: scout" \
  "$BASE_URL/alerts?device_id=eq.$DEVICE_ID&status=eq.active"

# 4. Recent sync status
echo -e "\n4. Recent Sync Status:"
curl -s -H "Accept-Profile: scout" \
  "$BASE_URL/sync_logs?device_id=eq.$DEVICE_ID&order=sync_started.desc&limit=3"
```

**Device Performance Monitor:**
```javascript
class DevicePerformanceMonitor {
  constructor(deviceId) {
    this.deviceId = deviceId;
    this.metrics = {
      healthSubmissions: 0,
      syncFailures: 0,
      alertsGenerated: 0,
      avgResponseTime: 0
    };
  }

  async submitHealthData(healthData) {
    const startTime = Date.now();
    
    try {
      const response = await fetch(`${baseURL}/rpc/fn_update_device_health`, {
        method: 'POST',
        headers: {
          'apikey': ANON_KEY,
          'Authorization': `Bearer ${deviceToken}`,
          'Content-Profile': 'scout',
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          device_id: this.deviceId,
          health_data: healthData
        })
      });

      const responseTime = Date.now() - startTime;
      this.updateMetrics('health_success', responseTime);

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      return await response.json();
    } catch (error) {
      this.updateMetrics('health_failure');
      console.error('Health submission failed:', error);
      throw error;
    }
  }

  updateMetrics(eventType, responseTime = null) {
    switch (eventType) {
      case 'health_success':
        this.metrics.healthSubmissions++;
        if (responseTime) {
          this.metrics.avgResponseTime = 
            (this.metrics.avgResponseTime + responseTime) / 2;
        }
        break;
      case 'health_failure':
        this.metrics.syncFailures++;
        break;
      case 'alert_generated':
        this.metrics.alertsGenerated++;
        break;
    }
  }

  getPerformanceReport() {
    return {
      deviceId: this.deviceId,
      uptime: this.calculateUptime(),
      metrics: this.metrics,
      healthScore: this.calculateHealthScore()
    };
  }
}
```

---

## 🎯 Production-Ready IoT Examples

### Complete Device Lifecycle Management

```javascript
class EdgeDeviceManager {
  constructor(storeId, deviceConfig) {
    this.storeId = storeId;
    this.deviceConfig = deviceConfig;
    this.deviceId = null;
    this.healthReportInterval = null;
    this.syncInterval = null;
  }

  async registerDevice() {
    try {
      const deviceData = {
        device_name: `${this.storeId}-${this.deviceConfig.type}-${Date.now()}`,
        device_type: this.deviceConfig.type,
        store_id: this.storeId,
        mac_address: this.getMacAddress(),
        ip_address: this.getLocalIP(),
        firmware_version: this.deviceConfig.firmwareVersion,
        device_config: {
          heartbeat_interval: 30,
          sync_interval: 300,
          health_report_interval: 60,
          alert_thresholds: this.deviceConfig.alertThresholds
        }
      };

      const response = await supabase.rpc('fn_register_edge_device', deviceData);
      
      if (response.error) {
        throw new Error(`Registration failed: ${response.error.message}`);
      }

      this.deviceId = response.data;
      console.log(`✅ Device registered: ${this.deviceId}`);
      
      // Start health monitoring
      this.startHealthReporting();
      this.startDataSync();
      
      return this.deviceId;
    } catch (error) {
      console.error('❌ Device registration failed:', error);
      throw error;
    }
  }

  startHealthReporting() {
    this.healthReportInterval = setInterval(async () => {
      try {
        const healthData = await this.collectHealthMetrics();
        await this.submitHealthData(healthData);
      } catch (error) {
        console.error('Health reporting failed:', error);
        // Implement exponential backoff retry
        this.retryHealthSubmission(error);
      }
    }, this.deviceConfig.healthReportInterval * 1000);
  }

  async collectHealthMetrics() {
    // Collect actual system metrics
    const systemInfo = await this.getSystemInfo();
    const networkInfo = await this.getNetworkInfo();
    const appMetrics = await this.getApplicationMetrics();

    return {
      cpu_usage: systemInfo.cpuUsage,
      memory_usage: systemInfo.memoryUsage,
      disk_usage: systemInfo.diskUsage,
      temperature_celsius: systemInfo.temperature,
      uptime_seconds: systemInfo.uptime,
      network_latency_ms: networkInfo.latency,
      wifi_signal_strength: networkInfo.signalStrength,
      is_online: true,
      brand_detection_accuracy: appMetrics.detectionAccuracy,
      transactions_processed_today: appMetrics.transactionCount,
      queue_size: appMetrics.queueSize,
      status: this.determineHealthStatus(systemInfo, networkInfo)
    };
  }

  async submitHealthData(healthData) {
    const response = await supabase.rpc('fn_update_device_health', {
      device_id: this.deviceId,
      health_data: healthData
    });

    if (response.error) {
      throw new Error(`Health submission failed: ${response.error.message}`);
    }

    // Check if new alerts were created
    await this.checkForNewAlerts();
  }

  determineHealthStatus(systemInfo, networkInfo) {
    const { alertThresholds } = this.deviceConfig;
    
    if (systemInfo.cpuUsage >= alertThresholds.cpu_critical ||
        systemInfo.memoryUsage >= alertThresholds.memory_critical ||
        systemInfo.temperature >= alertThresholds.temperature_critical) {
      return 'critical';
    }
    
    if (systemInfo.cpuUsage >= alertThresholds.cpu_warning ||
        systemInfo.memoryUsage >= alertThresholds.memory_warning ||
        networkInfo.latency > 100) {
      return 'warning';
    }
    
    return 'healthy';
  }

  async handleAlert(alert) {
    console.log(`🚨 Alert received: ${alert.title}`);
    
    // Take automated remedial actions based on alert type
    switch (alert.alert_type) {
      case 'system_health':
        await this.handleSystemHealthAlert(alert);
        break;
      case 'sync_failure':
        await this.handleSyncFailureAlert(alert);
        break;
      case 'device_offline':
        await this.handleOfflineAlert(alert);
        break;
      default:
        console.log(`No automated action for alert type: ${alert.alert_type}`);
    }
  }

  async handleSystemHealthAlert(alert) {
    // Implement automated recovery actions
    if (alert.alert_data.cpu_usage > 90) {
      console.log('🔄 High CPU usage detected, restarting non-critical services...');
      await this.restartNonCriticalServices();
    }
    
    if (alert.alert_data.memory_usage > 90) {
      console.log('🧹 High memory usage detected, clearing caches...');
      await this.clearCaches();
    }
  }

  cleanup() {
    if (this.healthReportInterval) {
      clearInterval(this.healthReportInterval);
    }
    if (this.syncInterval) {
      clearInterval(this.syncInterval);
    }
  }
}
```

### Store Connectivity Dashboard

```javascript
class StoreConnectivityDashboard {
  constructor(storeId) {
    this.storeId = storeId;
    this.devices = new Map();
    this.alertsQueue = [];
    this.setupRealtimeMonitoring();
  }

  async initialize() {
    // Load initial device data
    const { data: devices } = await supabase
      .from('v_device_dashboard')
      .select('*')
      .eq('store_id', this.storeId);

    devices.forEach(device => {
      this.devices.set(device.device_id, device);
      this.renderDeviceCard(device);
    });

    // Load store connectivity overview
    await this.loadStoreOverview();
  }

  setupRealtimeMonitoring() {
    // Monitor all store devices
    const storeDevicesChannel = supabase
      .channel(`store_${this.storeId}_monitoring`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'scout',
          table: 'edge_health',
          filter: `device_id=in.(${Array.from(this.devices.keys()).join(',')})`
        },
        this.handleHealthUpdate.bind(this)
      )
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'scout',
          table: 'alerts',
          filter: `store_id=eq.${this.storeId}`
        },
        this.handleNewAlert.bind(this)
      )
      .subscribe();
  }

  handleHealthUpdate(payload) {
    const healthData = payload.new;
    const device = this.devices.get(healthData.device_id);
    
    if (device) {
      // Update device metrics
      Object.assign(device, {
        cpu_usage: healthData.cpu_usage,
        memory_usage: healthData.memory_usage,
        status: healthData.status,
        last_health_update: healthData.timestamp
      });

      // Update UI
      this.updateDeviceCard(healthData.device_id, healthData);
      
      // Update store-level metrics
      this.updateStoreMetrics();
    }
  }

  handleNewAlert(payload) {
    const alert = payload.new;
    this.alertsQueue.push(alert);
    
    // Show notification
    this.showAlertNotification(alert);
    
    // Update alert counter
    this.updateAlertCounter();
    
    // Auto-acknowledge low priority alerts
    if (alert.priority <= 3) {
      setTimeout(() => {
        this.autoAcknowledgeAlert(alert.id);
      }, 30000); // Auto-ack after 30 seconds
    }
  }

  async loadStoreOverview() {
    const { data: overview } = await supabase
      .from('v_store_connectivity')
      .select('*')
      .eq('store_id', this.storeId)
      .single();

    this.renderStoreOverview(overview);
  }

  renderStoreOverview(overview) {
    const overviewContainer = document.getElementById('store-overview');
    overviewContainer.innerHTML = `
      <div class="overview-grid">
        <div class="metric-card">
          <h3>Total Devices</h3>
          <span class="metric-value">${overview.total_devices}</span>
        </div>
        <div class="metric-card">
          <h3>Online Devices</h3>
          <span class="metric-value ${overview.online_devices === overview.total_devices ? 'healthy' : 'warning'}">
            ${overview.online_devices}/${overview.total_devices}
          </span>
        </div>
        <div class="metric-card">
          <h3>Active Alerts</h3>
          <span class="metric-value ${overview.active_alerts === 0 ? 'healthy' : 'warning'}">
            ${overview.active_alerts}
          </span>
        </div>
        <div class="metric-card">
          <h3>Avg CPU Usage</h3>
          <span class="metric-value ${overview.avg_cpu_usage < 70 ? 'healthy' : 'warning'}">
            ${overview.avg_cpu_usage?.toFixed(1) || 0}%
          </span>
        </div>
      </div>
    `;
  }
}
```

---

## 📋 Quick Reference for IoT Operations

### Essential Headers for Edge Devices
```bash
# Device operations
apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Authorization: Bearer <service_role_token>
Content-Profile: scout
Content-Type: application/json

# Dashboard operations  
Accept-Profile: scout
Authorization: Bearer <user_jwt_token>

# Health data submission
Content-Profile: scout
Prefer: return=minimal  # For bulk operations
```

### Common URL Patterns for IoT
```bash
# Device management
GET  /edge_devices?store_id=eq.store_123
POST /edge_devices
POST /rpc/fn_register_edge_device

# Health monitoring  
GET  /edge_health?device_id=eq.dev_uuid&order=timestamp.desc&limit=100
POST /edge_health
POST /rpc/fn_update_device_health

# Alerts
GET  /alerts?status=eq.active&store_id=eq.store_123
PATCH /alerts?id=eq.alert_uuid
POST /rpc/fn_alert_acknowledge

# Dashboards
GET /v_device_dashboard?store_id=eq.store_123
GET /v_store_connectivity?store_id=eq.store_123
```

### IoT-Specific Filter Examples
```bash
# Device health filters
?cpu_usage=gte.80&memory_usage=gte.75&status=neq.healthy
?device_type=eq.raspberry_pi_5&is_online=eq.true
?last_checkin=gte.2025-08-24T00:00:00Z

# Alert filters
?severity=in.(warning,critical)&status=eq.active
?alert_type=eq.device_offline&created_at=gte.2025-08-24T00:00:00Z

# Sync operation filters  
?success=eq.false&retry_count=gte.3
?sync_type=eq.full_sync&duration_ms=gte.30000
```

---

**🎉 You're now ready to build production-grade IoT monitoring systems with Scout Connectivity Layer!**

For additional IoT support:
- 🔗 **Edge Functions**: Deploy custom device logic
- 📊 **Real-time Dashboard**: Monitor all store devices live
- 🚨 **Alert Management**: Proactive device maintenance
- 📡 **Sync Monitoring**: Ensure reliable data flow