#!/usr/bin/env python3
"""
Run script for MIDI comparison and feedback system.
"""

from midi_comparison import MIDIComparator
import os
import sys

def run_midi_comparison(user_midi_path: str, golden_midi_path: str, output_dir: str = "generated_files"):
    """
    Run the complete MIDI comparison and feedback system.
    
    Args:
        user_midi_path (str): Path to user's performance MIDI file
        golden_midi_path (str): Path to golden copy MIDI file
        output_dir (str): Directory to save output files
    
    Returns:
        dict: Complete report with analysis, feedback, and visualization
    """
    print("🎵 TuneIn MIDI Comparison System")
    print("=" * 40)
    
    # Check if MIDI files exist
    if not os.path.exists(user_midi_path):
        print(f"❌ User MIDI file not found: {user_midi_path}")
        return None
    
    if not os.path.exists(golden_midi_path):
        print(f"❌ Golden copy MIDI file not found: {golden_midi_path}")
        return None
    
    print(f"📁 User performance: {user_midi_path}")
    print(f"📁 Golden copy: {golden_midi_path}")
    print(f"📁 Output directory: {output_dir}")
    
    # Create comparator
    comparator = MIDIComparator()
    
    try:
        # Generate complete report
        report = comparator.generate_complete_report(user_midi_path, golden_midi_path, output_dir)
        
        # Display results
        print("\n📊 Analysis Results:")
        print("=" * 30)
        analysis = report['analysis']
        print(f"🎯 Overall Accuracy: {analysis['accuracy_percentage']:.1f}%")
        print(f"✅ Correct Notes: {analysis['correct_notes']}/{analysis['total_golden_notes']}")
        print(f"❌ Missed Notes: {analysis['missed_notes']}")
        print(f"➕ Extra Notes: {analysis['extra_notes']}")
        print(f"⏱️  Timing Accuracy: {analysis['timing_accuracy']:.1f}%")
        print(f"🎚️  Velocity Accuracy: {analysis['velocity_accuracy']:.1f}%")
        
        print(f"\n📊 Visualization: {report['visualization_path']}")
        print(f"📄 Detailed Report: {report['report_path']}")
        
        print(f"\n💬 Feedback:")
        print("-" * 30)
        print(report['feedback'])
        
        return report
        
    except Exception as e:
        print(f"❌ Comparison failed: {e}")
        return None

def find_midi_files_by_suffix(output_dir: str = "generated_files"):
    """Find MIDI files by their suffixes."""
    user_midi = None
    golden_midi = None
    
    if not os.path.exists(output_dir):
        print(f"❌ Output directory not found: {output_dir}")
        return None, None
    
    # Search for files with the specific suffixes
    for file in os.listdir(output_dir):
        if file.endswith('_userRecording.mid'):
            user_midi = os.path.join(output_dir, file)
        elif file.endswith('_goldencopy.mid'):
            golden_midi = os.path.join(output_dir, file)
    
    return user_midi, golden_midi

def test_with_sample_files():
    """Test the comparison system with sample files."""
    print("🧪 Testing MIDI comparison with sample files...")
    
    # Find files dynamically by suffix
    user_midi, golden_midi = find_midi_files_by_suffix()
    
    if not user_midi:
        print("❌ No user recording MIDI found (*_userRecording.mid)")
        print("Please run the audio transcription pipeline first.")
        return False
    
    if not golden_midi:
        print("❌ No golden copy MIDI found (*_goldencopy.mid)")
        print("Please run the sheet music pipeline first.")
        return False
    
    report = run_midi_comparison(user_midi, golden_midi)
    
    if report:
        print("\n🎉 MIDI comparison test completed successfully!")
        return True
    else:
        print("\n❌ MIDI comparison test failed!")
        return False

def main():
    """Main function."""
    success = test_with_sample_files()
    
    if success:
        print("\n✅ All systems working!")
    else:
        print("\n❌ Some issues detected.")
        sys.exit(1)

if __name__ == "__main__":
    main() 