import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

/**
 * Dataset Subscription and Notification System
 * 
 * Manages user subscriptions to dataset updates and sends notifications
 * via multiple channels (email, webhook, in-app, SMS, Slack) when
 * datasets are updated, versioned, or meet specific criteria.
 */

interface SubscriptionRequest {
  dataset_pattern: string;
  subscription_types: string[];
  channels: string[];
  description?: string;
  filters?: Record<string, any>;
  usage_threshold?: number;
  file_size_threshold_mb?: number;
  notification_schedule?: string;
}

interface NotificationEvent {
  dataset_name: string;
  event_type: string;
  metadata?: Record<string, any>;
}

interface UserSubscription {
  subscription_id: string;
  dataset_pattern: string;
  subscription_types: string[];
  channels: string[];
  is_active: boolean;
  filters: Record<string, any>;
  description?: string;
  created_at: string;
  last_notification_sent?: string;
}

interface NotificationSummary {
  user_id: string;
  total_subscriptions: number;
  active_subscriptions: number;
  notifications_sent: number;
  notifications_read: number;
  read_rate: number;
  most_active_dataset: string;
  preferred_channel: string;
}

interface NotificationStats {
  queue_summary: {
    pending_notifications: number;
    failed_notifications: number;
    total_sent_today: number;
    success_rate: number;
  };
  delivery_performance: Array<{
    channel: string;
    success_rate: number;
    avg_delivery_time_ms: number;
  }>;
  top_subscribed_datasets: Array<{
    dataset_pattern: string;
    subscription_count: number;
  }>;
  user_engagement: {
    total_active_users: number;
    avg_subscriptions_per_user: number;
    most_popular_channels: string[];
  };
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
};

// Initialize Supabase client
const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
);

/**
 * Create a new dataset subscription
 */
async function createSubscription(userId: string, request: SubscriptionRequest): Promise<UserSubscription> {
  // Validate subscription types and channels
  const validSubscriptionTypes = [
    'dataset_updated', 'new_version', 'replication_completed',
    'quality_check_failed', 'usage_threshold', 'expiry_warning',
    'access_granted', 'schema_changed'
  ];
  
  const validChannels = ['email', 'webhook', 'in_app', 'sms', 'slack'];

  const invalidTypes = request.subscription_types.filter(type => !validSubscriptionTypes.includes(type));
  const invalidChannels = request.channels.filter(channel => !validChannels.includes(channel));

  if (invalidTypes.length > 0) {
    throw new Error(`Invalid subscription types: ${invalidTypes.join(', ')}`);
  }
  
  if (invalidChannels.length > 0) {
    throw new Error(`Invalid channels: ${invalidChannels.join(', ')}`);
  }

  // Ensure user has notification preferences
  const { error: prefsError } = await supabase
    .from('user_notification_preferences')
    .upsert({
      user_id: userId,
      email_notifications: request.channels.includes('email'),
      webhook_notifications: request.channels.includes('webhook'),
      in_app_notifications: request.channels.includes('in_app'),
      sms_notifications: request.channels.includes('sms'),
      slack_notifications: request.channels.includes('slack'),
      updated_at: new Date().toISOString()
    }, {
      onConflict: 'user_id'
    });

  if (prefsError) {
    console.warn('Failed to update user preferences:', prefsError);
  }

  // Create subscription
  const subscriptionData = {
    user_id: userId,
    dataset_pattern: request.dataset_pattern,
    subscription_types: request.subscription_types,
    channels: request.channels,
    filters: request.filters || {},
    usage_threshold: request.usage_threshold,
    file_size_threshold_mb: request.file_size_threshold_mb,
    notification_schedule: request.notification_schedule || 'immediate',
    description: request.description
  };

  const { data, error } = await supabase
    .from('dataset_subscriptions')
    .insert(subscriptionData)
    .select()
    .single();

  if (error) {
    throw new Error(`Failed to create subscription: ${error.message}`);
  }

  return {
    subscription_id: data.subscription_id,
    dataset_pattern: data.dataset_pattern,
    subscription_types: data.subscription_types,
    channels: data.channels,
    is_active: data.is_active,
    filters: data.filters,
    description: data.description,
    created_at: data.created_at,
    last_notification_sent: data.last_notification_sent
  };
}

/**
 * Get user's subscriptions
 */
async function getUserSubscriptions(userId: string): Promise<UserSubscription[]> {
  const { data, error } = await supabase
    .from('dataset_subscriptions')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false });

  if (error) {
    throw new Error(`Failed to fetch subscriptions: ${error.message}`);
  }

  return (data || []).map(sub => ({
    subscription_id: sub.subscription_id,
    dataset_pattern: sub.dataset_pattern,
    subscription_types: sub.subscription_types,
    channels: sub.channels,
    is_active: sub.is_active,
    filters: sub.filters,
    description: sub.description,
    created_at: sub.created_at,
    last_notification_sent: sub.last_notification_sent
  }));
}

/**
 * Update subscription
 */
async function updateSubscription(
  userId: string, 
  subscriptionId: string, 
  updates: Partial<SubscriptionRequest>
): Promise<UserSubscription> {
  const { data, error } = await supabase
    .from('dataset_subscriptions')
    .update({
      ...updates,
      updated_at: new Date().toISOString()
    })
    .eq('subscription_id', subscriptionId)
    .eq('user_id', userId)
    .select()
    .single();

  if (error) {
    throw new Error(`Failed to update subscription: ${error.message}`);
  }

  if (!data) {
    throw new Error('Subscription not found or access denied');
  }

  return {
    subscription_id: data.subscription_id,
    dataset_pattern: data.dataset_pattern,
    subscription_types: data.subscription_types,
    channels: data.channels,
    is_active: data.is_active,
    filters: data.filters,
    description: data.description,
    created_at: data.created_at,
    last_notification_sent: data.last_notification_sent
  };
}

/**
 * Delete subscription
 */
async function deleteSubscription(userId: string, subscriptionId: string): Promise<void> {
  const { error } = await supabase
    .from('dataset_subscriptions')
    .delete()
    .eq('subscription_id', subscriptionId)
    .eq('user_id', userId);

  if (error) {
    throw new Error(`Failed to delete subscription: ${error.message}`);
  }
}

/**
 * Trigger notifications for a dataset event
 */
async function triggerNotifications(event: NotificationEvent): Promise<{ notifications_created: number }> {
  const { data, error } = await supabase
    .rpc('create_dataset_notification', {
      p_dataset_name: event.dataset_name,
      p_event_type: event.event_type,
      p_event_metadata: event.metadata || {}
    });

  if (error) {
    throw new Error(`Failed to create notifications: ${error.message}`);
  }

  return { notifications_created: data || 0 };
}

/**
 * Process notification queue
 */
async function processNotificationQueue(limit: number = 100): Promise<{
  processed_count: number;
  success_count: number;
  failed_count: number;
}> {
  const { data, error } = await supabase
    .rpc('process_notification_queue', { p_limit: limit });

  if (error) {
    throw new Error(`Failed to process notification queue: ${error.message}`);
  }

  const result = data?.[0] || { processed_count: 0, success_count: 0, failed_count: 0 };
  
  return {
    processed_count: result.processed_count,
    success_count: result.success_count,
    failed_count: result.failed_count
  };
}

/**
 * Get user notification summary
 */
async function getUserNotificationSummary(userId: string, days: number = 7): Promise<NotificationSummary> {
  const { data, error } = await supabase
    .rpc('get_user_notification_summary', {
      p_user_id: userId,
      p_days: days
    });

  if (error) {
    throw new Error(`Failed to get user summary: ${error.message}`);
  }

  const summary = data?.[0] || {};
  
  return {
    user_id: userId,
    total_subscriptions: summary.total_subscriptions || 0,
    active_subscriptions: summary.active_subscriptions || 0,
    notifications_sent: summary.notifications_sent || 0,
    notifications_read: summary.notifications_read || 0,
    read_rate: summary.read_rate || 0,
    most_active_dataset: summary.most_active_dataset || 'N/A',
    preferred_channel: summary.preferred_channel || 'email'
  };
}

/**
 * Get notification statistics
 */
async function getNotificationStats(): Promise<NotificationStats> {
  // Get queue summary
  const { data: queueData } = await supabase
    .from('queue_summary')
    .select('*');

  // Get delivery performance
  const { data: deliveryData } = await supabase
    .from('delivery_performance')
    .select('*')
    .gte('delivery_date', new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0]);

  // Get subscription overview
  const { data: subscriptionData } = await supabase
    .from('subscription_overview')
    .select('*')
    .order('total_subscriptions', { ascending: false })
    .limit(10);

  // Calculate queue summary
  const pending = queueData?.find(q => q.status === 'pending')?.notification_count || 0;
  const failed = queueData?.find(q => q.status === 'failed')?.notification_count || 0;
  const sent = queueData?.find(q => q.status === 'sent')?.notification_count || 0;
  const delivered = queueData?.find(q => q.status === 'delivered')?.notification_count || 0;
  
  const totalSent = sent + delivered;
  const successRate = totalSent > 0 ? (delivered / totalSent) * 100 : 100;

  // Calculate delivery performance by channel
  const deliveryPerformance: Array<{
    channel: string;
    success_rate: number;
    avg_delivery_time_ms: number;
  }> = [];

  const channels = ['email', 'webhook', 'in_app', 'sms', 'slack'];
  for (const channel of channels) {
    const channelData = deliveryData?.filter(d => d.channel === channel) || [];
    const avgSuccessRate = channelData.length > 0 
      ? channelData.reduce((sum, d) => sum + d.success_rate, 0) / channelData.length 
      : 95;
    const avgDeliveryTime = channelData.length > 0
      ? channelData.reduce((sum, d) => sum + d.avg_delivery_time_ms, 0) / channelData.length
      : 500;

    deliveryPerformance.push({
      channel,
      success_rate: avgSuccessRate,
      avg_delivery_time_ms: avgDeliveryTime
    });
  }

  // Get top subscribed datasets (simulated from subscription patterns)
  const topDatasets = [
    { dataset_pattern: 'daily_.*', subscription_count: 15 },
    { dataset_pattern: 'store_.*', subscription_count: 12 },
    { dataset_pattern: '.*_gold', subscription_count: 8 },
    { dataset_pattern: 'ml_.*', subscription_count: 6 },
    { dataset_pattern: '.*_platinum', subscription_count: 4 }
  ];

  // Calculate user engagement
  const totalActiveUsers = subscriptionData?.length || 0;
  const avgSubscriptionsPerUser = totalActiveUsers > 0 
    ? (subscriptionData?.reduce((sum, u) => sum + u.total_subscriptions, 0) || 0) / totalActiveUsers 
    : 0;

  return {
    queue_summary: {
      pending_notifications: pending,
      failed_notifications: failed,
      total_sent_today: totalSent,
      success_rate: successRate
    },
    delivery_performance: deliveryPerformance,
    top_subscribed_datasets: topDatasets,
    user_engagement: {
      total_active_users: totalActiveUsers,
      avg_subscriptions_per_user: avgSubscriptionsPerUser,
      most_popular_channels: ['email', 'in_app', 'webhook']
    }
  };
}

/**
 * Get user's notifications (in-app)
 */
async function getUserNotifications(userId: string, limit: number = 50, offset: number = 0): Promise<any[]> {
  const { data, error } = await supabase
    .from('notification_queue')
    .select('*')
    .eq('user_id', userId)
    .eq('channel', 'in_app')
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);

  if (error) {
    throw new Error(`Failed to fetch notifications: ${error.message}`);
  }

  return data || [];
}

/**
 * Mark notification as read
 */
async function markNotificationAsRead(userId: string, notificationId: string): Promise<void> {
  const { error } = await supabase
    .from('notification_queue')
    .update({ 
      status: 'read',
      read_at: new Date().toISOString()
    })
    .eq('notification_id', notificationId)
    .eq('user_id', userId);

  if (error) {
    throw new Error(`Failed to mark notification as read: ${error.message}`);
  }
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const { pathname, searchParams } = url;
    
    // Extract user ID from authorization header (simplified)
    const authHeader = req.headers.get('authorization');
    const userId = searchParams.get('user_id') || 'anonymous'; // In production, extract from JWT

    // Route: Create subscription
    if (pathname === '/subscriptions' && req.method === 'POST') {
      const subscriptionRequest = await req.json();
      const subscription = await createSubscription(userId, subscriptionRequest);

      return new Response(JSON.stringify(subscription), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Route: Get user subscriptions
    if (pathname === '/subscriptions' && req.method === 'GET') {
      const subscriptions = await getUserSubscriptions(userId);

      return new Response(JSON.stringify(subscriptions), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Route: Update subscription
    if (pathname.startsWith('/subscriptions/') && req.method === 'PUT') {
      const subscriptionId = pathname.split('/')[2];
      const updates = await req.json();
      const subscription = await updateSubscription(userId, subscriptionId, updates);

      return new Response(JSON.stringify(subscription), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Route: Delete subscription
    if (pathname.startsWith('/subscriptions/') && req.method === 'DELETE') {
      const subscriptionId = pathname.split('/')[2];
      await deleteSubscription(userId, subscriptionId);

      return new Response(JSON.stringify({ success: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Route: Trigger notifications (webhook endpoint)
    if (pathname === '/trigger' && req.method === 'POST') {
      const event = await req.json();
      const result = await triggerNotifications(event);

      return new Response(JSON.stringify(result), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Route: Process notification queue (admin)
    if (pathname === '/process-queue' && req.method === 'POST') {
      const limit = parseInt(searchParams.get('limit') || '100');
      const result = await processNotificationQueue(limit);

      return new Response(JSON.stringify(result), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Route: Get user notification summary
    if (pathname === '/summary' && req.method === 'GET') {
      const days = parseInt(searchParams.get('days') || '7');
      const summary = await getUserNotificationSummary(userId, days);

      return new Response(JSON.stringify(summary), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Route: Get notification statistics
    if (pathname === '/stats' && req.method === 'GET') {
      const stats = await getNotificationStats();

      return new Response(JSON.stringify(stats), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Route: Get user notifications (in-app)
    if (pathname === '/notifications' && req.method === 'GET') {
      const limit = parseInt(searchParams.get('limit') || '50');
      const offset = parseInt(searchParams.get('offset') || '0');
      const notifications = await getUserNotifications(userId, limit, offset);

      return new Response(JSON.stringify(notifications), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Route: Mark notification as read
    if (pathname.startsWith('/notifications/') && pathname.endsWith('/read') && req.method === 'POST') {
      const notificationId = pathname.split('/')[2];
      await markNotificationAsRead(userId, notificationId);

      return new Response(JSON.stringify({ success: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Route: Health check
    if (pathname === '/health') {
      return new Response(JSON.stringify({
        status: 'healthy',
        features: [
          'dataset_subscriptions',
          'multi_channel_notifications',
          'notification_templates',
          'delivery_tracking',
          'user_preferences'
        ],
        timestamp: new Date().toISOString()
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    return new Response(JSON.stringify({ error: 'Route not found' }), {
      status: 404,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('Dataset subscriptions error:', error);

    return new Response(JSON.stringify({
      error: 'Internal server error',
      message: error.message,
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});