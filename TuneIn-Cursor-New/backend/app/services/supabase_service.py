"""
Supabase service for TuneIn Cursor
Handles database operations and file storage
"""

import os
import tempfile
import shutil
import json
import uuid
from datetime import datetime
from typing import Optional, Dict, Any, List
import logging

from supabase import create_client, Client
from app.core.config import settings

logger = logging.getLogger(__name__)


class SupabaseService:
    """Supabase service for database operations"""
    
    def __init__(self):
        self.client: Optional[Client] = None
        self._initialize_client()
    
    def _initialize_client(self):
        """Initialize Supabase client"""
        try:
            if settings.SUPABASE_URL and settings.SUPABASE_KEY:
                self.client = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)
                logger.info("✅ Supabase client initialized successfully")
            else:
                logger.warning("⚠️ Supabase credentials not found - running in local mode")
                self.client = None
        except Exception as e:
            logger.error(f"❌ Failed to initialize Supabase client: {e}")
            self.client = None
    
    def is_available(self) -> bool:
        """Check if Supabase service is available"""
        return self.client is not None
    
    # User Management
    async def create_user_profile(self, user_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Create user profile in Supabase"""
        if not self.client:
            return None
        
        try:
            response = self.client.table("profiles").insert(user_data).execute()
            if response.data:
                return response.data[0]
            return None
        except Exception as e:
            logger.error(f"Error creating user profile: {e}")
            return None
    
    async def get_user_profile(self, user_id: str) -> Optional[Dict[str, Any]]:
        """Get user profile from Supabase"""
        if not self.client:
            return None
        
        try:
            response = self.client.table("profiles").select("*").eq("id", user_id).execute()
            if response.data:
                return response.data[0]
            return None
        except Exception as e:
            logger.error(f"Error getting user profile: {e}")
            return None
    
    async def update_user_profile(self, user_id: str, update_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Update user profile in Supabase"""
        if not self.client:
            return None
        
        try:
            response = self.client.table("profiles").update(update_data).eq("id", user_id).execute()
            if response.data:
                return response.data[0]
            return None
        except Exception as e:
            logger.error(f"Error updating user profile: {e}")
            return None
    
    # Session Management
    async def create_session(self, session_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Create session in Supabase"""
        if not self.client:
            return None
        
        try:
            response = self.client.table("sessions").insert(session_data).execute()
            if response.data:
                return response.data[0]
            return None
        except Exception as e:
            logger.error(f"Error creating session: {e}")
            return None
    
    async def get_user_sessions(self, user_id: str) -> List[Dict[str, Any]]:
        """Get user sessions from Supabase"""
        if not self.client:
            return []
        
        try:
            response = self.client.table("sessions").select("*").eq("user_id", user_id).order("created_at", desc=True).execute()
            return response.data or []
        except Exception as e:
            logger.error(f"Error getting user sessions: {e}")
            return []
    
    async def update_session(self, session_id: str, user_id: str, update_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Update session in Supabase"""
        if not self.client:
            return None
        
        try:
            response = self.client.table("sessions").update(update_data).eq("id", session_id).eq("user_id", user_id).execute()
            if response.data:
                return response.data[0]
            return None
        except Exception as e:
            logger.error(f"Error updating session: {e}")
            return None
    
    async def delete_session(self, session_id: str, user_id: str) -> bool:
        """Delete session from Supabase"""
        if not self.client:
            return False
        
        try:
            response = self.client.table("sessions").delete().eq("id", session_id).eq("user_id", user_id).execute()
            return bool(response.data)
        except Exception as e:
            logger.error(f"Error deleting session: {e}")
            return False
    
    # Analysis Management
    async def create_analysis(self, analysis_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Create analysis record in Supabase"""
        if not self.client:
            return None
        
        try:
            response = self.client.table("analyses").insert(analysis_data).execute()
            if response.data:
                return response.data[0]
            return None
        except Exception as e:
            logger.error(f"Error creating analysis: {e}")
            return None
    
    async def get_analysis(self, analysis_id: str, user_id: str) -> Optional[Dict[str, Any]]:
        """Get analysis from Supabase"""
        if not self.client:
            return None
        
        try:
            response = self.client.table("analyses").select("*").eq("id", analysis_id).eq("user_id", user_id).execute()
            if response.data:
                return response.data[0]
            return None
        except Exception as e:
            logger.error(f"Error getting analysis: {e}")
            return None
    
    async def update_analysis(self, analysis_id: str, update_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Update analysis in Supabase"""
        if not self.client:
            return None
        
        try:
            response = self.client.table("analyses").update(update_data).eq("id", analysis_id).execute()
            if response.data:
                return response.data[0]
            return None
        except Exception as e:
            logger.error(f"Error updating analysis: {e}")
            return None
    
    async def get_user_analyses(self, user_id: str, session_id: Optional[str] = None) -> List[Dict[str, Any]]:
        """Get user analyses from Supabase"""
        if not self.client:
            return []
        
        try:
            query = self.client.table("analyses").select("*").eq("user_id", user_id)
            
            if session_id:
                query = query.eq("session_id", session_id)
            
            response = query.order("created_at", desc=True).execute()
            return response.data or []
        except Exception as e:
            logger.error(f"Error getting user analyses: {e}")
            return []
    
    # File Storage
    async def upload_file(self, file_path: str, bucket: str, file_name: str) -> Optional[str]:
        """Upload file to Supabase storage"""
        if not self.client:
            return None
        
        try:
            with open(file_path, 'rb') as f:
                response = self.client.storage.from_(bucket).upload(file_name, f)
            
            if response:
                # Get public URL
                public_url = self.client.storage.from_(bucket).get_public_url(file_name)
                return public_url
            return None
        except Exception as e:
            logger.error(f"Error uploading file: {e}")
            return None
    
    async def delete_file(self, bucket: str, file_name: str) -> bool:
        """Delete file from Supabase storage"""
        if not self.client:
            return False
        
        try:
            response = self.client.storage.from_(bucket).remove([file_name])
            return True
        except Exception as e:
            logger.error(f"Error deleting file: {e}")
            return False


# Global instance
supabase_service = SupabaseService()