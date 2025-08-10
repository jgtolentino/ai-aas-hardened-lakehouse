# Superset Production Configuration
# Security-hardened settings for enterprise deployment

import os
from celery.schedules import crontab
from flask_appbuilder.security.manager import AUTH_OAUTH

# Security
SECRET_KEY = os.environ.get('SUPERSET_SECRET_KEY', 'CHANGE_ME_IN_PRODUCTION')
GUEST_TOKEN_JWT_SECRET = os.environ.get('GUEST_TOKEN_JWT_SECRET', 'CHANGE_ME_IN_PRODUCTION')
GUEST_TOKEN_JWT_ALGO = 'HS256'
GUEST_TOKEN_HEADER_NAME = 'X-GuestToken'
GUEST_TOKEN_JWT_EXP_SECONDS = 300  # 5 minutes

# CSRF Protection
WTF_CSRF_ENABLED = True
WTF_CSRF_EXEMPT_LIST = []
WTF_CSRF_TIME_LIMIT = 60 * 60 * 24  # 24 hours

# Session Security
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SECURE = True  # Requires HTTPS
SESSION_COOKIE_SAMESITE = 'Lax'
PERMANENT_SESSION_LIFETIME = 60 * 60 * 24  # 24 hours

# Content Security Policy
TALISMAN_ENABLED = True
TALISMAN_CONFIG = {
    'content_security_policy': {
        'default-src': ["'self'"],
        'img-src': ["'self'", 'data:', 'https:'],
        'script-src': ["'self'", "'unsafe-inline'", "'unsafe-eval'"],
        'style-src': ["'self'", "'unsafe-inline'"],
        'font-src': ["'self'", 'data:'],
        'connect-src': ["'self'", 'https://api.mapbox.com'],
        'object-src': "'none'",
        'frame-ancestors': [os.getenv("EMBED_ALLOWED_ORIGIN", "https://your-app.example.com")],  # Allow specific embedding
    },
    'force_https': True,
    'force_https_permanent': True,
    'strict_transport_security': True,
    'strict_transport_security_max_age': 31536000,  # 1 year
    'frame_options': 'DENY',
    'content_security_policy_nonce_in': ['script-src'],
}

# Authentication - OIDC/OAuth
AUTH_TYPE = AUTH_OAUTH
OAUTH_PROVIDERS = [
    {
        'name': 'google',
        'icon': 'fa-google',
        'token_key': 'access_token',
        'remote_app': {
            'client_id': os.environ.get('OIDC_CLIENT_ID'),
            'client_secret': os.environ.get('OIDC_CLIENT_SECRET'),
            'server_metadata_url': os.environ.get('OIDC_DISCOVERY_URL', 
                'https://accounts.google.com/.well-known/openid-configuration'),
            'client_kwargs': {
                'scope': 'openid email profile'
            },
        }
    }
]

# Role mapping from OAuth
AUTH_USER_REGISTRATION = True
AUTH_USER_REGISTRATION_ROLE = 'Gamma'  # Default role for new users
AUTH_ROLES_MAPPING = {
    "superset_admins": ["Admin"],
    "superset_users": ["Alpha"],
    "superset_viewers": ["Gamma"],
}

# Database
SQLALCHEMY_DATABASE_URI = os.environ.get('SUPERSET_META_URI',
    'postgresql+psycopg2://superset:superset@postgres-meta:5432/superset')

# Redis Cache
CACHE_CONFIG = {
    'CACHE_TYPE': 'RedisCache',
    'CACHE_DEFAULT_TIMEOUT': 60 * 60 * 24,  # 24 hours
    'CACHE_KEY_PREFIX': 'superset_cache_',
    'CACHE_REDIS_URL': os.environ.get('REDIS_URL', 'redis://redis:6379/0'),
}

DATA_CACHE_CONFIG = {
    'CACHE_TYPE': 'RedisCache',
    'CACHE_DEFAULT_TIMEOUT': 60 * 5,  # 5 minutes
    'CACHE_KEY_PREFIX': 'superset_data_',
    'CACHE_REDIS_URL': os.environ.get('REDIS_URL', 'redis://redis:6379/1'),
}

# Celery Configuration
class CeleryConfig:
    broker_url = os.environ.get('REDIS_URL', 'redis://redis:6379/2')
    result_backend = os.environ.get('REDIS_URL', 'redis://redis:6379/3')
    worker_prefetch_multiplier = 10
    task_acks_late = True
    task_annotations = {
        'sql_lab.get_sql_results': {
            'rate_limit': '100/s',
        },
    }
    beat_schedule = {
        'refresh-druid-metadata': {
            'task': 'refresh_druid_metadata',
            'schedule': crontab(hour='*/1'),
        },
        'cleanup-thumbnails': {
            'task': 'cleanup_thumbnails',
            'schedule': crontab(hour='1', minute='0'),
        },
    }

CELERY_CONFIG = CeleryConfig

# Feature Flags
FEATURE_FLAGS = {
    'EMBEDDED_SUPERSET': True,
    'ENABLE_TEMPLATE_PROCESSING': False,  # Security: disable Jinja in SQL
    'ENABLE_JAVASCRIPT_CONTROLS': False,  # Security: no custom JS
    'DASHBOARD_RBAC': True,
    'ROW_LEVEL_SECURITY': True,
    'ENABLE_ACCESS_REQUEST': False,
    'DISABLE_LEGACY_DATASOURCE_EDITOR': True,
    'VERSIONED_EXPORT': True,
    'DASHBOARD_NATIVE_FILTERS': True,
    'DASHBOARD_CROSS_FILTERS': True,
    'ALERT_REPORTS': True,
}

# Security - Additional Headers
ENABLE_PROXY_FIX = True
ENABLE_CORS = False  # Disable CORS, use proper domain
HTTP_HEADERS = {
    'X-Frame-Options': 'DENY',
    'X-Content-Type-Options': 'nosniff',
    'X-XSS-Protection': '1; mode=block',
    'Referrer-Policy': 'strict-origin-when-cross-origin',
    'Permissions-Policy': 'geolocation=(), microphone=(), camera=()',
}

# SQL Lab Security
SQL_MAX_ROW = 100000
SQL_QUERY_TIMEOUT = 60 * 5  # 5 minutes
SQLLAB_CTAS_NO_LIMIT = False

# Disable public dashboards
PUBLIC_ROLE_LIKE = ''  # No public role

# Logging
LOG_FORMAT = '%(asctime)s:%(levelname)s:%(name)s:%(message)s'
LOG_LEVEL = os.environ.get('LOG_LEVEL', 'INFO')

# Mapbox (if using maps)
MAPBOX_API_KEY = os.environ.get('MAPBOX_API_KEY', '')

# Thumbnail Configuration
THUMBNAIL_CACHE_CONFIG = {
    'CACHE_TYPE': 'RedisCache',
    'CACHE_DEFAULT_TIMEOUT': 60 * 60 * 24 * 7,  # 7 days
    'CACHE_KEY_PREFIX': 'superset_thumbnail_',
    'CACHE_REDIS_URL': os.environ.get('REDIS_URL', 'redis://redis:6379/4'),
}

THUMBNAIL_SELENIUM_USER = 'superset'
WEBDRIVER_BASEURL = 'http://superset:8088'
WEBDRIVER_BASEURL_USER_FRIENDLY = 'https://analytics.example.com'

# Email Configuration (for alerts)
SMTP_HOST = os.environ.get('SMTP_HOST', 'localhost')
SMTP_STARTTLS = True
SMTP_SSL = False
SMTP_USER = os.environ.get('SMTP_USER', '')
SMTP_PORT = int(os.environ.get('SMTP_PORT', '587'))
SMTP_PASSWORD = os.environ.get('SMTP_PASSWORD', '')
SMTP_MAIL_FROM = os.environ.get('SMTP_MAIL_FROM', 'superset@example.com')

# Alert & Report Configuration
ALERT_REPORTS_NOTIFICATION_DRY_RUN = False
ALERT_REPORTS_WORKING_TIME_OUT_KILL = True
ALERT_REPORTS_WORKING_TIME_OUT_LAG = 60 * 60 * 4  # 4 hours
ALERT_REPORTS_WORKING_SOFT_TIME_OUT_LAG = 60 * 60 * 1  # 1 hour

# Custom Security Manager (optional)
# from custom_security_manager import CustomSecurityManager
# CUSTOM_SECURITY_MANAGER = CustomSecurityManager