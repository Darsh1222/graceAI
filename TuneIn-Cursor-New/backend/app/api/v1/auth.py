"""
Authentication endpoints
"""

from fastapi import APIRouter, HTTPException, status, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from typing import Optional
import logging

from app.schemas.user import UserCreate, UserLogin, UserProfile
from app.services.supabase_service import SupabaseService
from app.core.security import create_access_token, verify_token
from app.core.database import get_supabase_client

router = APIRouter()
security = HTTPBearer()
logger = logging.getLogger(__name__)


@router.post("/signup", response_model=UserProfile)
async def signup(user_data: UserCreate):
    """User registration endpoint"""
    try:
        supabase = get_supabase_client()
        if not supabase:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Database service unavailable"
            )
        
        # Create user in Supabase
        response = supabase.auth.sign_up({
            "email": user_data.email,
            "password": user_data.password,
            "options": {
                "data": {
                    "name": user_data.name,
                    "avatar_url": user_data.avatar_url
                }
            }
        })
        
        if response.user:
            # Create user profile
            profile_data = {
                "id": response.user.id,
                "name": user_data.name,
                "email": user_data.email,
                "avatar_url": user_data.avatar_url,
                "created_at": response.user.created_at.isoformat() if response.user.created_at else None
            }
            
            # Insert into profiles table
            supabase.table("profiles").insert(profile_data).execute()
            
            return UserProfile(**profile_data)
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to create user"
            )
            
    except Exception as e:
        logger.error(f"Signup error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )


@router.post("/signin", response_model=dict)
async def signin(credentials: UserLogin):
    """User login endpoint"""
    try:
        supabase = get_supabase_client()
        if not supabase:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Database service unavailable"
            )
        
        # Authenticate with Supabase
        response = supabase.auth.sign_in_with_password({
            "email": credentials.email,
            "password": credentials.password
        })
        
        if response.user and response.session:
            # Create access token
            access_token = create_access_token(
                data={"sub": response.user.id, "email": response.user.email}
            )
            
            return {
                "access_token": access_token,
                "token_type": "bearer",
                "user": {
                    "id": response.user.id,
                    "email": response.user.email,
                    "name": response.user.user_metadata.get("name", ""),
                    "avatar_url": response.user.user_metadata.get("avatar_url", "")
                }
            }
        else:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid credentials"
            )
            
    except Exception as e:
        logger.error(f"Signin error: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials"
        )


@router.post("/google")
async def google_signin(id_token: str):
    """Google OAuth signin endpoint"""
    try:
        supabase = get_supabase_client()
        if not supabase:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Database service unavailable"
            )
        
        # Verify Google ID token with Supabase
        response = supabase.auth.sign_in_with_id_token({
            "provider": "google",
            "token": id_token
        })
        
        if response.user and response.session:
            # Create access token
            access_token = create_access_token(
                data={"sub": response.user.id, "email": response.user.email}
            )
            
            return {
                "access_token": access_token,
                "token_type": "bearer",
                "user": {
                    "id": response.user.id,
                    "email": response.user.email,
                    "name": response.user.user_metadata.get("name", ""),
                    "avatar_url": response.user.user_metadata.get("avatar_url", "")
                }
            }
        else:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Google authentication failed"
            )
            
    except Exception as e:
        logger.error(f"Google signin error: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Google authentication failed"
        )


@router.post("/logout")
async def logout(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """User logout endpoint"""
    try:
        # Verify token
        payload = verify_token(credentials.credentials)
        user_id = payload.get("sub")
        
        if user_id:
            supabase = get_supabase_client()
            if supabase:
                # Sign out from Supabase
                supabase.auth.sign_out()
            
            return {"message": "Successfully logged out"}
        else:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token"
            )
            
    except Exception as e:
        logger.error(f"Logout error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )
