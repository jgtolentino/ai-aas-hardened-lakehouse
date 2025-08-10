# Edge Device Upload Guide

## 🔐 Secure Upload Setup for Team Members

This guide explains how to give your colleagues secure upload access to Supabase Storage without exposing the Service Role Key.

## Step 1: Create Limited Permission Role

Run this SQL in your Supabase SQL Editor:

```sql
-- Run the setup script
-- This creates a 'storage_uploader' role with minimal permissions
-- Path: scripts/setup-storage-uploader.sql
```

The script creates a role that can ONLY:
- ✅ Upload files to `scout/v1/*` paths
- ✅ Update existing files (upsert)
- ✅ Read files they uploaded
- ❌ Cannot delete files
- ❌ Cannot access database
- ❌ Cannot read other buckets

## Step 2: Generate Secure Tokens

### Find your JWT Secret
1. Go to [Supabase Dashboard](https://app.supabase.com/project/cxzllzyxwpyptfretryc/settings/api)
2. Navigate to Settings → API
3. Copy the "JWT Secret" (keep this secret!)

### Generate Token for Colleagues
```bash
# Set your JWT secret
export SUPABASE_JWT_SECRET="your_jwt_secret_here"

# Generate a 30-day token
node scripts/generate-uploader-token.js

# Or generate a custom duration token
node scripts/generate-uploader-token.js --days 7 --name "pi5-device"
```

This generates:
- A secure JWT token
- Instructions file
- Example upload commands

## Step 3: Share with Colleagues

Give your colleagues:

### 1. Environment File (.env)
```env
SUPABASE_URL=https://cxzllzyxwpyptfretryc.supabase.co
SUPABASE_STORAGE_TOKEN=eyJhbGciOiJIUzI1NiIs... (the generated token)
```

### 2. Upload Script (for Pi 5)
Copy `scripts/edge-upload.sh` to the Raspberry Pi:

```bash
# On Pi 5
wget https://raw.githubusercontent.com/your-repo/main/scripts/edge-upload.sh
chmod +x edge-upload.sh

# Create .env with the token
nano .env
# Paste the SUPABASE_URL and SUPABASE_STORAGE_TOKEN

# Upload datasets
./edge-upload.sh
```

### 3. Manual Upload Examples

#### Using cURL:
```bash
curl -X POST "https://cxzllzyxwpyptfretryc.supabase.co/storage/v1/object/sample/scout/v1/gold/transactions.csv" \
  -H "Authorization: Bearer $SUPABASE_STORAGE_TOKEN" \
  -H "Content-Type: text/csv" \
  --data-binary "@transactions.csv"
```

#### Using Node.js:
```javascript
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_STORAGE_TOKEN
);

const { data, error } = await supabase.storage
  .from('sample')
  .upload('scout/v1/gold/transactions.csv', fileBuffer, {
    contentType: 'text/csv',
    upsert: true
  });
```

## Security Best Practices

### ✅ DO:
- Generate separate tokens for each device/colleague
- Use short expiry times (7-30 days)
- Name tokens for easy tracking
- Store tokens in .env files (never commit)
- Rotate tokens regularly

### ❌ DON'T:
- Share the Service Role Key
- Share the JWT Secret
- Commit tokens to Git
- Use tokens in client-side code
- Generate tokens with long expiry (>90 days)

## Token Management

### List Active Tokens
Currently, tokens are stateless. To track them:
1. Keep a record of Token IDs when generating
2. Use the `--name` parameter for identification
3. Store generation dates

### Revoke Tokens
Two options:
1. **Wait for expiry** - Tokens auto-expire
2. **Emergency revoke all** - Change JWT Secret in Supabase (invalidates ALL tokens)

### Monitor Usage
Check upload activity in the audit logs:

```sql
-- View recent uploads
SELECT * FROM scout.dataset_access_logs 
WHERE accessed_at > NOW() - INTERVAL '24 hours'
ORDER BY accessed_at DESC;
```

## Troubleshooting

### "Unauthorized" Error
- Token expired - generate a new one
- Wrong token - check .env file
- JWT Secret changed - regenerate all tokens

### "Permission Denied" 
- Trying to upload outside `scout/v1/*`
- Trying to delete files (not allowed)
- Role not created - run setup SQL

### "Network Error"
- Check internet connection on Pi
- Verify Supabase URL is correct
- Check if behind firewall/proxy

## Quick Start for New Device

```bash
# 1. On your machine - generate token
export SUPABASE_JWT_SECRET="your_secret"
node scripts/generate-uploader-token.js --days 30 --name "new-pi5"

# 2. Copy token from output
# 3. SSH to Pi 5
ssh pi@raspberrypi.local

# 4. Setup on Pi
cd ~
wget https://raw.githubusercontent.com/your-repo/main/scripts/edge-upload.sh
chmod +x edge-upload.sh

# 5. Create .env
cat > .env << EOF
SUPABASE_URL=https://cxzllzyxwpyptfretryc.supabase.co
SUPABASE_STORAGE_TOKEN=<paste_token_here>
DATASET_DIR=/home/pi/datasets
EOF

# 6. Test upload
./edge-upload.sh
```

## Automated Upload (Cron)

For automatic uploads every hour:

```bash
# On Pi 5
crontab -e

# Add this line
0 * * * * cd /home/pi && ./edge-upload.sh >> upload.log 2>&1
```

---

**Note**: This system ensures your colleagues can upload datasets without having dangerous admin access. The tokens are limited in scope and time, making them safe to distribute to edge devices.