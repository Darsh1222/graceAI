"""
Security utilities for authentication and authorization
"""

import secrets
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from jose import jwt
from passlib.context import CryptContext
from fastapi import HTTPException, status
import logging

logger = logging.getLogger(__name__)

from app.core.config import settings

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def create_access_token(data: Dict[str, Any], expires_delta: Optional[timedelta] = None) -> str:
    """Create JWT access token"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm="HS256")
    return encoded_jwt


def verify_token(token: str) -> Dict[str, Any]:
    """Verify JWT token - now uses Supabase JWT verification"""
    try:
        from app.core.supabase_auth import verify_supabase_token
        return verify_supabase_token(token)
    except HTTPException:
        # Re-raise HTTP exceptions from Supabase verification
        raise
    except Exception as e:
        logger.error(f"Token verification failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token"
        )


def hash_password(password: str) -> str:
    """Hash password"""
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify password"""
    return pwd_context.verify(plain_password, hashed_password)


def generate_user_id() -> str:
    """Generate unique user ID"""
    return secrets.token_urlsafe(16)


def generate_session_id() -> str:
    """Generate unique session ID"""
    return secrets.token_urlsafe(32)
