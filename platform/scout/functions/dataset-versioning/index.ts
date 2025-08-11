import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

/**
 * Dataset Versioning and Rollback System
 * 
 * Provides version control and rollback capabilities for datasets in the
 * Scout Analytics platform, enabling safe updates and data lineage tracking.
 */

interface DatasetVersion {
  version_id: string;
  dataset_name: string;
  version_number: string;
  version_tag?: string;
  file_path: string;
  file_size: number;
  checksum: string;
  schema_version: string;
  created_by: string;
  created_at: string;
  metadata: Record<string, any>;
  status: 'active' | 'archived' | 'deprecated';
  parent_version_id?: string;
  change_description?: string;
}

interface RollbackRequest {
  dataset_name: string;
  target_version: string;
  reason: string;
  backup_current?: boolean;
}

interface RollbackResult {
  rollback_id: string;
  dataset_name: string;
  from_version: string;
  to_version: string;
  status: 'success' | 'failed' | 'in_progress';
  backup_version_id?: string;
  error_message?: string;
  completed_at?: string;
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
 * Generate semantic version number
 */
function generateVersionNumber(lastVersion: string, changeType: 'major' | 'minor' | 'patch' = 'patch'): string {
  if (!lastVersion) {
    return '1.0.0';
  }

  const [major, minor, patch] = lastVersion.split('.').map(Number);
  
  switch (changeType) {
    case 'major':
      return `${major + 1}.0.0`;
    case 'minor':
      return `${major}.${minor + 1}.0`;
    case 'patch':
    default:
      return `${major}.${minor}.${patch + 1}`;
  }
}

/**
 * Calculate file checksum (MD5 hash)
 */
async function calculateChecksum(content: Uint8Array): Promise<string> {
  const hashBuffer = await crypto.subtle.digest('MD5', content);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

/**
 * Create a new dataset version
 */
async function createDatasetVersion(
  datasetName: string,
  filePath: string,
  changeType: 'major' | 'minor' | 'patch' = 'patch',
  metadata: Record<string, any> = {},
  changeDescription?: string,
  versionTag?: string,
  createdBy: string = 'system'
): Promise<DatasetVersion> {
  
  // Get the latest version
  const { data: latestVersion } = await supabase
    .from('dataset_versions')
    .select('version_number')
    .eq('dataset_name', datasetName)
    .eq('status', 'active')
    .order('created_at', { ascending: false })
    .limit(1);

  const lastVersionNumber = latestVersion?.[0]?.version_number || '0.0.0';
  const newVersionNumber = generateVersionNumber(lastVersionNumber, changeType);

  // Download file to get size and checksum
  let fileSize = 0;
  let checksum = '';
  
  try {
    const { data: fileData } = await supabase.storage
      .from('scout-platinum')
      .download(filePath.startsWith('/') ? filePath.substring(1) : filePath);
    
    if (fileData) {
      const content = new Uint8Array(await fileData.arrayBuffer());
      fileSize = content.length;
      checksum = await calculateChecksum(content);
    }
  } catch (error) {
    console.warn('Failed to calculate checksum:', error);
    checksum = 'unavailable';
  }

  // Create version record
  const versionId = crypto.randomUUID();
  
  const newVersion: Partial<DatasetVersion> = {
    version_id: versionId,
    dataset_name: datasetName,
    version_number: newVersionNumber,
    version_tag: versionTag,
    file_path: filePath,
    file_size: fileSize,
    checksum: checksum,
    schema_version: metadata.schema_version || '1.0',
    created_by: createdBy,
    created_at: new Date().toISOString(),
    metadata: metadata,
    status: 'active',
    change_description: changeDescription,
  };

  const { data, error } = await supabase
    .from('dataset_versions')
    .insert(newVersion)
    .select()
    .single();

  if (error) {
    throw new Error(`Failed to create version: ${error.message}`);
  }

  // Mark previous versions as archived
  await supabase
    .from('dataset_versions')
    .update({ status: 'archived' })
    .eq('dataset_name', datasetName)
    .neq('version_id', versionId)
    .eq('status', 'active');

  return data as DatasetVersion;
}

/**
 * Get dataset versions with pagination
 */
async function getDatasetVersions(
  datasetName?: string,
  limit: number = 50,
  offset: number = 0
): Promise<DatasetVersion[]> {
  let query = supabase
    .from('dataset_versions')
    .select('*')
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);

  if (datasetName) {
    query = query.eq('dataset_name', datasetName);
  }

  const { data, error } = await query;

  if (error) {
    throw new Error(`Failed to fetch versions: ${error.message}`);
  }

  return data || [];
}

/**
 * Get specific version details
 */
async function getVersionDetails(versionId: string): Promise<DatasetVersion | null> {
  const { data, error } = await supabase
    .from('dataset_versions')
    .select('*')
    .eq('version_id', versionId)
    .single();

  if (error) {
    if (error.code === 'PGRST116') {
      return null; // Not found
    }
    throw new Error(`Failed to fetch version: ${error.message}`);
  }

  return data as DatasetVersion;
}

/**
 * Perform dataset rollback
 */
async function rollbackDataset(request: RollbackRequest): Promise<RollbackResult> {
  const rollbackId = crypto.randomUUID();
  
  try {
    // Get current active version
    const { data: currentVersion } = await supabase
      .from('dataset_versions')
      .select('*')
      .eq('dataset_name', request.dataset_name)
      .eq('status', 'active')
      .single();

    if (!currentVersion) {
      throw new Error('No active version found for dataset');
    }

    // Get target version
    const targetVersion = await getVersionDetails(request.target_version);
    if (!targetVersion) {
      throw new Error('Target version not found');
    }

    // Create backup of current version if requested
    let backupVersionId: string | undefined;
    
    if (request.backup_current) {
      const backup = await createDatasetVersion(
        request.dataset_name,
        currentVersion.file_path,
        'patch',
        { ...currentVersion.metadata, rollback_backup: true },
        `Backup before rollback to ${targetVersion.version_number}`,
        `backup-${Date.now()}`,
        'system'
      );
      backupVersionId = backup.version_id;
    }

    // Create rollback log entry
    const { error: logError } = await supabase
      .from('dataset_rollbacks')
      .insert({
        rollback_id: rollbackId,
        dataset_name: request.dataset_name,
        from_version_id: currentVersion.version_id,
        to_version_id: request.target_version,
        reason: request.reason,
        backup_version_id: backupVersionId,
        status: 'in_progress',
        initiated_by: 'api',
        initiated_at: new Date().toISOString(),
      });

    if (logError) {
      throw new Error(`Failed to log rollback: ${logError.message}`);
    }

    // Perform the rollback by updating version statuses
    await supabase
      .from('dataset_versions')
      .update({ status: 'archived' })
      .eq('dataset_name', request.dataset_name)
      .eq('status', 'active');

    await supabase
      .from('dataset_versions')
      .update({ status: 'active' })
      .eq('version_id', request.target_version);

    // Update rollback status
    await supabase
      .from('dataset_rollbacks')
      .update({ 
        status: 'success',
        completed_at: new Date().toISOString()
      })
      .eq('rollback_id', rollbackId);

    return {
      rollback_id: rollbackId,
      dataset_name: request.dataset_name,
      from_version: currentVersion.version_number,
      to_version: targetVersion.version_number,
      status: 'success',
      backup_version_id: backupVersionId,
      completed_at: new Date().toISOString(),
    };

  } catch (error) {
    // Update rollback status to failed
    await supabase
      .from('dataset_rollbacks')
      .update({ 
        status: 'failed',
        error_message: error.message,
        completed_at: new Date().toISOString()
      })
      .eq('rollback_id', rollbackId);

    return {
      rollback_id: rollbackId,
      dataset_name: request.dataset_name,
      from_version: 'unknown',
      to_version: 'unknown',
      status: 'failed',
      error_message: error.message,
      completed_at: new Date().toISOString(),
    };
  }
}

/**
 * Compare two dataset versions
 */
async function compareVersions(version1Id: string, version2Id: string): Promise<{
  version1: DatasetVersion;
  version2: DatasetVersion;
  differences: {
    file_size_change: number;
    schema_changed: boolean;
    metadata_changes: string[];
    time_difference: string;
  };
}> {
  const [v1, v2] = await Promise.all([
    getVersionDetails(version1Id),
    getVersionDetails(version2Id)
  ]);

  if (!v1 || !v2) {
    throw new Error('One or both versions not found');
  }

  // Calculate differences
  const fileSizeChange = v2.file_size - v1.file_size;
  const schemaChanged = v1.schema_version !== v2.schema_version;
  const metadataChanges: string[] = [];

  // Compare metadata
  const v1Keys = Object.keys(v1.metadata || {});
  const v2Keys = Object.keys(v2.metadata || {});
  const allKeys = new Set([...v1Keys, ...v2Keys]);

  for (const key of allKeys) {
    const v1Value = v1.metadata?.[key];
    const v2Value = v2.metadata?.[key];
    
    if (JSON.stringify(v1Value) !== JSON.stringify(v2Value)) {
      metadataChanges.push(key);
    }
  }

  const timeDiff = new Date(v2.created_at).getTime() - new Date(v1.created_at).getTime();
  const daysDiff = Math.floor(timeDiff / (1000 * 60 * 60 * 24));
  const hoursDiff = Math.floor((timeDiff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));

  return {
    version1: v1,
    version2: v2,
    differences: {
      file_size_change: fileSizeChange,
      schema_changed: schemaChanged,
      metadata_changes: metadataChanges,
      time_difference: `${daysDiff} days, ${hoursDiff} hours`,
    }
  };
}

/**
 * Get rollback history
 */
async function getRollbackHistory(datasetName?: string): Promise<any[]> {
  let query = supabase
    .from('dataset_rollbacks')
    .select(`
      *,
      from_version:dataset_versions!from_version_id(version_number, version_tag),
      to_version:dataset_versions!to_version_id(version_number, version_tag)
    `)
    .order('initiated_at', { ascending: false });

  if (datasetName) {
    query = query.eq('dataset_name', datasetName);
  }

  const { data, error } = await query;

  if (error) {
    throw new Error(`Failed to fetch rollback history: ${error.message}`);
  }

  return data || [];
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const { pathname, searchParams } = url;

    // Route: Create new dataset version
    if (pathname === '/versions' && req.method === 'POST') {
      const {
        dataset_name,
        file_path,
        change_type = 'patch',
        metadata = {},
        change_description,
        version_tag,
        created_by = 'api'
      } = await req.json();

      if (!dataset_name || !file_path) {
        return new Response(JSON.stringify({
          error: 'Missing required fields: dataset_name, file_path'
        }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      const version = await createDatasetVersion(
        dataset_name,
        file_path,
        change_type,
        metadata,
        change_description,
        version_tag,
        created_by
      );

      return new Response(JSON.stringify(version), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Route: Get dataset versions
    if (pathname === '/versions' && req.method === 'GET') {
      const datasetName = searchParams.get('dataset');
      const limit = parseInt(searchParams.get('limit') || '50');
      const offset = parseInt(searchParams.get('offset') || '0');

      const versions = await getDatasetVersions(datasetName || undefined, limit, offset);

      return new Response(JSON.stringify(versions), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Route: Get specific version
    if (pathname.startsWith('/versions/') && req.method === 'GET') {
      const versionId = pathname.split('/')[2];
      const version = await getVersionDetails(versionId);

      if (!version) {
        return new Response(JSON.stringify({ error: 'Version not found' }), {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      return new Response(JSON.stringify(version), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Route: Rollback dataset
    if (pathname === '/rollback' && req.method === 'POST') {
      const rollbackRequest = await req.json();

      if (!rollbackRequest.dataset_name || !rollbackRequest.target_version || !rollbackRequest.reason) {
        return new Response(JSON.stringify({
          error: 'Missing required fields: dataset_name, target_version, reason'
        }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      const result = await rollbackDataset(rollbackRequest);

      return new Response(JSON.stringify(result), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Route: Compare versions
    if (pathname === '/compare' && req.method === 'GET') {
      const version1 = searchParams.get('version1');
      const version2 = searchParams.get('version2');

      if (!version1 || !version2) {
        return new Response(JSON.stringify({
          error: 'Both version1 and version2 parameters are required'
        }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      const comparison = await compareVersions(version1, version2);

      return new Response(JSON.stringify(comparison), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Route: Get rollback history
    if (pathname === '/rollbacks' && req.method === 'GET') {
      const datasetName = searchParams.get('dataset');
      const history = await getRollbackHistory(datasetName || undefined);

      return new Response(JSON.stringify(history), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Route: Health check
    if (pathname === '/health') {
      return new Response(JSON.stringify({
        status: 'healthy',
        features: [
          'version_creation',
          'rollback_management', 
          'version_comparison',
          'rollback_history'
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
    console.error('Dataset versioning error:', error);

    return new Response(JSON.stringify({
      error: 'Internal server error',
      message: error.message,
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});