#!/usr/bin/env python3
"""
Dependency-Free TuneIn Pipeline Runner
Works without requiring Audiveris or MuseScore installations.
"""

from cloud_based_alternatives import DependencyFreePipeline
import os
import sys

def run_dependency_free_pipeline():
    """Run the complete pipeline without external dependencies."""
    print("🎵 TuneIn Dependency-Free Pipeline")
    print("=" * 50)
    print("✅ No Audiveris or MuseScore required!")
    print("✅ Works with just Python packages")
    print("=" * 50)
    
    # Find input files
    user_audio = None
    sheet_music = None
    
    # Look for audio files
    if os.path.exists("generated_files"):
        for file in os.listdir("generated_files"):
            if file.endswith(('.m4a', '.wav', '.mp3')):
                user_audio = os.path.join("generated_files", file)
                break
    
    # Look for image files
    if os.path.exists("generated_files"):
        for file in os.listdir("generated_files"):
            if file.endswith(('.jpeg', '.jpg', '.png')):
                sheet_music = os.path.join("generated_files", file)
                break
    
    if not user_audio:
        print("❌ No audio file found in generated_files/")
        print("   Please add an audio file (.m4a, .wav, .mp3)")
        return False
    
    if not sheet_music:
        print("❌ No sheet music image found in generated_files/")
        print("   Please add an image file (.jpeg, .jpg, .png)")
        return False
    
    print(f"📱 User audio: {user_audio}")
    print(f"📄 Sheet music: {sheet_music}")
    
    # Run the pipeline
    pipeline = DependencyFreePipeline()
    
    try:
        results = pipeline.run_complete_pipeline_no_dependencies(
            user_audio, sheet_music, "generated_files"
        )
        
        print("\n🎉 Pipeline completed successfully!")
        print("=" * 40)
        
        if 'user_midi' in results:
            print(f"✅ User MIDI: {results['user_midi']}")
        
        if 'golden_midi' in results:
            print(f"✅ Golden copy MIDI: {results['golden_midi']}")
        
        if 'comparison_report' in results:
            report = results['comparison_report']
            print(f"📊 Visualization: {report['visualization_path']}")
            print(f"📄 Report: {report['report_path']}")
            print(f"💬 Feedback: {report['feedback'][:100]}...")
        
        return True
        
    except Exception as e:
        print(f"❌ Pipeline failed: {e}")
        return False

def show_advantages():
    """Show the advantages of the dependency-free approach."""
    print("\n🚀 Advantages of Dependency-Free Approach:")
    print("=" * 45)
    print("✅ No external software installation required")
    print("✅ Works on any system with Python")
    print("✅ Easier deployment and distribution")
    print("✅ Better user experience")
    print("✅ No dependency conflicts")
    print("✅ Faster setup for users")

def show_limitations():
    """Show current limitations and future improvements."""
    print("\n⚠️  Current Limitations:")
    print("=" * 25)
    print("📝 Sheet music processing is simplified (demo mode)")
    print("📝 In production, you should implement:")
    print("   - Real online OMR services")
    print("   - Better MusicXML parsing")
    print("   - More sophisticated MIDI generation")

def main():
    """Main function."""
    print("🎵 Welcome to TuneIn Dependency-Free!")
    print("=" * 40)
    
    # Show advantages
    show_advantages()
    
    # Run the pipeline
    success = run_dependency_free_pipeline()
    
    if success:
        print("\n🎉 Success! Your app can work without external dependencies!")
        print("📱 Users just need to install your app - no extra software!")
    else:
        print("\n❌ Pipeline failed, but the approach is still valid!")
        print("🔧 Check the error messages above for troubleshooting")
    
    # Show limitations
    show_limitations()
    
    print("\n💡 Next Steps:")
    print("- Implement real online OMR services")
    print("- Add better MusicXML parsing")
    print("- Integrate with cloud-based processing")
    print("- Test with real user scenarios")

if __name__ == "__main__":
    main() 