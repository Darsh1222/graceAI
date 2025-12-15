#!/usr/bin/env python3
import jwt
import time

# Your Apple Developer details
TEAM_ID = "FNMT325P7M"
KEY_ID = "UV59ZZPNW5"
SERVICE_ID = "com.darshsenthil.graceai.signin"

# Your private key (the .p8 file content)
PRIVATE_KEY = """-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQgzS5Q23dWKyOTZxd4
MYJnLzaEB3HwzjjDqTdmyvRFxFegCgYIKoZIzj0DAQehRANCAASyUcVhfUNl1jKF
iTq1PLHwDWuKc3pZ2sKF9KMLJ0YgNfvdsAhw26R3pwgQ72/Iwashp2aBv1ZiuEoy
V+F9oBmc
-----END PRIVATE KEY-----"""

# Create the JWT payload
payload = {
    "iss": TEAM_ID,
    "iat": int(time.time()),
    "exp": int(time.time()) + 86400 * 180,  # 6 months from now
    "aud": "https://appleid.apple.com",
    "sub": SERVICE_ID
}

# Create the JWT header
header = {
    "alg": "RS256",
    "kid": KEY_ID
}

try:
    # Generate the JWT
    token = jwt.encode(payload, PRIVATE_KEY, algorithm="RS256", headers=header)
    print("Generated JWT Token:")
    print(token)
    print("\nCopy this token and paste it into Supabase as your Secret Key!")
except Exception as e:
    print(f"Error generating JWT: {e}")
