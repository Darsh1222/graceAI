"""
GraceAI Backend - Local Development Version
Simplified version without heavy music analysis dependencies
"""

from fastapi import FastAPI, HTTPException, Depends, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import uvicorn
import os
import json
import random
import time
from datetime import datetime
from typing import Optional, Dict, Any
import requests
from pydantic import BaseModel

# Import only the essential modules
from app.core.config import settings
from app.core.supabase_auth import get_supabase_verifier

app = FastAPI(
    title="GraceAI Backend - Local",
    description="Local development version of GraceAI backend",
    version="1.0.0-local"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for local development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Pydantic models
class AnalysisRequest(BaseModel):
    audio_url: str
    sheet_music_url: str
    user_id: str

class AnalysisResult(BaseModel):
    accuracy: float
    correct_notes: int
    total_notes: int
    missed_notes: list
    tempo_feedback: str
    timing_feedback: str
    piece_title: str
    duration: float

class UserProfile(BaseModel):
    user_id: str
    name: str
    email: str
    created_at: str

# Health check endpoint
@app.get("/health/")
async def health_check():
    return {
        "status": "healthy",
        "environment": "local-development",
        "timestamp": datetime.now().isoformat(),
        "version": "1.0.0-local"
    }

# Authentication endpoint
@app.post("/auth/verify")
async def verify_token(token: str = Form(...)):
    """Verify Supabase token"""
    try:
        verifier = get_supabase_verifier()
        user_data = verifier.verify_token(token)
        return {"valid": True, "user": user_data}
    except Exception as e:
        raise HTTPException(status_code=401, detail="Invalid token")

# User profile endpoints
@app.get("/users/{user_id}")
async def get_user_profile(user_id: str):
    """Get user profile"""
    # For local development, return a mock profile
    return {
        "user_id": user_id,
        "name": "Local Test User",
        "email": "test@local.com",
        "created_at": datetime.now().isoformat()
    }

@app.post("/users")
async def create_user_profile(profile: UserProfile):
    """Create user profile"""
    # For local development, just return success
    return {"message": "User profile created", "user_id": profile.user_id}

# Analysis endpoint
@app.post("/analyze/")
async def analyze_performance(
    request: AnalysisRequest,
    authorization: str = None
):
    """Analyze musical performance"""
    
    # Verify token if provided
    if authorization:
        try:
            token = authorization.replace("Bearer ", "")
            verifier = get_supabase_verifier()
            user_data = verifier.verify_token(token)
            print(f"✅ Authenticated user: {user_data.get('sub', 'unknown')}")
        except Exception as e:
            print(f"❌ Authentication failed: {e}")
            raise HTTPException(status_code=401, detail="Invalid token")
    
    print(f"🎵 Analyzing performance for user: {request.user_id}")
    print(f"📁 Audio URL: {request.audio_url}")
    print(f"📄 Sheet Music URL: {request.sheet_music_url}")
    
    # Simulate analysis processing time
    await asyncio.sleep(2)
    
    # Generate realistic analysis results
    total_notes = random.randint(10, 20)
    correct_notes = random.randint(8, total_notes)
    accuracy = (correct_notes / total_notes) * 100
    missed_notes = [f"Note{chr(65 + i)}" for i in range(total_notes - correct_notes)]
    
    result = AnalysisResult(
        accuracy=round(accuracy, 1),
        correct_notes=correct_notes,
        total_notes=total_notes,
        missed_notes=missed_notes,
        tempo_feedback=random.choice([
            "Excellent tempo control!",
            "Good tempo matching with minor variations",
            "Tempo could be more consistent",
            "Great rhythmic accuracy!"
        ]),
        timing_feedback=random.choice([
            "Perfect timing alignment!",
            "Good timing with room for improvement",
            "Timing is mostly accurate",
            "Excellent rhythmic precision!"
        ]),
        piece_title=f"Practice Session {datetime.now().strftime('%H:%M')}",
        duration=120.0
    )
    
    print(f"✅ Analysis complete: {result.accuracy}% accuracy")
    return result

# Sessions endpoints
@app.get("/users/{user_id}/sessions")
async def get_user_sessions(user_id: str):
    """Get user sessions"""
    # For local development, return empty list
    return []

@app.post("/sessions")
async def save_session(session_data: dict):
    """Save session"""
    # For local development, just return success
    return {"message": "Session saved", "session_id": "local-session-123"}

if __name__ == "__main__":
    import asyncio
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=True)
