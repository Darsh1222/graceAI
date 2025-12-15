"""
Health check endpoints
"""

from fastapi import APIRouter, Depends
from datetime import datetime
import logging

from app.core.database import is_database_available
from app.core.config import settings
import subprocess
import os

router = APIRouter()
logger = logging.getLogger(__name__)


def test_musescore():
    """Test if MuseScore is available and working"""
    try:
        # Try with xvfb-run first (headless mode)
        result = subprocess.run(
            ["xvfb-run", "-a", "musescore3", "--version"], 
            capture_output=True, 
            text=True, 
            timeout=15
        )
        if result.returncode == 0 and "MuseScore" in result.stdout:
            return True
        
        # Fallback to direct execution
        result = subprocess.run(
            ["musescore3", "--version"], 
            capture_output=True, 
            text=True, 
            timeout=10
        )
        return result.returncode == 0 and "MuseScore" in result.stdout
    except (subprocess.TimeoutExpired, FileNotFoundError, Exception):
        return False


def test_audiveris():
    """Test if Audiveris is available and working"""
    try:
        # Check if JAR file exists
        import os
        jar_path = "/opt/audiveris/lib/app/audiveris.jar"
        if not os.path.exists(jar_path):
            return False
        
        # Try to run Audiveris with a simple command to see if it starts
        result = subprocess.run(
            ["java", "-cp", "/opt/audiveris/lib/app/*", "org.audiveris.omr.Main", "--help"], 
            capture_output=True, 
            text=True, 
            timeout=3
        )
        # If it shows CLI args, it's working (even if --help isn't supported)
        if "CLI args:" in result.stdout or "CLI args:" in result.stderr:
            return True
        
        # Try with xvfb-run as fallback
        result = subprocess.run(
            ["xvfb-run", "-a", "java", "-cp", "/opt/audiveris/lib/app/*", "org.audiveris.omr.Main", "--help"], 
            capture_output=True, 
            text=True, 
            timeout=3
        )
        if "CLI args:" in result.stdout or "CLI args:" in result.stderr:
            return True

        return False
    except (subprocess.TimeoutExpired, FileNotFoundError, Exception):
        return False


@router.get("/")
async def health_check():
    """Basic health check endpoint - fast response for load balancer"""
    return {
        "status": "healthy",
        "environment": settings.ENVIRONMENT,
        "timestamp": datetime.utcnow().isoformat(),
        "version": "1.0.0"
    }


@router.get("/detailed")
async def detailed_health_check():
    """Detailed health check with component status"""
    health_status = {
        "status": "healthy",
        "environment": settings.ENVIRONMENT,
        "timestamp": datetime.utcnow().isoformat(),
        "version": "1.0.0",
        "components": {
            "database": "healthy" if is_database_available() else "unhealthy",
            "file_system": "healthy",  # TODO: Add file system check
            "musescore": "healthy" if test_musescore() else "unhealthy",
            "audiveris": "healthy" if test_audiveris() else "unhealthy"
        }
    }
    
    # Check if critical components are unhealthy (Audiveris is optional)
    critical_components = ["database", "file_system", "musescore"]
    if any(health_status["components"][comp] == "unhealthy" for comp in critical_components):
        health_status["status"] = "degraded"
    
    return health_status


@router.get("/test-music-tools")
async def test_music_tools():
    """Test MuseScore and Audiveris availability"""
    musescore_status = test_musescore()
    audiveris_status = test_audiveris()
    
    return {
        "musescore": {
            "available": musescore_status,
            "status": "healthy" if musescore_status else "unhealthy"
        },
        "audiveris": {
            "available": audiveris_status,
            "status": "healthy" if audiveris_status else "unhealthy"
        },
        "overall": "healthy" if musescore_status else "unhealthy"
    }


@router.get("/debug-music-tools")
async def debug_music_tools():
    """Debug MuseScore and Audiveris with detailed output"""
    debug_info = {
        "musescore": {},
        "audiveris": {},
        "system": {}
    }
    
    # Test MuseScore with detailed output
    try:
        result = subprocess.run(
            ["xvfb-run", "-a", "musescore3", "--version"], 
            capture_output=True, 
            text=True, 
            timeout=15
        )
        debug_info["musescore"] = {
            "xvfb_run": {
                "returncode": result.returncode,
                "stdout": result.stdout,
                "stderr": result.stderr
            }
        }
    except Exception as e:
        debug_info["musescore"]["xvfb_run"] = {"error": str(e)}
    
    # Test MuseScore direct
    try:
        result = subprocess.run(
            ["musescore3", "--version"], 
            capture_output=True, 
            text=True, 
            timeout=10
        )
        debug_info["musescore"]["direct"] = {
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr
        }
    except Exception as e:
        debug_info["musescore"]["direct"] = {"error": str(e)}
    
    # Test Audiveris wrapper
    try:
        result = subprocess.run(
            ["/usr/local/bin/audiveris"], 
            capture_output=True, 
            text=True, 
            timeout=10
        )
        debug_info["audiveris"]["wrapper"] = {
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr
        }
    except Exception as e:
        debug_info["audiveris"]["wrapper"] = {"error": str(e)}

    # Test Audiveris direct JAR execution with classpath and headless display
    try:
        result = subprocess.run(
            ["xvfb-run", "-a", "java", "-cp", "/opt/audiveris/lib/app/*", "org.audiveris.omr.Main"], 
            capture_output=True, 
            text=True, 
            timeout=5
        )
        debug_info["audiveris"]["jar_direct"] = {
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr
        }
    except Exception as e:
        debug_info["audiveris"]["jar_direct"] = {"error": str(e)}

    # Test Audiveris original path (fallback)
    try:
        result = subprocess.run(
            ["/opt/audiveris/bin/audiveris", "--version"], 
            capture_output=True, 
            text=True, 
            timeout=15
        )
        debug_info["audiveris"]["original"] = {
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr
        }
    except Exception as e:
        debug_info["audiveris"]["original"] = {"error": str(e)}
    
    # System info
    debug_info["system"] = {
        "user": os.environ.get("USER", "Not set"),
        "home": os.environ.get("HOME", "Not set"),
        "display": os.environ.get("DISPLAY", "Not set"),
        "java_version": subprocess.run(["java", "-version"], capture_output=True, text=True).stderr.split('\n')[0] if subprocess.run(["which", "java"], capture_output=True).returncode == 0 else "Java not found"
    }
    
    return debug_info


@router.get("/debug-dependency-check")
async def debug_dependency_check():
    """Debug endpoint to test dependency check directly"""
    try:
        from heic_to_midi import check_dependencies
        result = check_dependencies()
        return {
            "dependency_check_result": result,
            "message": "Dependency check completed successfully" if result else "Dependency check failed"
        }
    except Exception as e:
        return {
            "dependency_check_result": False,
            "error": str(e),
            "message": "Dependency check failed with exception"
        }
