"""
Supabase JWT verification utilities
"""

import jwt
import requests
from typing import Dict, Any, Optional
from fastapi import HTTPException, status
import logging

logger = logging.getLogger(__name__)

class SupabaseJWTVerifier:
    """Verifies Supabase JWT tokens"""
    
    def __init__(self, supabase_url: str, supabase_anon_key: str):
        self.supabase_url = supabase_url
        self.supabase_anon_key = supabase_anon_key
        self._jwks_cache = {}
        self._jwks_url = f"{supabase_url}/auth/v1/jwks"
    
    def get_jwks(self) -> Dict[str, Any]:
        """Get JSON Web Key Set from Supabase"""
        try:
            response = requests.get(self._jwks_url, timeout=10)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            logger.error(f"Failed to fetch JWKS: {e}")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Unable to verify token"
            )
    
    def get_public_key(self, token: str) -> str:
        """Get the public key for verifying the token"""
        try:
            # Decode token header to get key ID
            unverified_header = jwt.get_unverified_header(token)
            kid = unverified_header.get("kid")
            
            if not kid:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid token format"
                )
            
            # Get JWKS
            jwks = self.get_jwks()
            
            # Find the key
            for key in jwks.get("keys", []):
                if key.get("kid") == kid:
                    # Convert JWK to PEM format
                    from cryptography.hazmat.primitives import serialization
                    from cryptography.hazmat.primitives.asymmetric import rsa
                    import base64
                    
                    n = base64.urlsafe_b64decode(key["n"] + "==")
                    e = base64.urlsafe_b64decode(key["e"] + "==")
                    
                    # Convert to integers
                    n_int = int.from_bytes(n, 'big')
                    e_int = int.from_bytes(e, 'big')
                    
                    # Create RSA public key
                    public_key = rsa.RSAPublicNumbers(e_int, n_int).public_key()
                    
                    # Serialize to PEM
                    pem = public_key.public_bytes(
                        encoding=serialization.Encoding.PEM,
                        format=serialization.PublicFormat.SubjectPublicKeyInfo
                    )
                    
                    return pem.decode()
            
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token key not found"
            )
            
        except Exception as e:
            logger.error(f"Failed to get public key: {e}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token"
            )
    
    def verify_token(self, token: str) -> Dict[str, Any]:
        """Verify Supabase JWT token using Supabase API"""
        try:
            # Use Supabase's built-in token verification
            headers = {
                "apikey": self.supabase_anon_key,
                "Authorization": f"Bearer {token}"
            }
            
            response = requests.get(
                f"{self.supabase_url}/auth/v1/user",
                headers=headers,
                timeout=10
            )
            
            if response.status_code == 200:
                user_data = response.json()
                # Extract user info from the response
                return {
                    "sub": user_data.get("id"),
                    "email": user_data.get("email"),
                    "aud": "authenticated",
                    "role": "authenticated"
                }
            else:
                logger.error(f"Supabase token verification failed: {response.status_code} - {response.text}")
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid token"
                )
                
        except requests.RequestException as e:
            logger.error(f"Failed to verify token with Supabase: {e}")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Unable to verify token"
            )
        except Exception as e:
            logger.error(f"Token verification failed: {e}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token verification failed"
            )

# Global verifier instance
_verifier: Optional[SupabaseJWTVerifier] = None

def get_supabase_verifier() -> SupabaseJWTVerifier:
    """Get the global Supabase JWT verifier"""
    global _verifier
    if _verifier is None:
        from app.core.config import settings
        if not settings.SUPABASE_URL or not settings.SUPABASE_KEY:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Supabase not configured"
            )
        _verifier = SupabaseJWTVerifier(settings.SUPABASE_URL, settings.SUPABASE_KEY)
    return _verifier

def verify_supabase_token(token: str) -> Dict[str, Any]:
    """Verify a Supabase JWT token"""
    verifier = get_supabase_verifier()
    return verifier.verify_token(token)
