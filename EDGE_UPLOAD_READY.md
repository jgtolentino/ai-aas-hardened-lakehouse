# 🔐 Secure Edge Upload Setup - Quick Guide

## ✅ Storage Uploader Role Created!

The `storage_uploader` role is now active in your Supabase database with:
- **SELECT** on storage.buckets  
- **SELECT, INSERT, UPDATE** on storage.objects
- Restricted to `scout/v1/*` paths only

## 📝 Generate Tokens for Colleagues

1. **Get your JWT Secret:**
   - Go to: https://supabase.com/dashboard/project/cxzllzyxwpyptfretryc/settings/api
   - Copy the JWT Secret value

2. **Generate tokens:**
```bash
# Set JWT secret
export SUPABASE_JWT_SECRET="your-jwt-secret-here"

# For colleague 1 (30-day token)
node scripts/generate-storage-token.js --days=30 --name=colleague1-pi5

# For colleague 2 (7-day test token)  
node scripts/generate-storage-token.js --days=7 --name=colleague2-test
```

## 📦 What to Send Your Colleagues

1. **Create their `.env` file:**
```env
SUPABASE_URL=https://cxzllzyxwpyptfretryc.supabase.co
SUPABASE_STORAGE_TOKEN=eyJ... (their generated token)
```

2. **Send them:**
- The `.env` file
- The `edge-upload.sh` script
- This instruction:
  ```bash
  # On their Pi 5 or laptop
  chmod +x edge-upload.sh
  ./edge-upload.sh /path/to/datasets
  ```

## 🔒 Security Features

Your colleagues **CAN**:
- ✅ Upload CSV/Parquet files to scout/v1/*
- ✅ Update existing files (upsert)
- ✅ Create manifests

Your colleagues **CANNOT**:
- ❌ Delete any files
- ❌ Access database tables
- ❌ Read other buckets
- ❌ Modify permissions
- ❌ Access files outside scout/v1/*

## 🔄 Token Management

- Tokens expire automatically (configurable days)
- Revoke access anytime by dropping the role:
  ```sql
  DROP ROLE storage_uploader;
  ```
- Monitor uploads in Storage dashboard

## 📊 Next Steps

1. Generate tokens for your 2 colleagues
2. Test upload with sample dataset
3. Deploy edge-upload.sh to Pi 5
4. Set up cron job for automated uploads (optional)
