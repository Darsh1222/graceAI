"""
User management endpoints
"""

from fastapi import APIRouter, HTTPException, status, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from typing import List
import logging

from app.schemas.user import UserProfile, UserUpdate, UserSession, SessionCreate, SessionUpdate
from app.core.security import verify_token
from app.core.database import get_supabase_client

router = APIRouter()
security = HTTPBearer()
logger = logging.getLogger(__name__)


async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> dict:
    """Get current authenticated user"""
    payload = verify_token(credentials.credentials)
    user_id = payload.get("sub")
    
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token"
        )
    
    return {"id": user_id, "email": payload.get("email")}


@router.get("/profile", response_model=UserProfile)
async def get_user_profile(current_user: dict = Depends(get_current_user)):
    """Get user profile"""
    try:
        supabase = get_supabase_client()
        if not supabase:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Database service unavailable"
            )
        
        # Get user profile from Supabase
        response = supabase.table("profiles").select("*").eq("id", current_user["id"]).execute()
        
        if response.data:
            return UserProfile(**response.data[0])
        else:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User profile not found"
            )
            
    except Exception as e:
        logger.error(f"Get profile error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )


@router.put("/profile", response_model=UserProfile)
async def update_user_profile(
    user_update: UserUpdate,
    current_user: dict = Depends(get_current_user)
):
    """Update user profile"""
    try:
        supabase = get_supabase_client()
        if not supabase:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Database service unavailable"
            )
        
        # Update user profile in Supabase
        update_data = {k: v for k, v in user_update.dict().items() if v is not None}
        
        if update_data:
            response = supabase.table("profiles").update(update_data).eq("id", current_user["id"]).execute()
            
            if response.data:
                return UserProfile(**response.data[0])
            else:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="User profile not found"
                )
        else:
            # No updates provided, return current profile
            return await get_user_profile(current_user)
            
    except Exception as e:
        logger.error(f"Update profile error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )


@router.get("/sessions", response_model=List[UserSession])
async def get_user_sessions(current_user: dict = Depends(get_current_user)):
    """Get user sessions"""
    try:
        supabase = get_supabase_client()
        if not supabase:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Database service unavailable"
            )
        
        # Get user sessions from Supabase
        response = supabase.table("sessions").select("*").eq("user_id", current_user["id"]).order("created_at", desc=True).execute()
        
        return [UserSession(**session) for session in response.data]
        
    except Exception as e:
        logger.error(f"Get sessions error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )


@router.post("/sessions", response_model=UserSession)
async def create_session(
    session_data: SessionCreate,
    current_user: dict = Depends(get_current_user)
):
    """Create new session"""
    try:
        supabase = get_supabase_client()
        if not supabase:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Database service unavailable"
            )
        
        # Create session in Supabase
        session_dict = {
            "user_id": current_user["id"],
            "session_name": session_data.session_name
        }
        
        response = supabase.table("sessions").insert(session_dict).execute()
        
        if response.data:
            return UserSession(**response.data[0])
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to create session"
            )
            
    except Exception as e:
        logger.error(f"Create session error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )


@router.put("/sessions/{session_id}", response_model=UserSession)
async def update_session(
    session_id: str,
    session_update: SessionUpdate,
    current_user: dict = Depends(get_current_user)
):
    """Update session"""
    try:
        supabase = get_supabase_client()
        if not supabase:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Database service unavailable"
            )
        
        # Update session in Supabase
        update_data = {k: v for k, v in session_update.dict().items() if v is not None}
        
        if update_data:
            response = supabase.table("sessions").update(update_data).eq("id", session_id).eq("user_id", current_user["id"]).execute()
            
            if response.data:
                return UserSession(**response.data[0])
            else:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Session not found"
                )
        else:
            # No updates provided, return current session
            response = supabase.table("sessions").select("*").eq("id", session_id).eq("user_id", current_user["id"]).execute()
            if response.data:
                return UserSession(**response.data[0])
            else:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Session not found"
                )
            
    except Exception as e:
        logger.error(f"Update session error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )


@router.delete("/sessions/{session_id}")
async def delete_session(
    session_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Delete session"""
    try:
        supabase = get_supabase_client()
        if not supabase:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Database service unavailable"
            )
        
        # Delete session from Supabase
        response = supabase.table("sessions").delete().eq("id", session_id).eq("user_id", current_user["id"]).execute()
        
        if response.data:
            return {"message": "Session deleted successfully"}
        else:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Session not found"
            )
            
    except Exception as e:
        logger.error(f"Delete session error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )

