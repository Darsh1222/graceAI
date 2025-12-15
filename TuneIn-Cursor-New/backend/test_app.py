#!/usr/bin/env python3
"""
Simple test script for FastAPI app
"""

import sys
import os

# Add the app directory to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'app'))

try:
    from app.main import app
    print("✅ FastAPI app imported successfully!")
    
    # Test basic app properties
    print(f"✅ App title: {app.title}")
    print(f"✅ App version: {app.version}")
    print(f"✅ App description: {app.description}")
    
    # List available routes
    print("\n📋 Available routes:")
    for route in app.routes:
        if hasattr(route, 'path') and hasattr(route, 'methods'):
            methods = ', '.join(route.methods) if route.methods else 'GET'
            print(f"  {methods} {route.path}")
    
    print("\n🎉 FastAPI app is ready to run!")
    
except Exception as e:
    print(f"❌ Error importing FastAPI app: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
