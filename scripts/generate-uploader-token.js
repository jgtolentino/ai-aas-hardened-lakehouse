#!/usr/bin/env node
/**
 * Generate JWT token for storage_uploader role
 * 
 * This creates a secure token that colleagues can use to upload
 * datasets without having access to the Service Role Key
 * 
 * Usage:
 *   SUPABASE_JWT_SECRET=your_secret node scripts/generate-uploader-token.js
 *   
 * Options:
 *   --days <number>    Token expiry in days (default: 30)
 *   --name <string>    Optional identifier for the token
 */

const jwt = require('jsonwebtoken');
const crypto = require('crypto');

// Parse command line arguments
const args = process.argv.slice(2);
const daysIndex = args.indexOf('--days');
const nameIndex = args.indexOf('--name');

const expiryDays = daysIndex > -1 ? parseInt(args[daysIndex + 1]) : 30;
const tokenName = nameIndex > -1 ? args[nameIndex + 1] : null;

// Check for JWT secret
if (!process.env.SUPABASE_JWT_SECRET) {
  console.error('❌ Error: SUPABASE_JWT_SECRET environment variable is required');
  console.error('\nTo find your JWT secret:');
  console.error('1. Go to Supabase Dashboard → Settings → API');
  console.error('2. Look for "JWT Secret" under "Configuration"');
  console.error('3. Run: export SUPABASE_JWT_SECRET="your_secret_here"');
  process.exit(1);
}

// Generate unique token ID for tracking/revocation
const tokenId = crypto.randomBytes(8).toString('hex');

// Create JWT payload
const payload = {
  role: 'storage_uploader',
  aud: 'authenticated',
  // Custom claims for tracking
  token_id: tokenId,
  token_name: tokenName || 'edge-uploader',
  permissions: ['storage.upload', 'storage.read'],
  allowed_buckets: ['sample'],
  allowed_paths: ['scout/v1/**'],
  // Standard JWT claims
  iat: Math.floor(Date.now() / 1000),
  exp: Math.floor(Date.now() / 1000) + (expiryDays * 24 * 60 * 60)
};

// Sign the token
const token = jwt.sign(payload, process.env.SUPABASE_JWT_SECRET);

// Generate setup instructions
const setupInstructions = `
# ============================================
# Storage Uploader Token Generated Successfully
# ============================================

Token ID: ${tokenId}
Token Name: ${payload.token_name}
Expires: ${new Date(payload.exp * 1000).toISOString()} (${expiryDays} days)

## 1. Save this token (colleagues will use this instead of Service Role Key):
${token}

## 2. Create .env file for your colleagues:
------- START .env -------
SUPABASE_URL=https://cxzllzyxwpyptfretryc.supabase.co
SUPABASE_STORAGE_TOKEN=${token}
------- END .env -------

## 3. Example upload commands your colleagues can use:

### Using cURL:
curl -X POST "https://cxzllzyxwpyptfretryc.supabase.co/storage/v1/object/sample/scout/v1/gold/mydata.csv" \\
  -H "Authorization: Bearer \${SUPABASE_STORAGE_TOKEN}" \\
  -H "Content-Type: text/csv" \\
  --data-binary "@mydata.csv"

### Using Node.js:
\`\`\`javascript
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_STORAGE_TOKEN
);

const { data, error } = await supabase.storage
  .from('sample')
  .upload('scout/v1/gold/mydata.csv', fileBuffer, {
    contentType: 'text/csv',
    upsert: true
  });
\`\`\`

### Using Supabase CLI:
supabase storage upload \\
  sample/scout/v1/gold/mydata.csv \\
  ./mydata.csv \\
  --url \$SUPABASE_URL \\
  --api-key \$SUPABASE_STORAGE_TOKEN

## 4. Security notes:
- This token can ONLY upload to scout/v1/* paths
- Cannot delete files or access the database
- Cannot read files outside scout/v1/*
- Expires automatically in ${expiryDays} days

## 5. To revoke this token:
Change your JWT secret in Supabase Dashboard (invalidates ALL tokens)
or implement a token blacklist in your Edge Functions
`;

console.log(setupInstructions);

// Also save to file for easy sharing
const fs = require('fs');
const outputFile = `storage-uploader-token-${tokenId}.txt`;
fs.writeFileSync(outputFile, setupInstructions);
console.log(`\n✅ Instructions also saved to: ${outputFile}`);