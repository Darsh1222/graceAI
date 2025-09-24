#!/usr/bin/env python3
"""
API Client for testing the TuneIn backend server
"""

import requests
import json
import os

class TuneInAPIClient:
    def __init__(self, base_url="http://tunein-backend-alb-1055077303.us-east-1.elb.amazonaws.com:8000"):
        self.base_url = base_url
        
    def create_user(self, name, email):
        """Create a new user"""
        url = f"{self.base_url}/users"
        data = {
            "name": name,
            "email": email
        }
        response = requests.post(url, json=data)
        return response.json(), response.status_code
    
    def get_user(self, user_id):
        """Get user profile"""
        url = f"{self.base_url}/users/{user_id}"
        response = requests.get(url)
        return response.json(), response.status_code
    
    def get_user_sessions(self, user_id):
        """Get all practice sessions for a user"""
        url = f"{self.base_url}/users/{user_id}/sessions"
        response = requests.get(url)
        return response.json(), response.status_code
    
    def analyze_practice(self, user_id, audio_file_path, sheet_music_path, piece_title=None, duration=0.0):
        """Analyze a practice session"""
        url = f"{self.base_url}/analyze"
        
        with open(audio_file_path, 'rb') as audio_file, open(sheet_music_path, 'rb') as sheet_file:
            files = {
                'audio_file': audio_file,
                'sheet_music': sheet_file
            }
            data = {
                'user_id': user_id,
                'piece_title': piece_title or '',
                'duration': str(duration)
            }
            response = requests.post(url, files=files, data=data)
        
        return response.json(), response.status_code
    
    def health_check(self):
        """Check server health"""
        url = f"{self.base_url}/health"
        response = requests.get(url)
        return response.json(), response.status_code

def main():
    """Test the API endpoints"""
    client = TuneInAPIClient()
    
    print("Testing TuneIn API...")
    
    # Health check
    print("\n1. Health check:")
    health, status = client.health_check()
    print(f"Status: {status}")
    print(f"Response: {health}")
    
    # Create user
    print("\n2. Creating user:")
    user_data, status = client.create_user("Test User", "test@example.com")
    print(f"Status: {status}")
    print(f"Response: {user_data}")
    
    if status == 201:
        user_id = user_data.get('user_id')
        
        # Get user profile
        print(f"\n3. Getting user profile for {user_id}:")
        profile, status = client.get_user(user_id)
        print(f"Status: {status}")
        print(f"Response: {profile}")
        
        # Get user sessions
        print(f"\n4. Getting sessions for {user_id}:")
        sessions, status = client.get_user_sessions(user_id)
        print(f"Status: {status}")
        print(f"Response: {sessions}")
        
        # Test analysis (if sample files exist)
        sample_audio = "generated_files/user_recording.m4a"
        sample_sheet = "generated_files/sheet_music.pdf"
        
        if os.path.exists(sample_audio) and os.path.exists(sample_sheet):
            print(f"\n5. Testing analysis with sample files:")
            analysis, status = client.analyze_practice(
                user_id, 
                sample_audio, 
                sample_sheet, 
                "Sample Piece", 
                120.0
            )
            print(f"Status: {status}")
            print(f"Response: {analysis}")
        else:
            print(f"\n5. Skipping analysis test - sample files not found")
            print(f"Expected: {sample_audio}, {sample_sheet}")

if __name__ == "__main__":
    main() 