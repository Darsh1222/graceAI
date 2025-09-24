"""
Analysis-related Pydantic schemas
"""

from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from datetime import datetime
from enum import Enum


class AnalysisStatus(str, Enum):
    """Analysis status enumeration"""
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"


class AnalysisResult(BaseModel):
    """Analysis result schema"""
    id: str
    user_id: str
    session_id: Optional[str] = None
    status: AnalysisStatus
    audio_file_path: Optional[str] = None
    sheet_music_path: Optional[str] = None
    midi_file_path: Optional[str] = None
    analysis_data: Optional[Dict[str, Any]] = None
    accuracy_score: Optional[float] = None
    feedback: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


class AnalysisRequest(BaseModel):
    """Analysis request schema"""
    session_id: Optional[str] = None
    audio_file: str  # Base64 encoded or file path
    sheet_music_file: Optional[str] = None  # Base64 encoded or file path


class AnalysisResponse(BaseModel):
    """Analysis response schema"""
    analysis_id: str
    status: AnalysisStatus
    message: str
    estimated_completion_time: Optional[int] = None  # seconds


class AnalysisFeedback(BaseModel):
    """Analysis feedback schema"""
    accuracy_score: float
    feedback: str
    suggestions: List[str]
    performance_metrics: Dict[str, Any]
