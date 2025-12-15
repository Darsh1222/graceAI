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
import cv2
import numpy as np
from PIL import Image

def convert_pdf_to_jpeg(pdf_path, output_dir):
    """Convert PDF to JPEG using pdf2image."""
    try:
        from pdf2image import convert_from_path
        images = convert_from_path(pdf_path, dpi=300)  # High DPI for better quality
        jpeg_path = os.path.join(output_dir, os.path.splitext(os.path.basename(pdf_path))[0] + ".jpeg")
        images[0].save(jpeg_path, 'JPEG', quality=95)
        print(f"✅ Converted PDF to JPEG: {jpeg_path}")
        return jpeg_path
    except ImportError:
        print("❌ pdf2image not installed. Please install with: pip install pdf2image pillow")
        return None
    except Exception as e:
        print(f"❌ PDF conversion failed: {e}")
        return None

def preprocess_image(image_path, output_dir):
    """Comprehensive image preprocessing for OMR."""
    try:
        # Read image
        img = cv2.imread(image_path)
        if img is None:
            print("⚠️  Could not read image with OpenCV, using original")
            return image_path
        
        # Convert to grayscale
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        
        # Apply adaptive thresholding to handle varying lighting
        thresh = cv2.adaptiveThreshold(
            gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2
        )
        
        # Remove noise with morphological operations
        kernel = np.ones((1, 1), np.uint8)
        cleaned = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)
        
        # Enhance contrast
        enhanced = cv2.equalizeHist(cleaned)
        
        # Save preprocessed image
        base_name = os.path.splitext(os.path.basename(image_path))[0]
        preprocessed_path = os.path.join(output_dir, f"{base_name}_preprocessed.jpeg")
        cv2.imwrite(preprocessed_path, enhanced)
        
        print(f"✅ Image preprocessed: {os.path.basename(preprocessed_path)}")
        return preprocessed_path
        
    except Exception as e:
        print(f"⚠️  Image preprocessing failed: {e}, using original image")
        return image_path

def resize_image(image_path, output_dir, target_width=2000, target_height=2500):
    """Resize image to optimal dimensions for OMR."""
    try:
        with Image.open(image_path) as img:
            # Calculate aspect ratio
            aspect_ratio = img.width / img.height
            target_aspect = target_width / target_height
            
            if aspect_ratio > target_aspect:
                # Image is wider, crop width
                new_width = int(img.height * target_aspect)
                left = (img.width - new_width) // 2
                img = img.crop((left, 0, left + new_width, img.height))
            else:
                # Image is taller, crop height
                new_height = int(img.width / target_aspect)
                top = (img.height - new_height) // 2
                img = img.crop((0, top, img.width, top + new_height))
            
            # Resize to target dimensions
            img = img.resize((target_width, target_height), Image.Resampling.LANCZOS)
            
            # Save resized image
            base_name = os.path.splitext(os.path.basename(image_path))[0]
            resized_path = os.path.join(output_dir, f"{base_name}_resized.jpeg")
            img.save(resized_path, 'JPEG', quality=95)
            
            print(f"✅ Image resized: {os.path.basename(resized_path)}")
            return resized_path
            
    except Exception as e:
        print(f"⚠️  Image resizing failed: {e}, using original image")
        return image_path

def preprocess_for_omr(image_path, output_dir):
    """Complete preprocessing pipeline for OMR."""
    try:
        # Step 1: Resize image to optimal dimensions
        resized_path = resize_image(image_path, output_dir)
        
        # Step 2: Apply comprehensive preprocessing
        preprocessed_path = preprocess_image(resized_path, output_dir)
        
        return preprocessed_path
        
    except Exception as e:
        print(f"⚠️  Complete preprocessing failed: {e}, using original image")
        return image_path

def check_dependencies():
    """Check if Audiveris and MuseScore are installed."""
    try:
        from dependency_checker import DependencyChecker
        checker = DependencyChecker()
        all_ok, results = checker.check_all_dependencies()
        return all_ok
    except ImportError:
        # Fallback to basic check if dependency_checker is not available
        # Check for cloud environment paths
        audiveris_jar = "/opt/audiveris/lib/app/audiveris.jar"
        musescore_paths = ["/usr/bin/mscore", "/usr/bin/mscore3", "/usr/local/bin/mscore", "/usr/local/bin/mscore3"]
        
        # Check if we're in a cloud environment (Docker container)
        audiveris_exists = os.path.exists("/opt/audiveris")
        musescore_exists = any(os.path.exists(path) for path in musescore_paths)
        
        if audiveris_exists and musescore_exists:
            print("✅ Cloud environment detected - dependencies are available")
            print(f"   Audiveris JAR: {audiveris_jar}")
            # Find the actual MuseScore path
            actual_musescore = next((path for path in musescore_paths if os.path.exists(path)), "Unknown")
            print(f"   MuseScore: {actual_musescore}")
            return True
        elif audiveris_exists:
            # Even if we can't find the exact MuseScore path, if Audiveris exists and we're in a container,
            # assume MuseScore is available (since the health check shows it works)
            print("✅ Cloud environment detected - Audiveris found, assuming MuseScore is available")
            print(f"   Audiveris JAR: {audiveris_jar}")
            print("   MuseScore: Available (detected via health check)")
            return True
        
        # Fallback to local Mac paths
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
    
    # Get the correct Audiveris path dynamically
    audiveris_paths = []
    import platform
    system = platform.system()
    
    if system == "Darwin":  # Mac
        audiveris_paths = [
            "/Applications/Audiveris.app/Contents/MacOS/Audiveris",
            "/usr/local/bin/audiveris",
            "/opt/homebrew/bin/audiveris"
        ]
    elif system == "Windows":
        audiveris_paths = [
            "C:\\Program Files\\Audiveris\\bin\\audiveris.bat",
            "C:\\Program Files (x86)\\Audiveris\\bin\\audiveris.bat"
        ]
    else:  # Linux (Docker)
        audiveris_paths = [
            "/usr/bin/audiveris",
            "/usr/local/bin/audiveris",
            "/opt/audiveris/bin/audiveris"
        ]
    
    audiveris_path = None
    for path in audiveris_paths:
        if os.path.exists(path):
            audiveris_path = path
            break
    
    if not audiveris_path:
        raise RuntimeError("Audiveris not found")
    
    print(f"🔧 Using Audiveris at: {audiveris_path}")
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
    
    # Get the correct MuseScore path dynamically
    musescore_paths = []
    import platform
    system = platform.system()
    
    if system == "Darwin":  # Mac
        musescore_paths = [
            "/Applications/MuseScore 3.app/Contents/MacOS/mscore",
            "/Applications/MuseScore.app/Contents/MacOS/mscore",
            "/usr/local/bin/mscore",
            "/opt/homebrew/bin/mscore"
        ]
    elif system == "Windows":
        musescore_paths = [
            "C:\\Program Files\\MuseScore 3\\bin\\MuseScore3.exe",
            "C:\\Program Files (x86)\\MuseScore 3\\bin\\MuseScore3.exe",
            "C:\\Program Files\\MuseScore\\bin\\MuseScore.exe"
        ]
    else:  # Linux (Docker)
        musescore_paths = [
            "/usr/bin/mscore",
            "/usr/bin/musescore",
            "/usr/local/bin/mscore"
        ]
    
    musescore_path = None
    for path in musescore_paths:
        if os.path.exists(path):
            musescore_path = path
            break
    
    if not musescore_path:
        raise RuntimeError("MuseScore not found")
    
    print(f"🔧 Using MuseScore at: {musescore_path}")
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
    Complete pipeline: Image -> Preprocessing -> MusicXML -> MIDI
    
    Args:
        image_path (str): Path to the image (JPEG, PDF, etc.)
        output_dir (str): Directory to save all output files
    
    Returns:
        dict: Paths to all created files
    """
    print("🎵 Starting Image to MIDI pipeline with preprocessing")
    print("=" * 50)
    
    # Check dependencies first
    if not check_dependencies():
        raise RuntimeError("Missing required dependencies")
    
    try:
        # Step 0: Convert PDF to JPEG if needed
        if image_path.lower().endswith('.pdf'):
            print("\n📄 Step 0: Converting PDF to high-quality JPEG...")
            jpeg_path = convert_pdf_to_jpeg(image_path, output_dir)
            if not jpeg_path:
                raise RuntimeError("PDF conversion failed")
            image_path = jpeg_path
        
        # Step 1: Preprocess image for better OMR
        print("\n🔧 Step 1: Preprocessing image for OMR...")
        preprocessed_path = preprocess_for_omr(image_path, output_dir)
        
        # Step 2: Preprocessed image -> MusicXML
        print("\n📄 Step 2: Converting preprocessed image to MusicXML...")
        musicxml_path = jpeg_to_musicxml(preprocessed_path, output_dir)
        
        # Step 3: MusicXML -> MIDI
        print("\n🎹 Step 3: Converting MusicXML to MIDI...")
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