#!/usr/bin/env node
/**
 * Generate JWT token for storage_uploader role
 * This creates secure tokens for edge devices to upload datasets
 */

const crypto = require('crypto');

// Get JWT secret from environment
const JWT_SECRET = process.env.SUPABASE_JWT_SECRET;

if (!JWT_SECRET) {
    console.error('❌ Error: SUPABASE_JWT_SECRET environment variable is required');
    console.error('Get it from: Supabase Dashboard → Settings → API → JWT Secret');
    process.exit(1);
}

// Parse command line arguments
const args = process.argv.slice(2);
const days = parseInt(args.find(a => a.startsWith('--days='))?.split('=')[1] || '30');
const name = args.find(a => a.startsWith('--name='))?.split('=')[1] || 'edge-device';

// Create JWT payload
const payload = {
    role: 'storage_uploader',
    iss: 'supabase',
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + (days * 24 * 60 * 60),
    sub: name,
    aud: 'authenticated'
};

// Simple JWT implementation (for Node.js without external dependencies)
function base64url(str) {
    return Buffer.from(str)
        .toString('base64')
        .replace(/=/g, '')
        .replace(/\+/g, '-')
        .replace(/\//g, '_');
}

const header = base64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
const payloadStr = base64url(JSON.stringify(payload));
const signature = base64url(
    crypto
        .createHmac('sha256', JWT_SECRET)
        .update(`${header}.${payloadStr}`)
        .digest()
);

const token = `${header}.${payloadStr}.${signature}`;

// Output results
console.log('✅ Storage Uploader Token Generated!\n');
console.log('Token Name:', name);
console.log('Expires in:', days, 'days');
console.log('Role:', 'storage_uploader (upload-only access to scout/v1/*)\n');
console.log('═══════════════════════════════════════════════════════════\n');
console.log('TOKEN (give this to your colleague):\n');
console.log(token);
console.log('\n═══════════════════════════════════════════════════════════\n');
console.log('Create .env file for colleague with:\n');
console.log('SUPABASE_URL=https://cxzllzyxwpyptfretryc.supabase.co');
console.log(`SUPABASE_STORAGE_TOKEN=${token}`);
console.log('\n═══════════════════════════════════════════════════════════');
