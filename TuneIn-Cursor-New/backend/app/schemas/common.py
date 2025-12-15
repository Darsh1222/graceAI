"""
Common Pydantic schemas
"""

from pydantic import BaseModel
from typing import Optional, Dict, Any
from datetime import datetime


class ErrorResponse(BaseModel):
    """Error response schema"""
    error: str
    detail: Optional[str] = None
    timestamp: datetime = datetime.utcnow()


class SuccessResponse(BaseModel):
    """Success response schema"""
    message: str
    data: Optional[Dict[str, Any]] = None
    timestamp: datetime = datetime.utcnow()


class PaginationParams(BaseModel):
    """Pagination parameters"""
    page: int = 1
    limit: int = 10
    
    @property
    def offset(self) -> int:
        return (self.page - 1) * self.limit


class PaginatedResponse(BaseModel):
    """Paginated response schema"""
    items: list
    total: int
    page: int
    limit: int
    pages: int
    
    @classmethod
    def create(cls, items: list, total: int, page: int, limit: int):
        pages = (total + limit - 1) // limit
        return cls(
            items=items,
            total=total,
            page=page,
            limit=limit,
            pages=pages
        )
