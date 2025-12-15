#!/usr/bin/env python3
"""
Script to create a profile for the existing test user
"""

import os
import sys
from datetime import datetime

# Add the parent directory to the Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.core.database import get_supabase_client

def create_user_profile():
    """Create a profile for the test user"""
    supabase = get_supabase_client()
    if not supabase:
        print("❌ Could not connect to Supabase")
        return False
    
    # Test user ID from the JWT token
    user_id = "d3c1c4f0-b74a-4587-962c-4e2b35cab303"
    email = "test@example.com"
    
    try:
        # Check if profile already exists
        existing = supabase.table("profiles").select("*").eq("id", user_id).execute()
        
        if existing.data:
            print(f"✅ Profile already exists for user {user_id}")
            return True
        
        # Create profile
        profile_data = {
            "id": user_id,
            "name": "Test User",
            "email": email,
            "avatar_url": None,
            "created_at": datetime.utcnow().isoformat()
        }
        
        result = supabase.table("profiles").insert(profile_data).execute()
        
        if result.data:
            print(f"✅ Created profile for user {user_id}")
            print(f"Profile data: {result.data[0]}")
            return True
        else:
            print(f"❌ Failed to create profile: {result}")
            return False
            
    except Exception as e:
        print(f"❌ Error creating profile: {e}")
        return False

if __name__ == "__main__":
    create_user_profile()
