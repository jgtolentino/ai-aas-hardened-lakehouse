#!/usr/bin/env python3
"""
Generate Storage Upload Tokens for Colleagues
Creates 30-day JWT tokens for secure dataset uploads
"""

import os
import json
import base64
import hmac
import hashlib
import time
import secrets
from datetime import datetime, timedelta

def base64url_encode(data):
    """Encode data to base64url format"""
    if isinstance(data, str):
        data = data.encode('utf-8')
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode('utf-8')

def generate_token(name, jwt_secret, expiry_days=30):
    """Generate a JWT token for storage uploads"""
    
    # Generate unique token ID
    token_id = secrets.token_hex(8)
    
    # Create header
    header = {
        "alg": "HS256",
        "typ": "JWT"
    }
    
    # Create payload
    now = int(time.time())
    exp = now + (expiry_days * 24 * 60 * 60)
    
    payload = {
        "role": "storage_uploader",
        "aud": "authenticated",
        "token_id": token_id,
        "token_name": name,
        "permissions": ["storage.upload", "storage.read"],
        "allowed_buckets": ["sample"],
        "allowed_paths": ["scout/v1/**"],
        "iat": now,
        "exp": exp
    }
    
    # Encode header and payload
    header_encoded = base64url_encode(json.dumps(header, separators=(',', ':')))
    payload_encoded = base64url_encode(json.dumps(payload, separators=(',', ':')))
    
    # Create signature
    message = f"{header_encoded}.{payload_encoded}"
    signature = hmac.new(
        jwt_secret.encode('utf-8'),
        message.encode('utf-8'),
        hashlib.sha256
    ).digest()
    signature_encoded = base64url_encode(signature)
    
    # Complete JWT
    jwt = f"{message}.{signature_encoded}"
    
    return jwt, token_id, exp

def save_token_file(name, token, token_id, exp_timestamp):
    """Save token and instructions to file"""
    
    filename = f"token-{name}-{token_id}.txt"
    exp_date = datetime.fromtimestamp(exp_timestamp)
    
    content = f"""# ============================================
# Storage Upload Token for: {name}
# ============================================

Token ID: {token_id}
Created: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
Expires: {exp_date.strftime('%Y-%m-%d %H:%M:%S')}
Duration: 30 days

## 1. Save this .env file:
------- START .env -------
SUPABASE_URL=https://cxzllzyxwpyptfretryc.supabase.co
SUPABASE_STORAGE_TOKEN={token}
------- END .env -------

## 2. Test upload command:
curl -X POST "https://cxzllzyxwpyptfretryc.supabase.co/storage/v1/object/sample/scout/v1/test.txt" \\
  -H "Authorization: Bearer $SUPABASE_STORAGE_TOKEN" \\
  -H "Content-Type: text/plain" \\
  -d "Test upload from {name}"

## 3. Use edge-upload.sh script:
./edge-upload.sh /path/to/datasets

## Security Notes:
- Can ONLY upload to scout/v1/* paths
- Cannot delete files or access database
- Expires automatically in 30 days
"""
    
    with open(filename, 'w') as f:
        f.write(content)
    
    return filename

def main():
    # Check for JWT secret
    jwt_secret = os.environ.get('SUPABASE_JWT_SECRET')
    if not jwt_secret:
        print("❌ Error: SUPABASE_JWT_SECRET not set")
        print("")
        print("Get it from Supabase Dashboard → Settings → API → JWT Secret")
        print("Then run: export SUPABASE_JWT_SECRET='your-secret-here'")
        exit(1)
    
    print("🔐 Generating 30-day Storage Upload Tokens")
    print("==========================================")
    print("")
    
    # Generate tokens for both colleagues
    colleagues = ["colleague1-pi5", "colleague2-pi5"]
    
    for name in colleagues:
        token, token_id, exp = generate_token(name, jwt_secret, expiry_days=30)
        filename = save_token_file(name, token, token_id, exp)
        
        print(f"✅ Token generated: {filename}")
        print(f"   Token ID: {token_id}")
        print("")
    
    print("📋 Summary:")
    print("- Both tokens expire in 30 days")
    print("- Tokens saved to token-*.txt files")
    print("- Share these files with your colleagues")
    print("")
    print("⚠️  Security Reminder:")
    print("- Never share the SUPABASE_JWT_SECRET")
    print("- These tokens can ONLY upload to scout/v1/*")
    print("- Tokens cannot delete files or access the database")

if __name__ == "__main__":
    main()