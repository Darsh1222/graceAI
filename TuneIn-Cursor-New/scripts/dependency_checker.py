#!/usr/bin/env python3
"""
Dependency Checker for TuneIn
Checks for required software and provides installation instructions.
"""

import os
import subprocess
import sys
import platform

class DependencyChecker:
    """Checks for required dependencies and provides installation help."""
    
    def __init__(self):
        self.system = platform.system()
        self.is_mac = self.system == "Darwin"
        self.is_windows = self.system == "Windows"
        self.is_linux = self.system == "Linux"
    
    def check_audiveris(self):
        """Check if Audiveris is installed."""
        audiveris_paths = []
        
        if self.is_mac:
            audiveris_paths = [
                "/Applications/Audiveris.app/Contents/MacOS/Audiveris",
                "/usr/local/bin/audiveris",
                "/opt/homebrew/bin/audiveris"
            ]
        elif self.is_windows:
            audiveris_paths = [
                "C:\\Program Files\\Audiveris\\bin\\audiveris.bat",
                "C:\\Program Files (x86)\\Audiveris\\bin\\audiveris.bat"
            ]
        else:  # Linux
            audiveris_paths = [
                "/usr/bin/audiveris",
                "/usr/local/bin/audiveris",
                "/opt/audiveris/bin/audiveris"
            ]
        
        for path in audiveris_paths:
            if os.path.exists(path):
                return True, path
        
        return False, None
    
    def check_musescore(self):
        """Check if MuseScore is installed."""
        musescore_paths = []
        
        if self.is_mac:
            musescore_paths = [
                "/Applications/MuseScore 3.app/Contents/MacOS/mscore",
                "/Applications/MuseScore.app/Contents/MacOS/mscore",
                "/usr/local/bin/mscore",
                "/opt/homebrew/bin/mscore"
            ]
        elif self.is_windows:
            musescore_paths = [
                "C:\\Program Files\\MuseScore 3\\bin\\MuseScore3.exe",
                "C:\\Program Files (x86)\\MuseScore 3\\bin\\MuseScore3.exe",
                "C:\\Program Files\\MuseScore\\bin\\MuseScore.exe"
            ]
        else:  # Linux
            musescore_paths = [
                "/usr/bin/mscore",
                "/usr/bin/musescore",
                "/usr/local/bin/mscore"
            ]
        
        for path in musescore_paths:
            if os.path.exists(path):
                return True, path
        
        return False, None
    
    def check_python_dependencies(self):
        """Check if required Python packages are installed."""
        required_packages = [
            'mido', 'matplotlib', 'numpy', 'basic_pitch', 
            'pretty_midi', 'soundfile', 'ffmpeg'
        ]
        
        missing_packages = []
        for package in required_packages:
            try:
                if package == 'ffmpeg':
                    __import__('ffmpeg')
                else:
                    __import__(package.replace('-', '_'))
            except ImportError:
                missing_packages.append(package)
        
        return len(missing_packages) == 0, missing_packages
    
    def get_installation_instructions(self, dependency):
        """Get installation instructions for a specific dependency."""
        instructions = {
            'audiveris': {
                'mac': """
📥 Install Audiveris on macOS:
1. Download from: https://github.com/Audiveris/audiveris/releases
2. Or use Homebrew: brew install audiveris
3. Or download the .dmg file and install manually
""",
                'windows': """
📥 Install Audiveris on Windows:
1. Download from: https://github.com/Audiveris/audiveris/releases
2. Run the installer (.exe file)
3. Add to PATH if prompted
""",
                'linux': """
📥 Install Audiveris on Linux:
1. Ubuntu/Debian: sudo apt-get install audiveris
2. Or download from: https://github.com/Audiveris/audiveris/releases
3. Or build from source
"""
            },
            'musescore': {
                'mac': """
📥 Install MuseScore on macOS:
1. Download from: https://musescore.org/
2. Or use Homebrew: brew install musescore
3. Install the .dmg file
""",
                'windows': """
📥 Install MuseScore on Windows:
1. Download from: https://musescore.org/
2. Run the installer (.exe file)
3. Follow installation wizard
""",
                'linux': """
📥 Install MuseScore on Linux:
1. Ubuntu/Debian: sudo apt-get install musescore
2. Or download from: https://musescore.org/
3. Or use your package manager
"""
            }
        }
        
        system_key = 'mac' if self.is_mac else 'windows' if self.is_windows else 'linux'
        return instructions.get(dependency, {}).get(system_key, "Please check the official website for installation instructions.")
    
    def check_all_dependencies(self):
        """Check all dependencies and return comprehensive report."""
        print("🔍 Checking TuneIn Dependencies")
        print("=" * 40)
        
        # Check Audiveris
        audiveris_installed, audiveris_path = self.check_audiveris()
        print(f"🎼 Audiveris: {'✅ Found' if audiveris_installed else '❌ Not Found'}")
        if audiveris_installed:
            print(f"   Location: {audiveris_path}")
        else:
            print(self.get_installation_instructions('audiveris'))
        
        # Check MuseScore
        musescore_installed, musescore_path = self.check_musescore()
        print(f"🎹 MuseScore: {'✅ Found' if musescore_installed else '❌ Not Found'}")
        if musescore_installed:
            print(f"   Location: {musescore_path}")
        else:
            print(self.get_installation_instructions('musescore'))
        
        # Check Python packages
        python_ok, missing_packages = self.check_python_dependencies()
        print(f"🐍 Python Packages: {'✅ All Found' if python_ok else '❌ Missing Packages'}")
        if not python_ok:
            print(f"   Missing: {', '.join(missing_packages)}")
            print("   Install with: pip install " + " ".join(missing_packages))
        
        # Summary
        print("\n📊 Summary:")
        print("-" * 20)
        all_ok = audiveris_installed and musescore_installed and python_ok
        
        if all_ok:
            print("✅ All dependencies are installed!")
            print("🚀 Ready to run TuneIn pipeline")
        else:
            print("❌ Some dependencies are missing")
            print("📋 Please install missing dependencies before running the pipeline")
            
            if not audiveris_installed:
                print("   - Audiveris is required for sheet music processing")
            if not musescore_installed:
                print("   - MuseScore is required for MIDI conversion")
            if not python_ok:
                print("   - Python packages are required for audio processing")
        
        return all_ok, {
            'audiveris': (audiveris_installed, audiveris_path),
            'musescore': (musescore_installed, musescore_path),
            'python_packages': (python_ok, missing_packages)
        }
    
    def get_alternative_solutions(self):
        """Provide alternative solutions if dependencies are missing."""
        print("\n💡 Alternative Solutions:")
        print("-" * 25)
        print("If you can't install Audiveris or MuseScore:")
        print("1. Use online OMR services (e.g., Audiveris online)")
        print("2. Use alternative sheet music processing tools")
        print("3. Manually create MIDI files and upload them")
        print("4. Use the audio-only pipeline (without sheet music comparison)")

def main():
    """Main function to check dependencies."""
    checker = DependencyChecker()
    all_ok, results = checker.check_all_dependencies()
    
    if not all_ok:
        checker.get_alternative_solutions()
    
    return all_ok

if __name__ == "__main__":
    main() 