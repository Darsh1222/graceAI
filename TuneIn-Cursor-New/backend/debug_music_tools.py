#!/usr/bin/env python3
"""
Debug script to test MuseScore and Audiveris in the container
"""

import subprocess
import os
import sys

def test_command(cmd, description):
    """Test a command and return detailed results"""
    print(f"\n🔍 Testing {description}:")
    print(f"Command: {' '.join(cmd)}")
    
    try:
        result = subprocess.run(
            cmd, 
            capture_output=True, 
            text=True, 
            timeout=30
        )
        
        print(f"Return code: {result.returncode}")
        print(f"STDOUT: {result.stdout}")
        print(f"STDERR: {result.stderr}")
        
        return result.returncode == 0, result.stdout, result.stderr
        
    except subprocess.TimeoutExpired:
        print("❌ Command timed out")
        return False, "", "Timeout"
    except FileNotFoundError:
        print("❌ Command not found")
        return False, "", "File not found"
    except Exception as e:
        print(f"❌ Error: {e}")
        return False, "", str(e)

def check_file_exists(path, description):
    """Check if a file exists"""
    print(f"\n📁 Checking {description}: {path}")
    exists = os.path.exists(path)
    print(f"Exists: {exists}")
    if exists:
        print(f"Executable: {os.access(path, os.X_OK)}")
        print(f"Size: {os.path.getsize(path)} bytes")
    return exists

def main():
    print("🎵 Debugging MuseScore and Audiveris in Container")
    print("=" * 50)
    
    # Check if files exist
    check_file_exists("/usr/bin/musescore3", "MuseScore3 binary")
    check_file_exists("/usr/local/bin/audiveris", "Audiveris binary")
    check_file_exists("/opt/audiveris/bin/audiveris", "Audiveris original binary")
    
    # Check Java
    test_command(["java", "-version"], "Java version")
    
    # Test MuseScore
    test_command(["musescore3", "--version"], "MuseScore version")
    test_command(["musescore3", "--help"], "MuseScore help")
    
    # Test Audiveris
    test_command(["audiveris", "--version"], "Audiveris version")
    test_command(["audiveris", "--help"], "Audiveris help")
    
    # Check environment
    print(f"\n🌍 Environment:")
    print(f"USER: {os.environ.get('USER', 'Not set')}")
    print(f"HOME: {os.environ.get('HOME', 'Not set')}")
    print(f"DISPLAY: {os.environ.get('DISPLAY', 'Not set')}")
    
    # Check if we can run with xvfb
    test_command(["xvfb-run", "--help"], "Xvfb help")
    test_command(["xvfb-run", "-a", "musescore3", "--version"], "MuseScore with Xvfb")

if __name__ == "__main__":
    main()
