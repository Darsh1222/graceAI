#!/usr/bin/env python3
"""
Clean implementation for converting sheet music images to MIDI:
1. JPEG -> MusicXML using Audiveris
2. MusicXML -> MIDI using MuseScore
"""

import os
import subprocess
import sys
from pathlib import Path

def check_dependencies():
    """Check if Audiveris and MuseScore are installed."""
    try:
        from dependency_checker import DependencyChecker
        checker = DependencyChecker()
        all_ok, results = checker.check_all_dependencies()
        return all_ok
    except ImportError:
        # Fallback to basic check if dependency_checker is not available
        audiveris_path = "/Applications/Audiveris.app/Contents/MacOS/Audiveris"
        musescore_path = "/Applications/MuseScore 3.app/Contents/MacOS/mscore"
        
        if not os.path.exists(audiveris_path):
            print("❌ Audiveris not found. Please install Audiveris first.")
            print("   Download from: https://github.com/Audiveris/audiveris")
            return False
        
        if not os.path.exists(musescore_path):
            print("❌ MuseScore 3 not found. Please install MuseScore 3 first.")
            print("   Download from: https://musescore.org/")
            return False
        
        print("✅ Dependencies found:")
        print(f"   Audiveris: {audiveris_path}")
        print(f"   MuseScore: {musescore_path}")
        return True

def jpeg_to_musicxml(image_path, output_dir):
    """
    Convert JPEG image to MusicXML using Audiveris.
    
    Args:
        image_path (str): Path to the JPEG image
        output_dir (str): Directory to save the MusicXML file
    
    Returns:
        str: Path to the created MusicXML file
    """
    if not os.path.exists(image_path):
        raise FileNotFoundError(f"Image file not found: {image_path}")
    
    os.makedirs(output_dir, exist_ok=True)
    
    # Get base name for output file
    base_name = Path(image_path).stem
    
    # Step 1: Process image to create .omr file
    print(f"🎼 Step 1: Processing image with Audiveris to create .omr file...")
    audiveris_path = "/Applications/Audiveris.app/Contents/MacOS/Audiveris"
    cmd1 = [
        audiveris_path,
        "-batch",           # Run in batch mode
        "-output", output_dir,  # Output directory
        image_path          # Input image
    ]
    
    print(f"🔧 Running command: {' '.join(cmd1)}")
    
    try:
        result1 = subprocess.run(cmd1, capture_output=True, text=True, check=True)
        print("✅ Step 1 completed - .omr file should be created")
        
        # Look for the .omr file
        omr_path = os.path.join(output_dir, f"{base_name}.omr")
        if not os.path.exists(omr_path):
            print("🔍 Searching for .omr files in output directory...")
            for file in os.listdir(output_dir):
                if file.endswith('.omr'):
                    omr_path = os.path.join(output_dir, file)
                    print(f"📄 Found .omr file: {omr_path}")
                    break
        
        if not os.path.exists(omr_path):
            print("❌ No .omr file found")
            print(f"📁 Files in {output_dir}:")
            for file in os.listdir(output_dir):
                print(f"   - {file}")
            raise FileNotFoundError(".omr file not found after Audiveris processing")
        
        # Step 2: Export .omr to MusicXML
        print(f"📄 Step 2: Exporting .omr to MusicXML...")
        cmd2 = [
            audiveris_path,
            "-batch",           # Run in batch mode
            "-export",          # Export the results
            "-output", output_dir,  # Output directory
            omr_path           # Input .omr file
        ]
        
        print(f"🔧 Running command: {' '.join(cmd2)}")
        
        result2 = subprocess.run(cmd2, capture_output=True, text=True, check=True)
        print("✅ Step 2 completed - MusicXML should be created")
        
        # Look for the created MusicXML file
        musicxml_path = None
        
        # First try the expected name based on .omr file
        omr_base = Path(omr_path).stem
        for ext in [".musicxml", ".xml", ".mxl"]:
            candidate = os.path.join(output_dir, f"{omr_base}{ext}")
            if os.path.exists(candidate):
                musicxml_path = candidate
                break
        
        # If not found, search for any .mxl or .musicxml file in the output directory
        if not musicxml_path:
            print("🔍 Searching for MusicXML files in output directory...")
            for file in os.listdir(output_dir):
                if file.endswith(('.mxl', '.musicxml', '.xml')):
                    candidate = os.path.join(output_dir, file)
                    if os.path.isfile(candidate):
                        musicxml_path = candidate
                        print(f"📄 Found MusicXML file: {musicxml_path}")
                        break
        
        if musicxml_path:
            print(f"📄 MusicXML created: {musicxml_path}")
            return musicxml_path
        else:
            print("❌ No MusicXML files found in output directory")
            print(f"📁 Files in {output_dir}:")
            for file in os.listdir(output_dir):
                print(f"   - {file}")
            raise FileNotFoundError("MusicXML file not found after Audiveris export")
            
    except subprocess.CalledProcessError as e:
        print(f"❌ Audiveris failed: {e}")
        print(f"stdout: {e.stdout}")
        print(f"stderr: {e.stderr}")
        raise
    except Exception as e:
        print(f"❌ Error during Audiveris processing: {e}")
        raise

def musicxml_to_midi(musicxml_path, output_dir):
    """
    Convert MusicXML to MIDI using MuseScore.
    
    Args:
        musicxml_path (str): Path to the MusicXML file
        output_dir (str): Directory to save the MIDI file
    
    Returns:
        str: Path to the created MIDI file
    """
    if not os.path.exists(musicxml_path):
        raise FileNotFoundError(f"MusicXML file not found: {musicxml_path}")
    
    os.makedirs(output_dir, exist_ok=True)
    
    # Get base name for output file
    base_name = Path(musicxml_path).stem
    midi_path = os.path.join(output_dir, f"{base_name}_goldencopy.mid")
    
    # MuseScore command
    musescore_path = "/Applications/MuseScore 3.app/Contents/MacOS/mscore"
    cmd = [
        musescore_path,
        musicxml_path,  # Input MusicXML
        "-o", midi_path  # Output MIDI
    ]
    
    print(f"🎹 Converting MusicXML to MIDI...")
    print(f"📄 Input: {musicxml_path}")
    print(f"🎵 Output: {midi_path}")
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        print("✅ MuseScore conversion completed successfully")
        
        if os.path.exists(midi_path):
            print(f"🎵 MIDI file created: {midi_path}")
            return midi_path
        else:
            raise FileNotFoundError("MIDI file not found after MuseScore conversion")
            
    except subprocess.CalledProcessError as e:
        print(f"❌ MuseScore failed: {e}")
        print(f"stdout: {e.stdout}")
        print(f"stderr: {e.stderr}")
        raise
    except Exception as e:
        print(f"❌ Error during MuseScore conversion: {e}")
        raise

def jpeg_to_midi_pipeline(image_path, output_dir="generated_files"):
    """
    Complete pipeline: JPEG -> MusicXML -> MIDI
    
    Args:
        image_path (str): Path to the JPEG image
        output_dir (str): Directory to save all output files
    
    Returns:
        dict: Paths to all created files
    """
    print("🎵 Starting JPEG to MIDI pipeline")
    print("=" * 40)
    
    # Check dependencies first
    if not check_dependencies():
        raise RuntimeError("Missing required dependencies")
    
    try:
        # Step 1: JPEG -> MusicXML
        print("\n📄 Step 1: Converting JPEG to MusicXML...")
        musicxml_path = jpeg_to_musicxml(image_path, output_dir)
        
        # Step 2: MusicXML -> MIDI
        print("\n🎹 Step 2: Converting MusicXML to MIDI...")
        midi_path = musicxml_to_midi(musicxml_path, output_dir)
        
        # Return results
        results = {
            'input_image': image_path,
            'musicxml': musicxml_path,
            'midi': midi_path
        }
        
        print("\n✅ Pipeline completed successfully!")
        print("=" * 40)
        for key, path in results.items():
            if os.path.exists(path):
                size = os.path.getsize(path)
                print(f"📁 {key}: {path} ({size:,} bytes)")
        
        return results
        
    except Exception as e:
        print(f"\n❌ Pipeline failed: {e}")
        raise

def main():
    """Main function for testing the pipeline."""
    # Example usage
    image_file = "generated_files/IMG_6169.jpeg"
    output_dir = "generated_files"
    
    if not os.path.exists(image_file):
        print(f"❌ Image file not found: {image_file}")
        print("Please provide a valid JPEG image path.")
        sys.exit(1)
    
    try:
        results = jpeg_to_midi_pipeline(image_file, output_dir)
        print(f"\n🎉 Success! MIDI file created: {results['midi']}")
    except Exception as e:
        print(f"\n❌ Failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()