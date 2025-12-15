"""
Music analysis endpoints
"""

from fastapi import APIRouter, HTTPException, status, Depends, UploadFile, File, Form
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from typing import Optional, List
import logging
import tempfile
import os
import uuid
from datetime import datetime

from app.schemas.analysis import AnalysisRequest, AnalysisResponse, AnalysisResult, AnalysisStatus
from app.core.security import verify_token
from app.core.database import get_supabase_client
from app.services.analysis_engine import run_full_pipeline
from app.utils.file_handlers import save_uploaded_file, cleanup_temp_files

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


@router.post("/", response_model=AnalysisResponse)
async def analyze_music(
    audio_file: UploadFile = File(...),
    sheet_music_file: Optional[UploadFile] = File(None),
    session_id: Optional[str] = Form(None),
    current_user: dict = Depends(get_current_user)
):
    """Analyze music performance"""
    try:
        # Generate analysis ID
        analysis_id = str(uuid.uuid4())
        
        # Create temporary directory for processing
        temp_dir = tempfile.mkdtemp()
        
        try:
            # Save uploaded files
            audio_path = await save_uploaded_file(audio_file, temp_dir)
            sheet_music_path = None
            
            if sheet_music_file:
                sheet_music_path = await save_uploaded_file(sheet_music_file, temp_dir)
            
            # Create analysis record in database
            supabase = get_supabase_client()
            if supabase:
                analysis_data = {
                    "id": analysis_id,
                    "user_id": current_user["id"],
                    "session_id": session_id,
                    "status": AnalysisStatus.PROCESSING,
                    "audio_file_path": audio_path,
                    "sheet_music_path": sheet_music_path,
                    "created_at": datetime.utcnow().isoformat(),
                    "updated_at": datetime.utcnow().isoformat()
                }
                
                supabase.table("analyses").insert(analysis_data).execute()
            
            # Run analysis in background (in production, use Celery or similar)
            # For now, we'll run it synchronously
            try:
                logger.info(f"Starting analysis for user {current_user['id']}")
                
                # Run the full pipeline
                result = run_full_pipeline(audio_path, sheet_music_path)
                
                # Check if pipeline failed
                if not result:
                    logger.error("Music processing pipeline failed")
                    if supabase:
                        supabase.table("analyses").update({
                            "status": AnalysisStatus.FAILED,
                            "feedback": "Music processing pipeline failed - dependencies not available",
                            "updated_at": datetime.utcnow().isoformat()
                        }).eq("id", analysis_id).execute()
                    
                    raise HTTPException(
                        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                        detail="Music processing failed - dependencies not available"
                    )
                
                # Update analysis record with results
                if supabase:
                    update_data = {
                        "status": AnalysisStatus.COMPLETED,
                        "midi_file_path": result.get("midi_path"),
                        "analysis_data": result.get("analysis_data"),
                        "accuracy_score": result.get("accuracy_score"),
                        "feedback": result.get("feedback"),
                        "updated_at": datetime.utcnow().isoformat()
                    }
                    
                    supabase.table("analyses").update(update_data).eq("id", analysis_id).execute()
                
                return AnalysisResponse(
                    analysis_id=analysis_id,
                    status=AnalysisStatus.COMPLETED,
                    message="Analysis completed successfully"
                )
                
            except Exception as e:
                logger.error(f"Analysis failed: {e}")
                
                # Update analysis record with error
                if supabase:
                    update_data = {
                        "status": AnalysisStatus.FAILED,
                        "feedback": f"Analysis failed: {str(e)}",
                        "updated_at": datetime.utcnow().isoformat()
                    }
                    
                    supabase.table("analyses").update(update_data).eq("id", analysis_id).execute()
                
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail=f"Analysis failed: {str(e)}"
                )
                
        finally:
            # Cleanup temporary files
            cleanup_temp_files(temp_dir)
            
    except Exception as e:
        logger.error(f"Analysis endpoint error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )


@router.get("/{analysis_id}", response_model=AnalysisResult)
async def get_analysis_result(
    analysis_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Get analysis result"""
    try:
        supabase = get_supabase_client()
        if not supabase:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Database service unavailable"
            )
        
        # Get analysis from database
        response = supabase.table("analyses").select("*").eq("id", analysis_id).eq("user_id", current_user["id"]).execute()
        
        if response.data:
            return AnalysisResult(**response.data[0])
        else:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Analysis not found"
            )
            
    except Exception as e:
        logger.error(f"Get analysis error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )


@router.get("/", response_model=List[AnalysisResult])
async def get_user_analyses(
    session_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Get user's analyses"""
    try:
        supabase = get_supabase_client()
        if not supabase:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Database service unavailable"
            )
        
        # Build query
        query = supabase.table("analyses").select("*").eq("user_id", current_user["id"])
        
        if session_id:
            query = query.eq("session_id", session_id)
        
        response = query.order("created_at", desc=True).execute()
        
        return [AnalysisResult(**analysis) for analysis in response.data]
        
    except Exception as e:
        logger.error(f"Get analyses error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )

