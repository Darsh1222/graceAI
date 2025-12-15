#!/usr/bin/env python3
"""
Complete Pipeline Demo
Shows the full TuneIn pipeline with proper file labeling.
"""

import os
import sys
from pathlib import Path

def find_midi_files_by_suffix(output_dir: str = "generated_files"):
    """Find MIDI files by their suffixes."""
    user_midi = None
    golden_midi = None
    
    if not os.path.exists(output_dir):
        return None, None
    
    # Search for files with the specific suffixes
    for file in os.listdir(output_dir):
        if file.endswith('_userRecording.mid'):
            user_midi = os.path.join(output_dir, file)
        elif file.endswith('_goldencopy.mid'):
            golden_midi = os.path.join(output_dir, file)
    
    return user_midi, golden_midi

def demo_complete_pipeline():
    """Demonstrate the complete pipeline with proper file labeling."""
    print("🎵 TuneIn Complete Pipeline Demo")
    print("=" * 50)
    
    # Step 1: Audio Transcription (User Recording)
    print("\n📱 Step 1: Audio Transcription (User Recording)")
    print("-" * 40)
    user_audio = "generated_files/testRecording.m4a"
    if os.path.exists(user_audio):
        print(f"✅ User audio found: {user_audio}")
        print("🎵 This will create: testRecording_userRecording.mid")
    else:
        print(f"❌ User audio not found: {user_audio}")
    
    # Step 2: Sheet Music Processing (Golden Copy)
    print("\n📄 Step 2: Sheet Music Processing (Golden Copy)")
    print("-" * 40)
    sheet_music = "generated_files/IMG_6169.jpeg"
    if os.path.exists(sheet_music):
        print(f"✅ Sheet music found: {sheet_music}")
        print("🎵 This will create: IMG_6169_goldencopy.mid")
    else:
        print(f"❌ Sheet music not found: {sheet_music}")
    
    # Step 3: MIDI Comparison
    print("\n📊 Step 3: MIDI Comparison & Feedback")
    print("-" * 40)
    
    # Find files dynamically
    user_midi, golden_midi = find_midi_files_by_suffix()
    
    if user_midi:
        print(f"✅ User MIDI found: {user_midi}")
    else:
        print(f"❌ No user MIDI found (*_userRecording.mid)")
    
    if golden_midi:
        print(f"✅ Golden copy MIDI found: {golden_midi}")
    else:
        print(f"❌ No golden copy MIDI found (*_goldencopy.mid)")
    
    # Show expected file structure
    print("\n📁 Expected File Structure in generated_files/")
    print("-" * 40)
    expected_files = [
        "*.m4a (user audio)",
        "*_userRecording.mid (user performance)",
        "*.jpeg (sheet music)",
        "*_goldencopy.mid (golden copy)",
        "piano_roll_analysis_*.png (visualization)",
        "performance_report_*.json (detailed report)"
    ]
    
    for file_desc in expected_files:
        print(f"📄 {file_desc}")
    
    print("\n🎯 Pipeline Summary:")
    print("-" * 20)
    print("1. User uploads audio → Creates *_userRecording.mid")
    print("2. User uploads sheet music → Creates *_goldencopy.mid")
    print("3. System compares both → Generates feedback & visualization")
    
    return True

def check_current_files():
    """Check what files currently exist."""
    print("\n🔍 Current Files in generated_files/")
    print("-" * 30)
    
    generated_dir = "generated_files"
    if os.path.exists(generated_dir):
        files = os.listdir(generated_dir)
        for file in sorted(files):
            if file.endswith('.mid'):
                if 'userRecording' in file:
                    print(f"🎵 {file} (User Performance)")
                elif 'goldencopy' in file:
                    print(f"📄 {file} (Golden Copy)")
                else:
                    print(f"📄 {file} (Other MIDI)")
            else:
                print(f"📁 {file}")
    else:
        print("❌ generated_files directory not found")

def main():
    """Main function."""
    demo_complete_pipeline()
    check_current_files()
    
    print("\n🚀 Ready to run the complete pipeline!")
    print("Run these commands in order:")
    print("1. python3 test_transcriber.py generated_files/testRecording.m4a generated_files")
    print("2. python3 heic_to_midiRun.py")
    print("3. python3 midi_comparison_run.py")

if __name__ == "__main__":
    main() 