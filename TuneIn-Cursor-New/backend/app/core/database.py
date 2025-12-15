"""
Database configuration and connection management
"""

import os
from typing import Optional
from supabase import create_client, Client
import logging

logger = logging.getLogger(__name__)

# Global Supabase client
supabase_client: Optional[Client] = None


async def init_db():
    """Initialize database connection"""
    global supabase_client
    
    from app.core.config import settings
    
    if settings.SUPABASE_URL and settings.SUPABASE_KEY:
        try:
            supabase_client = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)
            logger.info("✅ Supabase client initialized successfully")
        except Exception as e:
            logger.error(f"❌ Failed to initialize Supabase client: {e}")
            supabase_client = None
    else:
        logger.warning("⚠️ Supabase credentials not found - running in local mode")
        supabase_client = None


def get_supabase_client() -> Optional[Client]:
    """Get Supabase client instance"""
    return supabase_client


def is_database_available() -> bool:
    """Check if database is available"""
    return supabase_client is not None
