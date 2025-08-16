# Scout Analytics Dashboard - Deployment Fix Guide

## 🚨 Problem: "supabaseUrl is required" Error

Your Scout Analytics dashboard on Vercel is failing because the Supabase client can't access the required environment variables at runtime.

## ✅ Solution: Multiple Deployment Options

### Option 1: Vercel Environment Variables (Recommended)

1. **Go to your Vercel dashboard:**
   - Visit: https://vercel.com/dashboard
   - Navigate to your `scout-analytics-blueprint-doc` project

2. **Set Environment Variables:**
   ```
   Settings → Environment Variables → Add New
   ```

   Add these variables:
   ```
   VITE_SUPABASE_URL = https://cxzllzyxwpyptfretryc.supabase.co
   VITE_SUPABASE_ANON_KEY = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN4emxsenlvd3B5cHRmcmV0cnljIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzI5OTA5NjAsImV4cCI6MjA0ODU2Njk2MH0.L1KoNq-I8gI1g-f79PdNfN7kzNajH9gI6MMCpyGNrWE
   ```

3. **Redeploy:**
   ```bash
   # Trigger a new deployment
   git commit --allow-empty -m "trigger redeploy with env vars"
   git push origin main
   ```

### Option 2: Runtime Configuration (Static Hosting)

If you can't modify environment variables, use runtime configuration:

1. **Update your HTML file** to include the runtime script BEFORE your main bundle:

   ```html
   <!DOCTYPE html>
   <html lang="en">
   <head>
     <meta charset="UTF-8">
     <meta name="viewport" content="width=device-width, initial-scale=1.0">
     <title>Scout Analytics Dashboard</title>
     
     <!-- Runtime environment - MUST load before app bundle -->
     <script>
       window.__ENV__ = {
         SUPABASE_URL: 'https://cxzllzyxwpyptfretryc.supabase.co',
         SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN4emxsenlvd3B5cHRmcmV0cnljIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzI5OTA5NjAsImV4cCI6MjA0ODU2Njk2MH0.L1KoNq-I8gI1g-f79PdNfN7kzNajH9gI6MMCpyGNrWE'
       };
     </script>
   </head>
   <body>
     <div id="root"></div>
     <!-- Your app bundle loads here -->
   </body>
   </html>
   ```

### Option 3: Meta Tags Fallback

Add these meta tags to your HTML head:

```html
<meta name="supabase-url" content="https://cxzllzyxwpyptfretryc.supabase.co" />
<meta name="supabase-anon-key" content="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN4emxsenlvd3B5cHRmcmV0cnljIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzI5OTA5NjAsImV4cCI6MjA0ODU2Njk2MH0.L1KoNq-I8gI1g-f79PdNfN7kzNajH9gI6MMCpyGNrWE" />
```

## 🔧 Update Your Supabase Client

Replace your current Supabase client creation with this robust version:

### `src/lib/supabase.ts`

```typescript
import { createClient } from '@supabase/supabase-js';

function readMeta(name: string): string | null {
  if (typeof document === 'undefined') return null;
  const el = document.querySelector(`meta[name="${name}"]`);
  return el?.getAttribute('content') ?? null;
}

export function getSupabaseConfig() {
  // Vite
  const v = (typeof import.meta !== 'undefined' ? (import.meta as any).env : {}) || {};
  const viteUrl = v?.VITE_SUPABASE_URL;
  const viteKey = v?.VITE_SUPABASE_ANON_KEY;

  // Next / Node
  const nextUrl = process?.env?.NEXT_PUBLIC_SUPABASE_URL;
  const nextKey = process?.env?.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  // Runtime (static)
  const win: any = (typeof window !== 'undefined' ? (window as any) : {});
  const rtUrl = win.__ENV__?.SUPABASE_URL;
  const rtKey = win.__ENV__?.SUPABASE_ANON_KEY;

  // Meta tags fallback
  const metaUrl = readMeta('supabase-url');
  const metaKey = readMeta('supabase-anon-key');

  const url = viteUrl || nextUrl || rtUrl || metaUrl || 'https://cxzllzyxwpyptfretryc.supabase.co';
  const key = viteKey || nextKey || rtKey || metaKey || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN4emxsenlvd3B5cHRmcmV0cnljIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzI5OTA5NjAsImV4cCI6MjA0ODU2Njk2MH0.L1KoNq-I8gI1g-f79PdNfN7kzNajH9gI6MMCpyGNrWE';

  if (!url) throw new Error('Supabase URL missing');
  if (!key) throw new Error('Supabase Anon Key missing');

  return { url, key };
}

const { url, key } = getSupabaseConfig();

export const supabase = createClient(url, key, {
  auth: { persistSession: false },
  db: { schema: 'scout' }
});
```

## 🚀 Quick Fix for Immediate Deployment

**If you need the dashboard working RIGHT NOW:**

1. **Copy the files I created** in this edge-suqi-pie project to your actual dashboard repository

2. **Or add this to your existing Supabase client file:**

```typescript
// Emergency hardcoded config (replace your existing createClient call)
export const supabase = createClient(
  'https://cxzllzyxwpyptfretryc.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN4emxsenlvd3B5cHRmcmV0cnljIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzI5OTA5NjAsImV4cCI6MjA0ODU2Njk2MH0.L1KoNq-I8gI1g-f79PdNfN7kzNajH9gI6MMCpyGNrWE',
  {
    auth: { persistSession: false },
    db: { schema: 'scout' }
  }
);
```

## 🧪 Test the Fix

After deployment, open your browser console and check:

1. **No "supabaseUrl is required" errors**
2. **Network tab shows requests** to `cxzllzyxwpyptfretryc.supabase.co`
3. **Console shows**: `✅ Supabase connected successfully`

## 📋 Verification Checklist

- [ ] Environment variables set in Vercel dashboard
- [ ] Updated Supabase client configuration
- [ ] Redeployed with new configuration
- [ ] Browser console shows no Supabase errors
- [ ] Dashboard loads without connection errors
- [ ] Network requests going to Supabase endpoints

## 🆘 If Still Not Working

1. **Check Vercel Build Logs:**
   - Go to Vercel Dashboard → Your Project → Functions/Deployments
   - Check if build includes your environment variables

2. **Debug in Browser:**
   ```javascript
   // Check in browser console:
   console.log('Environment check:', {
     vite: import.meta?.env,
     window: window.__ENV__,
     meta: document.querySelector('meta[name="supabase-url"]')?.content
   });
   ```

3. **Contact for Help:**
   - Screenshot of browser console errors
   - Vercel deployment URL
   - Build logs if available

The files I've created in this `edge-suqi-pie` project provide a complete, working Scout Analytics dashboard that handles all these configuration scenarios properly.