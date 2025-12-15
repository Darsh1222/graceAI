"""
Application configuration management
Environment-based configuration with validation
"""

import os
from typing import List, Optional
from pydantic import BaseModel, Field
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings"""
    
    # Environment
    ENVIRONMENT: str = "development"
    DEBUG: bool = False
    
    # API Configuration
    API_V1_STR: str = "/api/v1"
    PROJECT_NAME: str = "TuneIn Cursor API"
    
    # Server Configuration
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    
    # CORS Configuration
    ALLOWED_ORIGINS: str = "*"
    ALLOWED_HOSTS: str = "*"
    
    # File Upload Configuration
    UPLOAD_FOLDER: str = "uploads"
    MAX_CONTENT_LENGTH: int = 50 * 1024 * 1024  # 50MB
    ALLOWED_EXTENSIONS: str = "m4a,wav,mp3,aac,pdf,jpeg,jpg,png,heic"
    
    # Supabase Configuration
    SUPABASE_URL: Optional[str] = None
    SUPABASE_KEY: Optional[str] = None
    
    # Security
    SECRET_KEY: str = "your-secret-key-here"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    
    # Database
    DATABASE_URL: Optional[str] = None
    
    # AWS Configuration
    AWS_REGION: str = "us-east-1"
    AWS_ACCESS_KEY_ID: Optional[str] = None
    AWS_SECRET_ACCESS_KEY: Optional[str] = None
    
    # Music Processing
    MUSESCORE_PATH: str = "/usr/bin/musescore3"
    AUDIVERIS_PATH: str = "/usr/local/bin/audiveris.jar"
    
    @property
    def allowed_origins_list(self) -> List[str]:
        """Convert ALLOWED_ORIGINS string to list"""
        if self.ALLOWED_ORIGINS == "*":
            return ["*"]
        return [i.strip() for i in self.ALLOWED_ORIGINS.split(",")]
    
    @property
    def allowed_hosts_list(self) -> List[str]:
        """Convert ALLOWED_HOSTS string to list"""
        if self.ALLOWED_HOSTS == "*":
            return ["*"]
        return [i.strip() for i in self.ALLOWED_HOSTS.split(",")]
    
    @property
    def allowed_extensions_list(self) -> List[str]:
        """Convert ALLOWED_EXTENSIONS string to list"""
        return [i.strip() for i in self.ALLOWED_EXTENSIONS.split(",")]
    
    class Config:
        env_file = "env.aws"
        case_sensitive = True
        extra = "ignore"  # Ignore extra fields in env file


# Create settings instance
settings = Settings()
