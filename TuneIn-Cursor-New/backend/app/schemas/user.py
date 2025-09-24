"""
User-related Pydantic schemas
"""

from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime


class UserBase(BaseModel):
    """Base user schema"""
    name: str
    email: EmailStr
    avatar_url: Optional[str] = None


class UserCreate(UserBase):
    """User creation schema"""
    password: str


class UserLogin(BaseModel):
    """User login schema"""
    email: EmailStr
    password: str


class UserProfile(UserBase):
    """User profile schema"""
    id: str
    created_at: datetime
    
    class Config:
        from_attributes = True


class UserUpdate(BaseModel):
    """User update schema"""
    name: Optional[str] = None
    avatar_url: Optional[str] = None


class UserSession(BaseModel):
    """User session schema"""
    id: str
    user_id: str
    session_name: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


class SessionCreate(BaseModel):
    """Session creation schema"""
    session_name: str


class SessionUpdate(BaseModel):
    """Session update schema"""
    session_name: Optional[str] = None
