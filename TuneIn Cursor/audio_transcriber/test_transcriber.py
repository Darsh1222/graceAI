import os
import sys
import argparse
from audio_transcriber.transcriber import transcribe_audio

def main():
    parser = argparse.ArgumentParser(description="Test audio transcription from .m4a to MIDI.")
    parser.add_argument("input_m4a", help="Path to input .m4a file")
    parser.add_argument("output_dir", help="Directory to save output files")
    args = parser.parse_args()
    try:
        midi_path = transcribe_audio(args.input_m4a, args.output_dir)
        print(f"MIDI file generated: {midi_path}")
        if os.path.exists(midi_path):
            print("Test successful: MIDI file exists.")
        else:
            print("Test failed: MIDI file not found.")
    except Exception as e:
        print(f"Error during transcription: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 