# TBWA Neural Workbench v2.0 - Deployment Guide

Complete deployment guide for getting Neural Workbench running in production environments.

## 🎯 Quick Deployment Summary

**Local Development**: 5 minutes with `./launch.sh`  
**Streamlit Cloud**: 10 minutes with GitHub integration  
**Docker Production**: 15 minutes with container deployment  
**Enterprise**: 30 minutes with full database integration

## 📋 Prerequisites

### System Requirements
- **Python**: 3.8+ (recommended: 3.11)
- **Memory**: Minimum 2GB RAM (4GB+ recommended)
- **Storage**: 1GB free space for dependencies
- **Network**: Internet access for package installation

### Optional Requirements
- **Database**: Supabase project for persistence and collaboration
- **Authentication**: TBWA SSO/LDAP for enterprise deployment
- **Storage**: Cloud storage for large file uploads (S3/GCS)

## 🚀 Deployment Options

### Option 1: Local Development (Fastest)

**Time**: ~5 minutes  
**Use Case**: Development, testing, demos

```bash
cd /Users/tbwa/ai-aas-hardened-lakehouse/apps/neural-workbench-streamlit

# Quick start with launch script
./launch.sh

# Manual start (if preferred)
pip install -r requirements.txt
streamlit run streamlit_app.py
```

**Access**: http://localhost:8501

### Option 2: Streamlit Cloud (Recommended)

**Time**: ~10 minutes  
**Use Case**: Team sharing, quick production deployment

#### Setup Steps:

1. **Push to GitHub**:
   ```bash
   git add .
   git commit -m "feat: Neural Workbench v2.0 Streamlit app"
   git push origin main
   ```

2. **Deploy to Streamlit Cloud**:
   - Visit [share.streamlit.io](https://share.streamlit.io)
   - Connect your GitHub account
   - Select repository: `ai-aas-hardened-lakehouse`
   - Set main file path: `apps/neural-workbench-streamlit/streamlit_app.py`
   - Add secrets (optional):
     ```toml
     # .streamlit/secrets.toml
     SUPABASE_URL = "https://cxzllzyxwpyptfretryc.supabase.co"
     SUPABASE_ANON_KEY = "your_anon_key"
     ```

3. **Configure Custom Domain** (optional):
   - Add CNAME record: `neural.tbwa.com` → `your-app.streamlit.app`
   - Update Streamlit Cloud domain settings

**Result**: Public URL like `https://neural-workbench.streamlit.app`

### Option 3: Docker Production

**Time**: ~15 minutes  
**Use Case**: Containerized deployment, Kubernetes, cloud platforms

#### Create Dockerfile:

```dockerfile
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Expose Streamlit port
EXPOSE 8501

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD curl --fail http://localhost:8501/_stcore/health || exit 1

# Run the application
CMD ["streamlit", "run", "streamlit_app.py", "--server.port=8501", "--server.address=0.0.0.0"]
```

#### Build and Deploy:

```bash
# Build image
docker build -t tbwa/neural-workbench:v2.0 .

# Run locally
docker run -p 8501:8501 tbwa/neural-workbench:v2.0

# Deploy to cloud (example with Google Cloud Run)
gcloud run deploy neural-workbench \
  --image tbwa/neural-workbench:v2.0 \
  --platform managed \
  --port 8501 \
  --memory 2Gi \
  --allow-unauthenticated
```

### Option 4: Enterprise Deployment

**Time**: ~30 minutes  
**Use Case**: Full production with database, authentication, monitoring

#### Prerequisites:
- Supabase project with neural schema deployed
- TBWA authentication system (SSO/LDAP)
- Cloud storage bucket for file uploads
- Monitoring infrastructure (optional)

#### Environment Configuration:

```bash
# Production environment variables
export SUPABASE_URL="https://cxzllzyxwpyptfretryc.supabase.co"
export SUPABASE_ANON_KEY="your_production_anon_key"
export SUPABASE_SERVICE_ROLE_KEY="your_service_role_key"
export AUTH_ENABLED="true"
export TBWA_DOMAIN="tbwa.com"
export MAX_UPLOAD_SIZE_MB="500"
export LOG_LEVEL="INFO"
```

#### Database Setup:
1. Apply neural schema migration:
   ```bash
   # Use the migration script created earlier
   ./apply-neural-schema.sh
   ```

2. Verify schema deployment:
   ```sql
   SELECT table_name FROM information_schema.tables 
   WHERE table_schema = 'neural' ORDER BY table_name;
   ```

#### Load Balancer Configuration:
```nginx
upstream neural_workbench {
    server 127.0.0.1:8501;
    server 127.0.0.1:8502;
    server 127.0.0.1:8503;
}

server {
    listen 443 ssl http2;
    server_name neural.tbwa.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    location / {
        proxy_pass http://neural_workbench;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## 🔧 Configuration Reference

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SUPABASE_URL` | No | None | Supabase project URL for persistence |
| `SUPABASE_ANON_KEY` | No | None | Supabase anonymous key |
| `SUPABASE_SERVICE_ROLE_KEY` | No | None | Supabase service role key (admin operations) |
| `APP_TITLE` | No | "TBWA Neural Workbench v2.0" | Application title |
| `APP_DESCRIPTION` | No | "10-minute magic..." | Application description |
| `MAX_UPLOAD_SIZE_MB` | No | 200 | Maximum file upload size in MB |
| `AUTH_ENABLED` | No | false | Enable user authentication |
| `TBWA_DOMAIN` | No | tbwa.com | Corporate domain for authentication |
| `DEBUG` | No | false | Enable debug logging |
| `LOG_LEVEL` | No | INFO | Logging level (DEBUG/INFO/WARN/ERROR) |

### Streamlit Configuration

#### config.toml Settings:
```toml
[global]
dataFrameSerialization = "legacy"

[server]
runOnSave = true
port = 8501
baseUrlPath = ""
maxUploadSize = 200
enableCORS = false
enableXsrfProtection = true

[browser]
gatherUsageStats = false
serverAddress = "0.0.0.0"  # For Docker deployment

[theme]
primaryColor = "#1a1a1a"
backgroundColor = "#ffffff" 
secondaryBackgroundColor = "#f8f9fa"
textColor = "#1a1a1a"
font = "sans serif"
```

### Docker Compose (Multi-Container)

```yaml
version: '3.8'

services:
  neural-workbench:
    build: .
    ports:
      - "8501:8501"
    environment:
      - SUPABASE_URL=${SUPABASE_URL}
      - SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}
      - MAX_UPLOAD_SIZE_MB=500
    volumes:
      - ./data:/app/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8501/_stcore/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./certs:/etc/nginx/certs
    depends_on:
      - neural-workbench
    restart: unless-stopped

networks:
  default:
    driver: bridge
```

## 🔐 Security Configuration

### SSL/TLS Setup
```bash
# Generate self-signed certificate (development)
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes

# Or use Let's Encrypt (production)
certbot --nginx -d neural.tbwa.com
```

### Authentication Integration

For enterprise deployments with TBWA SSO:

1. **Update streamlit_app.py** to include authentication:
```python
import streamlit_authenticator as stauth

# Add to main() function
authenticator = stauth.Authenticate(
    credentials,
    'neural_workbench',
    'auth_signature_key',
    cookie_expiry_days=30
)

name, authentication_status, username = authenticator.login('Login', 'sidebar')

if authentication_status == False:
    st.error('Username/password is incorrect')
elif authentication_status == None:
    st.warning('Please enter your username and password')
elif authentication_status:
    # Main application logic here
    sidebar_navigation()
    # ... rest of app
```

2. **Configure LDAP/SSO** (optional):
```python
# Custom TBWA authentication adapter
from lib.auth import TBWAAuthAdapter

auth_adapter = TBWAAuthAdapter(domain='tbwa.com')
user_info = auth_adapter.authenticate(username, password)
```

## 📊 Monitoring and Observability

### Application Metrics
```python
# Add to streamlit_app.py for production monitoring
import streamlit as st
from datetime import datetime
import json

def log_user_action(action, details=None):
    """Log user actions for analytics"""
    log_entry = {
        'timestamp': datetime.now().isoformat(),
        'action': action,
        'session_id': st.session_state.get('session_id'),
        'details': details or {}
    }
    
    # Send to monitoring service (e.g., DataDog, CloudWatch)
    print(json.dumps(log_entry))  # Replace with actual logging

# Usage throughout the app
log_user_action('data_uploaded', {'rows': len(df), 'columns': len(df.columns)})
log_user_action('chart_created', {'type': chart_type})
log_user_action('dashboard_shared', {'method': 'public_link'})
```

### Health Check Endpoint
```python
# Add to streamlit_app.py
import streamlit as st

def health_check():
    """Health check endpoint for load balancers"""
    return {
        'status': 'healthy',
        'version': '2.0.0',
        'timestamp': datetime.now().isoformat(),
        'dependencies': {
            'database': db_client.is_connected() if 'db_client' in globals() else False
        }
    }

# Streamlit exposes /_stcore/health automatically
```

### Log Configuration
```python
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('/app/logs/neural-workbench.log')
    ]
)

logger = logging.getLogger('neural_workbench')
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Port Already in Use
```bash
# Find process using port 8501
lsof -i :8501

# Kill the process
kill -9 <PID>

# Or use different port
streamlit run streamlit_app.py --server.port=8502
```

#### 2. Memory Issues with Large Files
```python
# Add to streamlit_app.py
@st.cache_data
def load_large_dataset(file):
    """Cache large datasets to avoid memory issues"""
    return pd.read_csv(file)

# For very large files, use chunking
def process_large_file(file, chunk_size=10000):
    chunks = []
    for chunk in pd.read_csv(file, chunksize=chunk_size):
        chunks.append(process_chunk(chunk))
    return pd.concat(chunks, ignore_index=True)
```

#### 3. Database Connection Issues
```python
# Add connection retry logic
import time
from functools import wraps

def retry_db_operation(max_retries=3, delay=1):
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            for attempt in range(max_retries):
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    if attempt == max_retries - 1:
                        raise e
                    time.sleep(delay * (2 ** attempt))  # Exponential backoff
            return None
        return wrapper
    return decorator

@retry_db_operation()
def create_project_with_retry(project_data):
    return db_client.create_project(project_data)
```

#### 4. CSS/Styling Issues
```python
# Add custom CSS fixes
st.markdown("""
<style>
    /* Fix for mobile responsiveness */
    .stButton > button {
        width: 100%;
    }
    
    /* Fix for chart rendering */
    .plotly-graph-div {
        height: 400px !important;
    }
    
    /* Fix for file uploader on small screens */
    .stFileUploader {
        margin-bottom: 20px;
    }
</style>
""", unsafe_allow_html=True)
```

### Performance Optimization

#### 1. Caching Strategy
```python
# Cache expensive operations
@st.cache_data
def generate_data_profile(df):
    # Expensive profiling operation
    return profile

@st.cache_data
def create_chart(df, chart_type, x_col, y_col, color_col):
    # Cache chart creation
    return fig

# Cache database queries
@st.cache_data(ttl=3600)  # Cache for 1 hour
def fetch_projects(org_id):
    return db_client.get_projects(org_id)
```

#### 2. Lazy Loading
```python
# Load components only when needed
if st.session_state.current_page == 'build':
    # Only import heavy chart libraries when needed
    import plotly.express as px
    import plotly.graph_objects as go
```

### Monitoring Dashboard URLs
- **Streamlit Cloud**: https://share.streamlit.io/[username]/[repo]
- **Local**: http://localhost:8501
- **Docker**: http://localhost:8501 (or configured port)
- **Production**: https://neural.tbwa.com

## 📚 Additional Resources

- [Streamlit Documentation](https://docs.streamlit.io/)
- [Supabase Python Client](https://github.com/supabase/supabase-py)
- [Plotly Python Documentation](https://plotly.com/python/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)

## 🆘 Support

For deployment issues:
1. Check application logs first
2. Verify environment variables
3. Test database connectivity
4. Review resource usage (memory/CPU)
5. Create issue with deployment details

---

**🚀 Ready to deploy? Choose your option above and get Neural Workbench running in minutes!**