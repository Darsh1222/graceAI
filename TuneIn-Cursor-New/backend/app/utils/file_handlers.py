"""
File handling utilities
"""

import os
import shutil
import tempfile
from typing import Optional
from fastapi import UploadFile
import logging

logger = logging.getLogger(__name__)


async def save_uploaded_file(upload_file: UploadFile, destination_dir: str) -> str:
    """
    Save uploaded file to destination directory
    
    Args:
        upload_file: FastAPI UploadFile object
        destination_dir: Directory to save the file
        
    Returns:
        Path to saved file
    """
    try:
        # Ensure destination directory exists
        os.makedirs(destination_dir, exist_ok=True)
        
        # Generate safe filename
        filename = upload_file.filename
        if not filename:
            filename = "uploaded_file"
        
        # Create full path
        file_path = os.path.join(destination_dir, filename)
        
        # Save file
        with open(file_path, "wb") as buffer:
            content = await upload_file.read()
            buffer.write(content)
        
        logger.info(f"File saved: {file_path}")
        return file_path
        
    except Exception as e:
        logger.error(f"Error saving file: {e}")
        raise


def cleanup_temp_files(temp_dir: str):
    """
    Clean up temporary files and directory
    
    Args:
        temp_dir: Directory to clean up
    """
    try:
        if os.path.exists(temp_dir):
            shutil.rmtree(temp_dir)
            logger.info(f"Cleaned up temporary directory: {temp_dir}")
    except Exception as e:
        logger.error(f"Error cleaning up temp files: {e}")


def get_file_extension(filename: str) -> str:
    """
    Get file extension from filename
    
    Args:
        filename: Name of the file
        
    Returns:
        File extension (lowercase)
    """
    return os.path.splitext(filename)[1].lower().lstrip('.')


def is_allowed_file(filename: str, allowed_extensions: list) -> bool:
    """
    Check if file extension is allowed
    
    Args:
        filename: Name of the file
        allowed_extensions: List of allowed extensions
        
    Returns:
        True if file extension is allowed
    """
    if not filename:
        return False
    
    extension = get_file_extension(filename)
    return extension in allowed_extensions


def get_file_size(file_path: str) -> int:
    """
    Get file size in bytes
    
    Args:
        file_path: Path to the file
        
    Returns:
        File size in bytes
    """
    try:
        return os.path.getsize(file_path)
    except OSError:
        return 0
