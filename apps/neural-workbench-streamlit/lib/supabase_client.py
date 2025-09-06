"""
Supabase client configuration for Neural Workbench
Handles database connection and neural schema operations
"""

import os
from typing import Optional, Dict, Any, List
from supabase import create_client, Client
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class NeuralWorkbenchDB:
    """Database client for Neural Workbench operations"""
    
    def __init__(self):
        self.url = os.getenv('SUPABASE_URL')
        self.key = os.getenv('SUPABASE_ANON_KEY')
        self.service_role_key = os.getenv('SUPABASE_SERVICE_ROLE_KEY')
        self.client: Optional[Client] = None
        self.admin_client: Optional[Client] = None
        
    def connect(self) -> bool:
        """Initialize Supabase client connection"""
        try:
            if self.url and self.key:
                # Regular client for user operations
                self.client = create_client(self.url, self.key)
                
                # Admin client for service operations
                if self.service_role_key:
                    self.admin_client = create_client(self.url, self.service_role_key)
                
                return True
        except Exception as e:
            print(f"Failed to connect to Supabase: {e}")
            return False
    
    def is_connected(self) -> bool:
        """Check if database is connected"""
        return self.client is not None
    
    # Project Operations
    def create_project(self, project_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Create a new neural project"""
        if not self.client:
            return None
            
        try:
            response = self.client.table('neural.projects').insert(project_data).execute()
            return response.data[0] if response.data else None
        except Exception as e:
            print(f"Error creating project: {e}")
            return None
    
    def get_projects(self, org_id: str) -> List[Dict[str, Any]]:
        """Get all projects for an organization"""
        if not self.client:
            return []
            
        try:
            response = self.client.table('neural.projects')\
                .select('*')\
                .eq('org_id', org_id)\
                .order('updated_at', desc=True)\
                .execute()
            return response.data or []
        except Exception as e:
            print(f"Error fetching projects: {e}")
            return []
    
    def update_project(self, project_id: str, updates: Dict[str, Any]) -> bool:
        """Update a project"""
        if not self.client:
            return False
            
        try:
            response = self.client.table('neural.projects')\
                .update(updates)\
                .eq('id', project_id)\
                .execute()
            return len(response.data) > 0
        except Exception as e:
            print(f"Error updating project: {e}")
            return False
    
    # Dataset Operations
    def create_dataset(self, dataset_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Create a new dataset entry"""
        if not self.client:
            return None
            
        try:
            response = self.client.table('neural.datasets').insert(dataset_data).execute()
            return response.data[0] if response.data else None
        except Exception as e:
            print(f"Error creating dataset: {e}")
            return None
    
    def get_datasets(self, project_id: str) -> List[Dict[str, Any]]:
        """Get all datasets for a project"""
        if not self.client:
            return []
            
        try:
            response = self.client.table('neural.datasets')\
                .select('*')\
                .eq('project_id', project_id)\
                .order('created_at', desc=True)\
                .execute()
            return response.data or []
        except Exception as e:
            print(f"Error fetching datasets: {e}")
            return []
    
    # Dashboard Operations
    def create_dashboard(self, dashboard_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Create a new dashboard"""
        if not self.client:
            return None
            
        try:
            response = self.client.table('neural.dashboards').insert(dashboard_data).execute()
            return response.data[0] if response.data else None
        except Exception as e:
            print(f"Error creating dashboard: {e}")
            return None
    
    def get_dashboards(self, project_id: str) -> List[Dict[str, Any]]:
        """Get all dashboards for a project"""
        if not self.client:
            return []
            
        try:
            response = self.client.table('neural.dashboards')\
                .select('*')\
                .eq('project_id', project_id)\
                .order('updated_at', desc=True)\
                .execute()
            return response.data or []
        except Exception as e:
            print(f"Error fetching dashboards: {e}")
            return []
    
    def update_dashboard(self, dashboard_id: str, updates: Dict[str, Any]) -> bool:
        """Update a dashboard"""
        if not self.client:
            return False
            
        try:
            response = self.client.table('neural.dashboards')\
                .update(updates)\
                .eq('id', dashboard_id)\
                .execute()
            return len(response.data) > 0
        except Exception as e:
            print(f"Error updating dashboard: {e}")
            return False
    
    # Share Operations
    def create_share(self, share_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Create a new share link"""
        if not self.client:
            return None
            
        try:
            response = self.client.table('neural.shares').insert(share_data).execute()
            return response.data[0] if response.data else None
        except Exception as e:
            print(f"Error creating share: {e}")
            return None
    
    def get_share_by_token(self, token: str) -> Optional[Dict[str, Any]]:
        """Get share information by access token"""
        if not self.client:
            return None
            
        try:
            response = self.client.table('neural.shares')\
                .select('*')\
                .eq('access_token', token)\
                .single()\
                .execute()
            return response.data
        except Exception as e:
            print(f"Error fetching share: {e}")
            return None
    
    # Utility Operations
    def check_schema_exists(self) -> bool:
        """Check if neural schema exists in database"""
        if not self.admin_client:
            return False
            
        try:
            # Use admin client to check schema
            response = self.admin_client.rpc('exec_sql', {
                'sql_string': "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'neural'"
            }).execute()
            return len(response.data) > 0
        except Exception as e:
            print(f"Error checking schema: {e}")
            return False
    
    def track_project_access(self, project_id: str) -> bool:
        """Track project access using database function"""
        if not self.client:
            return False
            
        try:
            self.client.rpc('track_project_access', {'project_id': project_id}).execute()
            return True
        except Exception as e:
            print(f"Error tracking access: {e}")
            return False

# Global database client instance
db_client = NeuralWorkbenchDB()

def get_db_client() -> NeuralWorkbenchDB:
    """Get the global database client instance"""
    if not db_client.is_connected():
        db_client.connect()
    return db_client

def ensure_connection() -> bool:
    """Ensure database connection is established"""
    client = get_db_client()
    return client.is_connected()