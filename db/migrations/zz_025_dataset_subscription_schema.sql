-- Dataset Subscription and Notification Schema
-- Enables users to subscribe to dataset updates and receive notifications via email, webhook, or in-app

-- Create notifications schema
CREATE SCHEMA IF NOT EXISTS notifications;

-- Notification channel enum
CREATE TYPE notifications.notification_channel AS ENUM (
  'email',
  'webhook',
  'in_app',
  'sms',
  'slack'
);

-- Subscription type enum
CREATE TYPE notifications.subscription_type AS ENUM (
  'dataset_updated',        -- Dataset file changed
  'new_version',           -- New version published
  'replication_completed', -- Cross-region replication finished
  'quality_check_failed',  -- Data quality issues detected
  'usage_threshold',       -- Usage exceeded threshold
  'expiry_warning',        -- Dataset approaching expiry
  'access_granted',        -- New access permissions
  'schema_changed'         -- Dataset schema modified
);

-- Notification status enum
CREATE TYPE notifications.notification_status AS ENUM (
  'pending',
  'sent',
  'delivered',
  'failed',
  'read',
  'dismissed'
);

-- User preferences for notifications
CREATE TABLE notifications.user_notification_preferences (
  user_id TEXT PRIMARY KEY,
  email_notifications BOOLEAN DEFAULT true,
  webhook_notifications BOOLEAN DEFAULT false,
  in_app_notifications BOOLEAN DEFAULT true,
  sms_notifications BOOLEAN DEFAULT false,
  slack_notifications BOOLEAN DEFAULT false,
  email_address TEXT,
  webhook_url TEXT,
  phone_number TEXT,
  slack_webhook_url TEXT,
  timezone TEXT DEFAULT 'UTC',
  quiet_hours_start TIME DEFAULT '22:00',
  quiet_hours_end TIME DEFAULT '08:00',
  max_notifications_per_day INTEGER DEFAULT 50,
  notification_frequency TEXT DEFAULT 'immediate', -- immediate, hourly, daily, weekly
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Dataset subscriptions
CREATE TABLE notifications.dataset_subscriptions (
  subscription_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  dataset_pattern TEXT NOT NULL, -- Regex pattern for dataset names
  subscription_types notifications.subscription_type[] NOT NULL,
  channels notifications.notification_channel[] NOT NULL,
  is_active BOOLEAN DEFAULT true,
  
  -- Filters
  filters JSONB DEFAULT '{}', -- JSON filters like file_size, region, etc.
  
  -- Thresholds
  usage_threshold INTEGER, -- Notify when usage exceeds this
  file_size_threshold_mb INTEGER, -- Notify when file size exceeds this
  
  -- Scheduling
  notification_schedule TEXT DEFAULT 'immediate', -- cron expression or 'immediate'
  last_notification_sent TIMESTAMP WITH TIME ZONE,
  next_notification_due TIMESTAMP WITH TIME ZONE,
  
  -- Metadata
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  FOREIGN KEY (user_id) REFERENCES notifications.user_notification_preferences(user_id)
);

-- Notification queue
CREATE TABLE notifications.notification_queue (
  notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id UUID REFERENCES notifications.dataset_subscriptions(subscription_id),
  user_id TEXT NOT NULL,
  notification_type notifications.subscription_type NOT NULL,
  channel notifications.notification_channel NOT NULL,
  
  -- Message details
  subject TEXT NOT NULL,
  message_body TEXT NOT NULL,
  message_html TEXT,
  
  -- Dataset context
  dataset_name TEXT,
  dataset_metadata JSONB DEFAULT '{}',
  
  -- Delivery details
  recipient_address TEXT, -- email, phone, webhook URL
  status notifications.notification_status DEFAULT 'pending',
  scheduled_for TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  sent_at TIMESTAMP WITH TIME ZONE,
  delivered_at TIMESTAMP WITH TIME ZONE,
  read_at TIMESTAMP WITH TIME ZONE,
  
  -- Error handling
  retry_count INTEGER DEFAULT 0,
  max_retries INTEGER DEFAULT 3,
  error_message TEXT,
  
  -- Tracking
  tracking_id TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Notification templates
CREATE TABLE notifications.notification_templates (
  template_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_name TEXT UNIQUE NOT NULL,
  notification_type notifications.subscription_type NOT NULL,
  channel notifications.notification_channel NOT NULL,
  
  -- Template content
  subject_template TEXT NOT NULL,
  body_template TEXT NOT NULL,
  html_template TEXT,
  
  -- Template variables info
  available_variables TEXT[], -- List of variables that can be used
  
  -- Metadata
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  created_by TEXT DEFAULT 'system',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Notification delivery log
CREATE TABLE notifications.delivery_log (
  log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_id UUID REFERENCES notifications.notification_queue(notification_id),
  delivery_attempt INTEGER NOT NULL,
  channel notifications.notification_channel NOT NULL,
  recipient_address TEXT NOT NULL,
  status TEXT NOT NULL, -- success, failed, bounced, etc.
  response_code INTEGER,
  response_message TEXT,
  delivery_time_ms INTEGER,
  attempted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Subscription analytics
CREATE TABLE notifications.subscription_analytics (
  analytics_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id UUID REFERENCES notifications.dataset_subscriptions(subscription_id),
  user_id TEXT NOT NULL,
  metric_date DATE DEFAULT CURRENT_DATE,
  
  -- Metrics
  notifications_sent INTEGER DEFAULT 0,
  notifications_delivered INTEGER DEFAULT 0,
  notifications_read INTEGER DEFAULT 0,
  notifications_clicked INTEGER DEFAULT 0,
  notifications_dismissed INTEGER DEFAULT 0,
  
  -- Engagement
  average_read_time_seconds INTEGER DEFAULT 0,
  click_through_rate DECIMAL(5,2) DEFAULT 0,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  UNIQUE(subscription_id, metric_date)
);

-- Indexes for performance
CREATE INDEX idx_subscriptions_user ON notifications.dataset_subscriptions(user_id);
CREATE INDEX idx_subscriptions_pattern ON notifications.dataset_subscriptions(dataset_pattern);
CREATE INDEX idx_subscriptions_active ON notifications.dataset_subscriptions(is_active);
CREATE INDEX idx_subscriptions_next_due ON notifications.dataset_subscriptions(next_notification_due);

CREATE INDEX idx_queue_status ON notifications.notification_queue(status);
CREATE INDEX idx_queue_scheduled ON notifications.notification_queue(scheduled_for);
CREATE INDEX idx_queue_user ON notifications.notification_queue(user_id);
CREATE INDEX idx_queue_dataset ON notifications.notification_queue(dataset_name);
CREATE INDEX idx_queue_channel ON notifications.notification_queue(channel);

CREATE INDEX idx_delivery_log_notification ON notifications.delivery_log(notification_id);
CREATE INDEX idx_delivery_log_attempted ON notifications.delivery_log(attempted_at);

CREATE INDEX idx_analytics_date ON notifications.subscription_analytics(metric_date);
CREATE INDEX idx_analytics_user ON notifications.subscription_analytics(user_id);

-- Views for monitoring and analytics

-- Subscription overview
CREATE OR REPLACE VIEW notifications.subscription_overview AS
SELECT 
  u.user_id,
  u.email_address,
  COUNT(s.subscription_id) as total_subscriptions,
  COUNT(s.subscription_id) FILTER (WHERE s.is_active = true) as active_subscriptions,
  array_agg(DISTINCT unnest(s.subscription_types)) as subscribed_event_types,
  array_agg(DISTINCT unnest(s.channels)) as notification_channels,
  MAX(s.last_notification_sent) as last_notification_sent,
  MIN(s.next_notification_due) as next_notification_due
FROM notifications.user_notification_preferences u
LEFT JOIN notifications.dataset_subscriptions s ON u.user_id = s.user_id
GROUP BY u.user_id, u.email_address
ORDER BY total_subscriptions DESC;

-- Notification queue summary
CREATE OR REPLACE VIEW notifications.queue_summary AS
SELECT 
  channel,
  status,
  COUNT(*) as notification_count,
  MIN(scheduled_for) as oldest_scheduled,
  MAX(scheduled_for) as newest_scheduled,
  AVG(retry_count) as avg_retry_count,
  COUNT(*) FILTER (WHERE retry_count >= max_retries) as max_retries_reached
FROM notifications.notification_queue
GROUP BY channel, status
ORDER BY channel, 
  CASE status
    WHEN 'pending' THEN 1
    WHEN 'sent' THEN 2
    WHEN 'delivered' THEN 3
    WHEN 'read' THEN 4
    WHEN 'failed' THEN 5
    WHEN 'dismissed' THEN 6
  END;

-- Delivery performance
CREATE OR REPLACE VIEW notifications.delivery_performance AS
SELECT 
  channel,
  DATE(attempted_at) as delivery_date,
  COUNT(*) as total_attempts,
  COUNT(*) FILTER (WHERE status = 'success') as successful_deliveries,
  COUNT(*) FILTER (WHERE status = 'failed') as failed_deliveries,
  (COUNT(*) FILTER (WHERE status = 'success') * 100.0 / COUNT(*)) as success_rate,
  AVG(delivery_time_ms) as avg_delivery_time_ms,
  AVG(response_code) FILTER (WHERE response_code IS NOT NULL) as avg_response_code
FROM notifications.delivery_log
GROUP BY channel, DATE(attempted_at)
ORDER BY delivery_date DESC, channel;

-- Functions

-- Check if user matches dataset pattern
CREATE OR REPLACE FUNCTION notifications.matches_dataset_pattern(
  p_dataset_name TEXT,
  p_pattern TEXT
) RETURNS BOOLEAN AS $$
BEGIN
  RETURN p_dataset_name ~ p_pattern;
END;
$$ LANGUAGE plpgsql;

-- Create notification for dataset event
CREATE OR REPLACE FUNCTION notifications.create_dataset_notification(
  p_dataset_name TEXT,
  p_event_type notifications.subscription_type,
  p_event_metadata JSONB DEFAULT '{}'
) RETURNS INTEGER AS $$
DECLARE
  subscription RECORD;
  template RECORD;
  notification_count INTEGER := 0;
  subject_text TEXT;
  body_text TEXT;
BEGIN
  -- Find matching subscriptions
  FOR subscription IN
    SELECT DISTINCT 
      s.subscription_id,
      s.user_id,
      s.channels,
      u.email_address,
      u.webhook_url,
      u.phone_number,
      u.slack_webhook_url,
      u.notification_frequency
    FROM notifications.dataset_subscriptions s
    JOIN notifications.user_notification_preferences u ON s.user_id = u.user_id
    WHERE s.is_active = true
      AND p_event_type = ANY(s.subscription_types)
      AND notifications.matches_dataset_pattern(p_dataset_name, s.dataset_pattern)
      -- Check if within rate limits
      AND (
        s.last_notification_sent IS NULL OR
        s.last_notification_sent < NOW() - INTERVAL '1 hour' OR
        u.notification_frequency = 'immediate'
      )
  LOOP
    -- Process each notification channel for this subscription
    FOR i IN 1..array_length(subscription.channels, 1) LOOP
      DECLARE
        channel notifications.notification_channel := subscription.channels[i];
        recipient_address TEXT;
      BEGIN
        -- Determine recipient address based on channel
        CASE channel
          WHEN 'email' THEN recipient_address := subscription.email_address;
          WHEN 'webhook' THEN recipient_address := subscription.webhook_url;
          WHEN 'sms' THEN recipient_address := subscription.phone_number;
          WHEN 'slack' THEN recipient_address := subscription.slack_webhook_url;
          WHEN 'in_app' THEN recipient_address := subscription.user_id;
          ELSE recipient_address := NULL;
        END CASE;

        -- Skip if no recipient address
        CONTINUE WHEN recipient_address IS NULL;

        -- Get notification template
        SELECT * INTO template
        FROM notifications.notification_templates
        WHERE notification_type = p_event_type
          AND channel = channel
          AND is_active = true
        LIMIT 1;

        -- Use default template if none found
        IF template IS NULL THEN
          subject_text := format('Dataset %s - %s', p_dataset_name, p_event_type);
          body_text := format('Dataset %s has been %s at %s', 
            p_dataset_name, p_event_type, NOW());
        ELSE
          -- Replace template variables
          subject_text := replace(template.subject_template, '{{dataset_name}}', p_dataset_name);
          subject_text := replace(subject_text, '{{event_type}}', p_event_type::TEXT);
          subject_text := replace(subject_text, '{{timestamp}}', NOW()::TEXT);
          
          body_text := replace(template.body_template, '{{dataset_name}}', p_dataset_name);
          body_text := replace(body_text, '{{event_type}}', p_event_type::TEXT);
          body_text := replace(body_text, '{{timestamp}}', NOW()::TEXT);
        END IF;

        -- Create notification in queue
        INSERT INTO notifications.notification_queue (
          subscription_id,
          user_id,
          notification_type,
          channel,
          subject,
          message_body,
          dataset_name,
          dataset_metadata,
          recipient_address,
          tracking_id
        ) VALUES (
          subscription.subscription_id,
          subscription.user_id,
          p_event_type,
          channel,
          subject_text,
          body_text,
          p_dataset_name,
          p_event_metadata,
          recipient_address,
          encode(gen_random_bytes(8), 'hex')
        );

        notification_count := notification_count + 1;
      END;
    END LOOP;

    -- Update last notification sent time
    UPDATE notifications.dataset_subscriptions
    SET last_notification_sent = NOW()
    WHERE subscription_id = subscription.subscription_id;
  END LOOP;

  RETURN notification_count;
END;
$$ LANGUAGE plpgsql;

-- Process notification queue
CREATE OR REPLACE FUNCTION notifications.process_notification_queue(
  p_limit INTEGER DEFAULT 100
) RETURNS TABLE (
  processed_count INTEGER,
  success_count INTEGER,
  failed_count INTEGER
) AS $$
DECLARE
  notification RECORD;
  total_processed INTEGER := 0;
  total_success INTEGER := 0;
  total_failed INTEGER := 0;
  delivery_success BOOLEAN;
BEGIN
  -- Process pending notifications
  FOR notification IN
    SELECT *
    FROM notifications.notification_queue
    WHERE status = 'pending'
      AND scheduled_for <= NOW()
      AND retry_count < max_retries
    ORDER BY scheduled_for ASC
    LIMIT p_limit
  LOOP
    total_processed := total_processed + 1;
    delivery_success := false;

    BEGIN
      -- Simulate delivery based on channel
      CASE notification.channel
        WHEN 'email' THEN
          -- Email delivery simulation
          delivery_success := (random() > 0.05); -- 95% success rate
        WHEN 'webhook' THEN
          -- Webhook delivery simulation  
          delivery_success := (random() > 0.1); -- 90% success rate
        WHEN 'in_app' THEN
          -- In-app notifications always succeed
          delivery_success := true;
        WHEN 'sms' THEN
          -- SMS delivery simulation
          delivery_success := (random() > 0.02); -- 98% success rate
        WHEN 'slack' THEN
          -- Slack delivery simulation
          delivery_success := (random() > 0.03); -- 97% success rate
        ELSE
          delivery_success := false;
      END CASE;

      -- Update notification status
      IF delivery_success THEN
        UPDATE notifications.notification_queue
        SET 
          status = 'sent',
          sent_at = NOW()
        WHERE notification_id = notification.notification_id;
        
        total_success := total_success + 1;
      ELSE
        UPDATE notifications.notification_queue
        SET 
          status = 'failed',
          retry_count = retry_count + 1,
          error_message = 'Simulated delivery failure',
          scheduled_for = NOW() + INTERVAL '5 minutes' * retry_count
        WHERE notification_id = notification.notification_id;
        
        total_failed := total_failed + 1;
      END IF;

      -- Log delivery attempt
      INSERT INTO notifications.delivery_log (
        notification_id,
        delivery_attempt,
        channel,
        recipient_address,
        status,
        response_code,
        response_message,
        delivery_time_ms
      ) VALUES (
        notification.notification_id,
        notification.retry_count + 1,
        notification.channel,
        notification.recipient_address,
        CASE WHEN delivery_success THEN 'success' ELSE 'failed' END,
        CASE WHEN delivery_success THEN 200 ELSE 500 END,
        CASE WHEN delivery_success THEN 'Delivered successfully' ELSE 'Delivery failed' END,
        (random() * 1000 + 100)::INTEGER -- Random delivery time 100-1100ms
      );

    EXCEPTION WHEN OTHERS THEN
      UPDATE notifications.notification_queue
      SET 
        status = 'failed',
        retry_count = retry_count + 1,
        error_message = SQLERRM,
        scheduled_for = NOW() + INTERVAL '5 minutes' * retry_count
      WHERE notification_id = notification.notification_id;
      
      total_failed := total_failed + 1;
    END;
  END LOOP;

  RETURN QUERY SELECT total_processed, total_success, total_failed;
END;
$$ LANGUAGE plpgsql;

-- Get user notification summary
CREATE OR REPLACE FUNCTION notifications.get_user_notification_summary(
  p_user_id TEXT,
  p_days INTEGER DEFAULT 7
) RETURNS TABLE (
  total_subscriptions INTEGER,
  active_subscriptions INTEGER,
  notifications_sent INTEGER,
  notifications_read INTEGER,
  read_rate DECIMAL(5,2),
  most_active_dataset TEXT,
  preferred_channel notifications.notification_channel
) AS $$
BEGIN
  RETURN QUERY
  WITH user_stats AS (
    SELECT 
      COUNT(DISTINCT s.subscription_id) as total_subs,
      COUNT(DISTINCT s.subscription_id) FILTER (WHERE s.is_active = true) as active_subs,
      COUNT(n.notification_id) as sent_count,
      COUNT(n.notification_id) FILTER (WHERE n.read_at IS NOT NULL) as read_count,
      MODE() WITHIN GROUP (ORDER BY s.dataset_pattern) as top_dataset_pattern,
      MODE() WITHIN GROUP (ORDER BY n.channel) as preferred_chan
    FROM notifications.dataset_subscriptions s
    LEFT JOIN notifications.notification_queue n ON s.subscription_id = n.subscription_id
      AND n.created_at > NOW() - INTERVAL '1 day' * p_days
    WHERE s.user_id = p_user_id
  )
  SELECT 
    COALESCE(us.total_subs, 0)::INTEGER,
    COALESCE(us.active_subs, 0)::INTEGER,
    COALESCE(us.sent_count, 0)::INTEGER,
    COALESCE(us.read_count, 0)::INTEGER,
    CASE 
      WHEN us.sent_count > 0 THEN (us.read_count * 100.0 / us.sent_count)::DECIMAL(5,2)
      ELSE 0::DECIMAL(5,2)
    END,
    us.top_dataset_pattern,
    us.preferred_chan
  FROM user_stats us;
END;
$$ LANGUAGE plpgsql;

-- Insert default notification templates
INSERT INTO notifications.notification_templates (template_name, notification_type, channel, subject_template, body_template, available_variables) VALUES

-- Email templates
('dataset_updated_email', 'dataset_updated', 'email', 
 'Dataset Updated: {{dataset_name}}',
 'Hello,

The dataset "{{dataset_name}}" has been updated at {{timestamp}}.

You can access the latest version through the Scout Analytics platform.

Best regards,
Scout Analytics Team',
 ARRAY['dataset_name', 'timestamp', 'file_size', 'version']),

('new_version_email', 'new_version', 'email',
 'New Version Available: {{dataset_name}}',
 'Hello,

A new version of dataset "{{dataset_name}}" is now available ({{version}}).

Changes in this version:
{{change_description}}

Access the new version through the Scout Analytics platform.

Best regards,
Scout Analytics Team',
 ARRAY['dataset_name', 'version', 'change_description', 'timestamp']),

-- Webhook templates  
('dataset_updated_webhook', 'dataset_updated', 'webhook',
 'Dataset Updated',
 '{"event": "dataset_updated", "dataset": "{{dataset_name}}", "timestamp": "{{timestamp}}", "metadata": {}}',
 ARRAY['dataset_name', 'timestamp', 'file_size']),

-- In-app templates
('dataset_updated_in_app', 'dataset_updated', 'in_app',
 'Dataset Updated',
 'Dataset {{dataset_name}} has been updated',
 ARRAY['dataset_name', 'timestamp']),

-- Slack templates
('dataset_updated_slack', 'dataset_updated', 'slack',
 'Dataset Updated',
 '{"text": "📊 Dataset *{{dataset_name}}* has been updated at {{timestamp}}", "channel": "#data-updates"}',
 ARRAY['dataset_name', 'timestamp'])

ON CONFLICT (template_name) DO NOTHING;

-- Insert sample user preferences
INSERT INTO notifications.user_notification_preferences (user_id, email_address, email_notifications, in_app_notifications) VALUES
('admin', 'admin@tbwa.com', true, true),
('scout_user', 'scout@tbwa.com', true, true),
('analyst', 'analyst@tbwa.com', false, true)
ON CONFLICT (user_id) DO NOTHING;

-- Insert sample subscriptions
INSERT INTO notifications.dataset_subscriptions (user_id, dataset_pattern, subscription_types, channels, description) VALUES
('admin', '.*_gold', ARRAY['dataset_updated', 'new_version']::notifications.subscription_type[], ARRAY['email', 'in_app']::notifications.notification_channel[], 'Admin monitoring all gold datasets'),
('scout_user', 'daily_.*', ARRAY['dataset_updated']::notifications.subscription_type[], ARRAY['in_app']::notifications.notification_channel[], 'Daily datasets updates'),
('analyst', 'store_.*', ARRAY['dataset_updated', 'quality_check_failed']::notifications.subscription_type[], ARRAY['email']::notifications.notification_channel[], 'Store data analysis updates')
ON CONFLICT DO NOTHING;

-- Grant permissions
GRANT USAGE ON SCHEMA notifications TO authenticated, anon, service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA notifications TO authenticated, anon;
GRANT ALL ON ALL TABLES IN SCHEMA notifications TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA notifications TO authenticated, anon, service_role;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA notifications TO service_role;

-- Row Level Security
ALTER TABLE notifications.user_notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications.dataset_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications.notification_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications.notification_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications.delivery_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications.subscription_analytics ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can manage their own preferences" ON notifications.user_notification_preferences
  FOR ALL USING (auth.jwt() ->> 'sub' = user_id OR auth.role() = 'service_role');

CREATE POLICY "Users can manage their own subscriptions" ON notifications.dataset_subscriptions
  FOR ALL USING (auth.jwt() ->> 'sub' = user_id OR auth.role() = 'service_role');

CREATE POLICY "Users can view their own notifications" ON notifications.notification_queue
  FOR SELECT USING (auth.jwt() ->> 'sub' = user_id OR auth.role() = 'service_role');

CREATE POLICY "Service role can manage notifications" ON notifications.notification_queue
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Users can view templates" ON notifications.notification_templates
  FOR SELECT USING (true);

CREATE POLICY "Service role can manage templates" ON notifications.notification_templates
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Users can view delivery logs for their notifications" ON notifications.delivery_log
  FOR SELECT USING (
    notification_id IN (
      SELECT notification_id FROM notifications.notification_queue 
      WHERE user_id = auth.jwt() ->> 'sub'
    ) OR auth.role() = 'service_role'
  );

CREATE POLICY "Service role can manage delivery logs" ON notifications.delivery_log
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Users can view their own analytics" ON notifications.subscription_analytics
  FOR SELECT USING (auth.jwt() ->> 'sub' = user_id OR auth.role() = 'service_role');

CREATE POLICY "Service role can manage analytics" ON notifications.subscription_analytics
  FOR ALL USING (auth.role() = 'service_role');