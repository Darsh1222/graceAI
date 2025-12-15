#!/usr/bin/env python3
"""
Run script for the clean JPEG to MIDI pipeline using Audiveris and MuseScore.
"""

from heic_to_midi import jpeg_to_midi_pipeline, check_dependencies
import os
import sys

def run_pipeline(image_path, output_dir="generated_files"):
    """
    Run the complete JPEG to MIDI pipeline.
    
    Args:
        image_path (str): Path to the JPEG image
        output_dir (str): Directory to save output files
    
    Returns:
        dict: Results with paths to all created files
    """
    print("🎵 TuneIn Sheet Music Processing Pipeline")
    print("=" * 50)
    
    # Check if image exists
    if not os.path.exists(image_path):
        print(f"❌ Image file not found: {image_path}")
        return None
    
    # Check dependencies
    print("🔍 Checking dependencies...")
    if not check_dependencies():
        print("❌ Missing required dependencies. Please install Audiveris and MuseScore 3.")
        return None
    
    try:
        # Run the complete pipeline
        results = jpeg_to_midi_pipeline(image_path, output_dir)
        
        print("\n📊 Final Results:")
        print("=" * 30)
        for key, path in results.items():
            if path and os.path.exists(path):
                size = os.path.getsize(path)
                print(f"✅ {key}: {path} ({size:,} bytes)")
            else:
                print(f"❌ {key}: Not created")
        
        return results
        
    except Exception as e:
        print(f"\n❌ Pipeline failed: {e}")
        return None

def test_with_sample_image():
    """Test the pipeline with the sample image."""
    image_file = "generated_files/IMG_6169.jpeg"
    
    if not os.path.exists(image_file):
        print(f"❌ Sample image not found: {image_file}")
        print("Please make sure the sample image exists in the generated_files directory.")
        return False
    
    print(f"🧪 Testing with sample image: {image_file}")
    results = run_pipeline(image_file)
    
    if results and results.get('midi'):
        print(f"\n🎉 Test successful! MIDI file: {results['midi']}")
        return True
    else:
        print("\n❌ Test failed!")
        return False

def main():
    """Main function."""
    # Test with the sample image
    success = test_with_sample_image()
    
    if success:
        print("\n✅ Pipeline test completed successfully!")
    else:
        print("\n❌ Pipeline test failed!")
        sys.exit(1)

if __name__ == "__main__":
    main()

