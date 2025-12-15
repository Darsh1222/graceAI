"""
Audio processing utilities
"""

import os
import ffmpeg
import soundfile as sf
import numpy as np
import logging
from typing import Tuple

logger = logging.getLogger(__name__)


def convert_audio_format(
    input_path: str, 
    output_path: str, 
    sample_rate: int = 44100,
    channels: int = 1
) -> str:
    """
    Convert audio file to WAV format
    
    Args:
        input_path: Path to input audio file
        output_path: Path to output WAV file
        sample_rate: Target sample rate
        channels: Number of channels (1 for mono, 2 for stereo)
        
    Returns:
        Path to converted audio file
    """
    try:
        # Ensure output directory exists
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
        # Convert using ffmpeg
        (
            ffmpeg.input(input_path)
            .output(output_path, ar=sample_rate, ac=channels, format='wav')
            .overwrite_output()
            .run(quiet=True)
        )
        
        # Verify conversion
        data, sr = sf.read(output_path)
        if sr != sample_rate:
            raise ValueError(f"Sample rate is {sr}, expected {sample_rate}")
        
        if channels == 1 and len(data.shape) > 1:
            raise ValueError("Audio is not mono after conversion.")
        
        logger.info(f"Audio converted successfully: {output_path}")
        return output_path
        
    except Exception as e:
        logger.error(f"Audio conversion failed: {e}")
        raise


def validate_audio_file(file_path: str) -> bool:
    """
    Validate audio file
    
    Args:
        file_path: Path to audio file
        
    Returns:
        True if file is valid audio
    """
    try:
        # Try to read the file
        data, sample_rate = sf.read(file_path)
        
        # Check if we got valid data
        if len(data) == 0:
            return False
        
        # Check sample rate
        if sample_rate < 8000 or sample_rate > 192000:
            return False
        
        return True
        
    except Exception as e:
        logger.error(f"Audio validation failed: {e}")
        return False


def get_audio_info(file_path: str) -> dict:
    """
    Get audio file information
    
    Args:
        file_path: Path to audio file
        
    Returns:
        Dictionary with audio information
    """
    try:
        data, sample_rate = sf.read(file_path)
        
        return {
            "sample_rate": sample_rate,
            "channels": 1 if len(data.shape) == 1 else data.shape[1],
            "duration": len(data) / sample_rate,
            "samples": len(data),
            "format": "mono" if len(data.shape) == 1 else "stereo"
        }
        
    except Exception as e:
        logger.error(f"Error getting audio info: {e}")
        return {}


def normalize_audio(data: np.ndarray) -> np.ndarray:
    """
    Normalize audio data
    
    Args:
        data: Audio data array
        
    Returns:
        Normalized audio data
    """
    try:
        # Avoid division by zero
        max_val = np.max(np.abs(data))
        if max_val == 0:
            return data
        
        # Normalize to [-1, 1]
        return data / max_val
        
    except Exception as e:
        logger.error(f"Audio normalization failed: {e}")
        return data
