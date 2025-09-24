#!/usr/bin/env python3
"""
Test script to verify music processing functionality without database dependency
"""

import sys
import os
import tempfile
import shutil
from pathlib import Path

# Add the app directory to the Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.services.analysis_engine import run_full_pipeline

def test_music_processing():
    """Test music processing with the provided files"""
    
    # Paths to test files
    audio_file = "../data/generated_files/testRecording.m4a"
    pdf_file = "../data/generated_files/jinglebooomtestfr.pdf"
    
    print("🎵 Testing Music Processing Pipeline")
    print("=" * 50)
    
    # Test 1: Audio file processing
    print("\n1. Testing Audio File Processing...")
    print(f"   Audio file: {audio_file}")
    
    if os.path.exists(audio_file):
        try:
            result = run_full_pipeline(audio_file, None)
            print("   ✅ Audio processing completed!")
            print(f"   Result keys: {list(result.keys())}")
            
            # Show some results
            if 'midi_path' in result and result['midi_path']:
                print(f"   MIDI file created: {result['midi_path']}")
            if 'accuracy_score' in result:
                print(f"   Accuracy score: {result['accuracy_score']}")
            if 'feedback' in result:
                print(f"   Feedback: {result['feedback'][:100]}...")
                
        except Exception as e:
            print(f"   ❌ Audio processing failed: {e}")
    else:
        print(f"   ❌ Audio file not found: {audio_file}")
    
    # Test 2: PDF file processing
    print("\n2. Testing PDF File Processing...")
    print(f"   PDF file: {pdf_file}")
    
    if os.path.exists(pdf_file):
        try:
            result = run_full_pipeline(None, pdf_file)
            print("   ✅ PDF processing completed!")
            print(f"   Result keys: {list(result.keys())}")
            
            # Show some results
            if 'midi_path' in result and result['midi_path']:
                print(f"   MIDI file created: {result['midi_path']}")
            if 'accuracy_score' in result:
                print(f"   Accuracy score: {result['accuracy_score']}")
            if 'feedback' in result:
                print(f"   Feedback: {result['feedback'][:100]}...")
                
        except Exception as e:
            print(f"   ❌ PDF processing failed: {e}")
    else:
        print(f"   ❌ PDF file not found: {pdf_file}")
    
    print("\n" + "=" * 50)
    print("🎉 Music Processing Test Complete!")

if __name__ == "__main__":
    test_music_processing()
