#!/usr/bin/env python3
"""
System Requirements Checker for TuneIn
Shows what happens when dependencies are missing.
"""

import os
import sys

def check_system_requirements():
    """Check if the system meets requirements for TuneIn."""
    print("🔍 TuneIn System Requirements Check")
    print("=" * 50)
    
    # Check if dependency checker exists
    if os.path.exists("dependency_checker.py"):
        print("✅ Dependency checker available")
        from dependency_checker import DependencyChecker
        checker = DependencyChecker()
        all_ok, results = checker.check_all_dependencies()
        
        if not all_ok:
            print("\n⚠️  IMPORTANT: Missing Dependencies")
            print("=" * 40)
            print("The TuneIn pipeline will NOT work without these dependencies:")
            print()
            
            audiveris_ok, _ = results['audiveris']
            musescore_ok, _ = results['musescore']
            python_ok, _ = results['python_packages']
            
            if not audiveris_ok:
                print("❌ Audiveris missing - Sheet music processing will fail")
                print("   This is required to convert sheet music images to MIDI")
            
            if not musescore_ok:
                print("❌ MuseScore missing - MIDI conversion will fail")
                print("   This is required to convert MusicXML to MIDI")
            
            if not python_ok:
                print("❌ Python packages missing - Audio processing may fail")
                print("   Required for audio transcription and analysis")
            
            print("\n💡 What this means for your app:")
            print("- Users without these dependencies cannot use sheet music features")
            print("- Audio-only features may still work (depending on Python packages)")
            print("- You'll need to provide clear installation instructions")
            print("- Consider providing alternative solutions")
        
        return all_ok
    else:
        print("❌ Dependency checker not found")
        return False

def show_alternative_approaches():
    """Show alternative approaches when dependencies are missing."""
    print("\n💡 Alternative Approaches for Your App:")
    print("=" * 45)
    
    print("1. 📱 Audio-Only Mode:")
    print("   - Only use audio transcription (no sheet music)")
    print("   - Compare user audio with pre-existing MIDI files")
    print("   - Requires only Python packages (no Audiveris/MuseScore)")
    
    print("\n2. 🌐 Web-Based Processing:")
    print("   - Use online OMR services instead of local Audiveris")
    print("   - Use online MusicXML to MIDI converters")
    print("   - Requires internet connection but no local software")
    
    print("\n3. 📤 Manual Upload Mode:")
    print("   - Let users upload their own MIDI files")
    print("   - Skip the sheet music processing entirely")
    print("   - Users create MIDI files using their own tools")
    
    print("\n4. 🔧 Progressive Enhancement:")
    print("   - Start with basic audio features")
    print("   - Add sheet music features only if dependencies are available")
    print("   - Graceful degradation when software is missing")

def show_implementation_strategy():
    """Show how to implement dependency-aware features."""
    print("\n🎯 Implementation Strategy:")
    print("=" * 30)
    
    print("1. Check dependencies on app startup")
    print("2. Show/hide features based on availability")
    print("3. Provide clear error messages when features are unavailable")
    print("4. Offer installation instructions or alternatives")
    print("5. Consider cloud-based processing for complex operations")

def main():
    """Main function."""
    print("🎵 TuneIn Dependency Analysis")
    print("=" * 30)
    
    # Check current system
    system_ok = check_system_requirements()
    
    if not system_ok:
        show_alternative_approaches()
        show_implementation_strategy()
        
        print("\n📋 Summary for App Development:")
        print("-" * 35)
        print("✅ Audio transcription: Works with Python packages only")
        print("❌ Sheet music processing: Requires Audiveris + MuseScore")
        print("✅ MIDI comparison: Works with any MIDI files")
        print("❌ Full pipeline: Requires all dependencies")
        
        print("\n🚀 Recommended approach:")
        print("1. Start with audio-only features")
        print("2. Add sheet music features as optional")
        print("3. Provide clear dependency requirements")
        print("4. Offer alternative solutions")
    else:
        print("\n🎉 All systems ready!")
        print("Your app can use the full TuneIn pipeline")

if __name__ == "__main__":
    main() 