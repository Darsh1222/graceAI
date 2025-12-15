#!/usr/bin/env python3
"""
Full GraceAI Pipeline Runner (with Audiveris and MuseScore)
Runs the complete pipeline with Audiveris and MuseScore for real sheet music processing.
Supports PDF, JPEG, and HEIC file formats.
Includes ALL code from other modules for maximum accuracy.
"""

# Set matplotlib to use non-interactive backend to prevent GUI crashes
import matplotlib
matplotlib.use('Agg')  # Use non-interactive backend

import os
import sys
import shutil
import json
import subprocess
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patches as patches
import ffmpeg
import soundfile as sf
import mido
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from basic_pitch.inference import predict
from basic_pitch import ICASSP_2022_MODEL_PATH
import pretty_midi

def preprocess_image(image_path, output_dir):
    """Comprehensive image preprocessing for OMR."""
    try:
        import cv2
        import numpy as np
        from PIL import Image
        
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
        base_name = Path(image_path).stem
        preprocessed_path = os.path.join(output_dir, f"{base_name}_preprocessed.jpeg")
        cv2.imwrite(preprocessed_path, enhanced)
        
        print(f"✅ Image preprocessed: {os.path.basename(preprocessed_path)}")
        return preprocessed_path
        
    except ImportError:
        print("⚠️  OpenCV not available, using original image")
        return image_path
    except Exception as e:
        print(f"⚠️  Image preprocessing failed: {e}, using original image")
        return image_path

def resize_image(image_path, output_dir, target_width=2000, target_height=2500):
    """Resize image to optimal dimensions for OMR."""
    try:
        from PIL import Image
        
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
            base_name = Path(image_path).stem
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

# ============================================================================
# AUDIO TRANSCRIPTION FUNCTIONS (from transcriber.py)
# ============================================================================

def m4a_to_wav(input_path, wav_path, sample_rate=44100):
    """Convert M4A to WAV using ffmpeg."""
    os.makedirs(os.path.dirname(wav_path), exist_ok=True)
    (
        ffmpeg.input(input_path)
        .output(wav_path, ar=sample_rate, ac=1, format='wav')
        .overwrite_output()
        .run(quiet=True)
    )
    data, sr = sf.read(wav_path)
    if sr != sample_rate:
        raise ValueError(f"Sample rate is {sr}, expected {sample_rate}")
    if len(data.shape) > 1 and data.shape[1] != 1:
        raise ValueError("Audio is not mono after conversion.")
    return wav_path

def transcribe_audio(input_m4a_path, output_dir):
    """Transcribe audio to MIDI using Basic Pitch."""
    if not os.path.exists(input_m4a_path):
        raise FileNotFoundError(f"Input file {input_m4a_path} does not exist.")
    os.makedirs(output_dir, exist_ok=True)
    base = os.path.splitext(os.path.basename(input_m4a_path))[0]
    wav_path = os.path.join(output_dir, base + "_converted.wav")
    midi_path = os.path.join(output_dir, base + "_userRecording.mid")
    m4a_to_wav(input_m4a_path, wav_path)

    model_output, midi_data, note_events = predict(
        wav_path,
        onset_threshold=0.5,
        frame_threshold=0.5,
    )

    midi_data.write(midi_path)
    return midi_path

# ============================================================================
# DEPENDENCY CHECKER FUNCTIONS (from dependency_checker.py)
# ============================================================================

class DependencyChecker:
    """Checks for required dependencies and provides installation help."""
    
    def __init__(self):
        import platform
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
    
    def check_all_dependencies(self):
        """Check all dependencies and return comprehensive report."""
        print("🔍 Checking GraceAI Dependencies")
        print("=" * 40)
        
        # Check Audiveris
        audiveris_installed, audiveris_path = self.check_audiveris()
        print(f"🎼 Audiveris: {'✅ Found' if audiveris_installed else '❌ Not Found'}")
        if audiveris_installed:
            print(f"   Location: {audiveris_path}")
        
        # Check MuseScore
        musescore_installed, musescore_path = self.check_musescore()
        print(f"🎹 MuseScore: {'✅ Found' if musescore_installed else '❌ Not Found'}")
        if musescore_installed:
            print(f"   Location: {musescore_path}")
        
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
            print("🚀 Ready to run GraceAI pipeline")
        else:
            print("❌ Some dependencies are missing")
            print("📋 Please install missing dependencies before running the pipeline")
        
        return all_ok, {
            'audiveris': (audiveris_installed, audiveris_path),
            'musescore': (musescore_installed, musescore_path),
            'python_packages': (python_ok, missing_packages)
        }

# ============================================================================
# MIDI COMPARISON FUNCTIONS (from midi_comparison.py)
# ============================================================================

class MIDIComparator:
    """Compares two MIDI files and generates feedback."""
    
    def __init__(self, openai_api_key: Optional[str] = None):
        self.openai_api_key = openai_api_key or os.getenv('OPENAI_API_KEY')
        if self.openai_api_key:
            import openai
            openai.api_key = self.openai_api_key
    
    def load_midi_file(self, midi_path: str) -> mido.MidiFile:
        """Load a MIDI file and return the MidiFile object."""
        if not os.path.exists(midi_path):
            raise FileNotFoundError(f"MIDI file not found: {midi_path}")
        
        print(f"📁 Loading MIDI file: {midi_path}")
        midi = mido.MidiFile(midi_path)
        print(f"✅ Loaded MIDI with {len(midi.tracks)} tracks")
        return midi
    
    def extract_notes_from_midi(self, midi: mido.MidiFile) -> List[Dict]:
        """Extract all notes from a MIDI file with timing information."""
        notes = []
        current_time = 0
        
        for track in midi.tracks:
            track_time = 0
            for msg in track:
                track_time += msg.time
                if msg.type == 'note_on' and msg.velocity > 0:
                    # Find corresponding note_off
                    note_off_time = track_time
                    note_off_velocity = 0
                    
                    # Look ahead for note_off
                    temp_time = track_time
                    for future_msg in track[track.index(msg) + 1:]:
                        temp_time += future_msg.time
                        if (future_msg.type == 'note_off' or 
                            (future_msg.type == 'note_on' and future_msg.velocity == 0)):
                            if future_msg.note == msg.note:
                                note_off_time = temp_time
                                break
                    
                    notes.append({
                        'note': msg.note,
                        'velocity': msg.velocity,
                        'start_time': track_time,
                        'end_time': note_off_time,
                        'duration': note_off_time - track_time,
                        'channel': msg.channel
                    })
        
        # Convert to absolute time
        ticks_per_beat = midi.ticks_per_beat
        tempo = 500000  # Default tempo (microseconds per beat)
        
        for note in notes:
            # Convert ticks to seconds
            note['start_seconds'] = mido.tick2second(note['start_time'], ticks_per_beat, tempo)
            note['end_seconds'] = mido.tick2second(note['end_time'], ticks_per_beat, tempo)
            note['duration_seconds'] = note['end_seconds'] - note['start_seconds']
        
        return notes
    
    def compare_midi_files(self, user_midi_path: str, golden_midi_path: str) -> Dict:
        """Compare two MIDI files and return analysis results."""
        print("🎵 Starting MIDI comparison...")
        
        # Load both MIDI files
        user_midi = self.load_midi_file(user_midi_path)
        golden_midi = self.load_midi_file(golden_midi_path)
        
        # Extract notes
        user_notes = self.extract_notes_from_midi(user_midi)
        golden_notes = self.extract_notes_from_midi(golden_midi)
        
        print(f"📊 User performance: {len(user_notes)} notes")
        print(f"📊 Golden copy: {len(golden_notes)} notes")
        
        # Analyze differences
        analysis = self._analyze_note_differences(user_notes, golden_notes)
        
        return {
            'user_notes': user_notes,
            'golden_notes': golden_notes,
            'analysis': analysis,
            'user_midi_path': user_midi_path,
            'golden_midi_path': golden_midi_path
        }
    
    def _analyze_note_differences(self, user_notes: List[Dict], golden_notes: List[Dict]) -> Dict:
        """Analyze differences between user and golden notes with tempo and timing alignment."""
        analysis = {
            'total_user_notes': len(user_notes),
            'total_golden_notes': len(golden_notes),
            'correct_notes': 0,
            'missed_notes': 0,
            'extra_notes': 0,
            'timing_errors': [],
            'velocity_errors': [],
            'accuracy_percentage': 0.0,
            'timing_accuracy': 0.0,
            'velocity_accuracy': 0.0,
            'tempo_ratio': 1.0,
            'time_offset': 0.0,
            'alignment_info': {},
            'missed_notes_details': [] # Added for specific missed notes
        }
        
        # Step 1: Detect tempo and timing offset
        tempo_info = self._detect_tempo_and_offset(user_notes, golden_notes)
        analysis['tempo_ratio'] = tempo_info['tempo_ratio']
        analysis['time_offset'] = tempo_info['time_offset']
        analysis['alignment_info'] = tempo_info
        
        # Step 2: Align user notes to golden copy timing
        aligned_user_notes = self._align_notes_to_golden(user_notes, tempo_info)
        
        # Step 3: Match notes with more flexible timing
        matched_golden = set()
        matched_user = set()
        
        for i, user_note in enumerate(aligned_user_notes):
            best_match = None
            best_score = float('inf')
            
            for j, golden_note in enumerate(golden_notes):
                if j in matched_golden:
                    continue
                
                # Check if notes match (same pitch)
                if user_note['note'] == golden_note['note']:
                    # Calculate timing difference with more flexible tolerance
                    time_diff = abs(user_note['aligned_start'] - golden_note['start_seconds'])
                    
                    # More flexible timing tolerance based on tempo
                    tolerance = max(0.2, 0.1 * tempo_info['tempo_ratio'])  # At least 200ms, scales with tempo
                    
                    if time_diff < tolerance:
                        score = time_diff
                        if score < best_score:
                            best_score = score
                            best_match = j
            
            if best_match is not None:
                analysis['correct_notes'] += 1
                matched_golden.add(best_match)
                matched_user.add(i)
                
                # Analyze timing and velocity differences
                golden_note = golden_notes[best_match]
                timing_diff = user_note['aligned_start'] - golden_note['start_seconds']
                velocity_diff = user_note['velocity'] - golden_note['velocity']
                
                # More lenient timing error threshold
                timing_threshold = max(0.15, 0.05 * tempo_info['tempo_ratio'])  # At least 150ms
                if abs(timing_diff) > timing_threshold:
                    analysis['timing_errors'].append({
                        'note': user_note['note'],
                        'user_time': user_note['aligned_start'],
                        'golden_time': golden_note['start_seconds'],
                        'difference': timing_diff,
                        'original_user_time': user_note['start_seconds']
                    })
                
                if abs(velocity_diff) > 15:  # More lenient velocity threshold
                    analysis['velocity_errors'].append({
                        'note': user_note['note'],
                        'user_velocity': user_note['velocity'],
                        'golden_velocity': golden_note['velocity'],
                        'difference': velocity_diff
                    })
        
        # Calculate missed and extra notes
        analysis['missed_notes'] = len(golden_notes) - len(matched_golden)
        analysis['extra_notes'] = abs(len(golden_notes) - len(user_notes))
        
        # Track missed notes with letter names
        missed_notes_details = []
        for j, golden_note in enumerate(golden_notes):
            if j not in matched_golden:
                note_name = self.midi_to_note_name(golden_note['note'])
                missed_notes_details.append(note_name)
        analysis['missed_notes_details'] = missed_notes_details
        
        # Calculate accuracy percentages
        if analysis['total_golden_notes'] > 0:
            analysis['accuracy_percentage'] = (analysis['correct_notes'] / analysis['total_golden_notes']) * 100
        
        if analysis['correct_notes'] > 0:
            timing_errors = len(analysis['timing_errors'])
            velocity_errors = len(analysis['velocity_errors'])
            analysis['timing_accuracy'] = ((analysis['correct_notes'] - timing_errors) / analysis['correct_notes']) * 100
            analysis['velocity_accuracy'] = ((analysis['correct_notes'] - velocity_errors) / analysis['correct_notes']) * 100
        
        return analysis
    
    def _detect_tempo_and_offset(self, user_notes: List[Dict], golden_notes: List[Dict]) -> Dict:
        """Detect tempo ratio and time offset between user and golden performance."""
        if len(user_notes) < 3 or len(golden_notes) < 3:
            return {'tempo_ratio': 1.0, 'time_offset': 0.0, 'confidence': 'low'}
        
        # Find potential matching note sequences
        matches = []
        for i, user_note in enumerate(user_notes):
            for j, golden_note in enumerate(golden_notes):
                if user_note['note'] == golden_note['note']:
                    matches.append({
                        'user_idx': i,
                        'golden_idx': j,
                        'user_time': user_note['start_seconds'],
                        'golden_time': golden_note['start_seconds']
                    })
        
        if len(matches) < 3:
            return {'tempo_ratio': 1.0, 'time_offset': 0.0, 'confidence': 'low'}
        
        # Calculate time differences for consecutive matches
        time_diffs = []
        for i in range(len(matches) - 1):
            user_interval = matches[i+1]['user_time'] - matches[i]['user_time']
            golden_interval = matches[i+1]['golden_time'] - matches[i]['golden_time']
            
            if golden_interval > 0.1:  # Minimum interval to avoid division by zero
                tempo_ratio = user_interval / golden_interval
                if 0.5 < tempo_ratio < 2.0:  # Reasonable tempo range
                    time_diffs.append(tempo_ratio)
        
        # Calculate average tempo ratio
        if time_diffs:
            avg_tempo_ratio = sum(time_diffs) / len(time_diffs)
        else:
            avg_tempo_ratio = 1.0
        
        # Calculate time offset (when user starts relative to golden)
        offsets = []
        for match in matches:
            # Adjust user time by tempo ratio to find offset
            adjusted_user_time = match['user_time'] / avg_tempo_ratio
            offset = adjusted_user_time - match['golden_time']
            offsets.append(offset)
        
        avg_offset = sum(offsets) / len(offsets) if offsets else 0.0
        
        return {
            'tempo_ratio': avg_tempo_ratio,
            'time_offset': avg_offset,
            'confidence': 'high' if len(time_diffs) > 2 else 'medium',
            'num_matches': len(matches)
        }
    
    def _align_notes_to_golden(self, user_notes: List[Dict], tempo_info: Dict) -> List[Dict]:
        """Align user notes to golden copy timing using detected tempo and offset."""
        aligned_notes = []
        
        for note in user_notes:
            # Apply tempo and offset correction
            aligned_start = (note['start_seconds'] / tempo_info['tempo_ratio']) - tempo_info['time_offset']
            aligned_end = (note['end_seconds'] / tempo_info['tempo_ratio']) - tempo_info['time_offset']
            
            aligned_note = note.copy()
            aligned_note['aligned_start'] = max(0, aligned_start)  # Don't go negative
            aligned_note['aligned_end'] = max(0, aligned_end)
            aligned_note['original_start'] = note['start_seconds']
            aligned_note['original_end'] = note['end_seconds']
            
            aligned_notes.append(aligned_note)
        
        return aligned_notes
    
    def _plot_piano_roll(self, ax, notes: List[Dict], title: str, color: str, alpha: float = 1.0):
        """Plot a basic piano roll."""
        for note in notes:
            y_pos = note['note']
            x_start = note['start_seconds']
            x_end = note['end_seconds']
            
            rect = patches.Rectangle((x_start, y_pos - 0.5), x_end - x_start, 1, 
                                   facecolor=color, alpha=alpha, edgecolor='black', linewidth=0.5)
            ax.add_patch(rect)
        
        ax.set_title(title, fontweight='bold')
        ax.set_xlabel('Time (seconds)')
        ax.set_ylabel('Note (MIDI pitch)')
        ax.grid(True, alpha=0.3)
        
        # Set reasonable y-axis limits
        if notes:
            min_note = min(note['note'] for note in notes)
            max_note = max(note['note'] for note in notes)
            ax.set_ylim(min_note - 5, max_note + 5)
    
    def _plot_piano_roll_improved(self, ax, user_notes: List[Dict], golden_notes: List[Dict], 
                                  title: str, analysis: Dict):
        """Plot piano roll with improved color coding and note labels."""
        # Create a mapping of golden notes for comparison
        golden_note_map = {}
        for note in golden_notes:
            key = (note['note'], round(note['start_seconds'], 1))
            golden_note_map[key] = note
        
        # Track which golden notes have been matched
        matched_golden = set()
        
        for note in user_notes:
            y_pos = note['note']
            x_start = note['start_seconds']
            x_end = note['end_seconds']
            
            # Determine color based on comparison
            color = 'red'  # Default to missed/wrong
            alpha = 0.7
            note_label = self.midi_to_note_name(note['note'])
            
            # Check if this note matches a golden note
            key = (note['note'], round(x_start, 1))
            if key in golden_note_map:
                golden_note = golden_note_map[key]
                timing_diff = abs(x_start - golden_note['start_seconds'])
                
                if timing_diff <= 0.1:  # Correct timing
                    color = 'green'  # Correct
                    matched_golden.add(key)
                else:
                    color = 'yellow'  # Timing error
                    matched_golden.add(key)
            
            rect = patches.Rectangle((x_start, y_pos - 0.5), x_end - x_start, 1,
                                   facecolor=color, alpha=alpha, edgecolor='black', linewidth=0.5)
            ax.add_patch(rect)
            
            # Add note label
            ax.text(x_start + (x_end - x_start)/2, y_pos, note_label, 
                   ha='center', va='center', fontsize=8, fontweight='bold')
        
        # Add missed golden notes in red
        for note in golden_notes:
            key = (note['note'], round(note['start_seconds'], 1))
            if key not in matched_golden:
                y_pos = note['note']
                x_start = note['start_seconds']
                x_end = note['end_seconds']
                note_label = self.midi_to_note_name(note['note'])
                
                rect = patches.Rectangle((x_start, y_pos - 0.5), x_end - x_start, 1,
                                       facecolor='red', alpha=0.5, edgecolor='black', linewidth=0.5)
                ax.add_patch(rect)
                ax.text(x_start + (x_end - x_start)/2, y_pos, note_label, 
                       ha='center', va='center', fontsize=8, fontweight='bold')
        
        ax.set_title(title, fontweight='bold')
        ax.set_xlabel('Time (seconds)')
        ax.set_ylabel('Note (MIDI pitch)')
        ax.grid(True, alpha=0.3)
        
        # Set reasonable y-axis limits
        all_notes = user_notes + golden_notes
        if all_notes:
            min_note = min(note['note'] for note in all_notes)
            max_note = max(note['note'] for note in all_notes)
            ax.set_ylim(min_note - 5, max_note + 5)
    
    def generate_gpt_feedback(self, analysis: Dict) -> str:
        """Generate detailed feedback using GPT-4."""
        if not self.openai_api_key:
            return self._generate_basic_feedback(analysis)
        
        try:
            prompt = self._create_feedback_prompt(analysis)
            
            from openai import OpenAI
            client = OpenAI(api_key=self.openai_api_key)
            
            response = client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": "You are a music teacher providing constructive feedback on piano performance. Be encouraging but honest about areas for improvement."},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=500,
                temperature=0.7
            )
            
            return response.choices[0].message.content or self._generate_basic_feedback(analysis)
            
        except Exception as e:
            print(f"⚠️ GPT-4 feedback failed: {e}")
            return self._generate_basic_feedback(analysis)
    
    def _create_feedback_prompt(self, analysis: Dict) -> str:
        """Create a detailed prompt for GPT-4 feedback."""
        tempo_info = analysis.get('alignment_info', {})
        tempo_ratio = analysis.get('tempo_ratio', 1.0)
        time_offset = analysis.get('time_offset', 0.0)
        
        # Convert tempo ratio to BPM difference
        if tempo_ratio > 1.0:
            tempo_feedback = f"Played {tempo_ratio:.1f}x faster than the original"
        elif tempo_ratio < 1.0:
            tempo_feedback = f"Played {1/tempo_ratio:.1f}x slower than the original"
        else:
            tempo_feedback = "Tempo matched the original well"
        
        # Convert time offset to human-readable format
        if abs(time_offset) > 0.5:
            if time_offset > 0:
                timing_feedback = f"Started {time_offset:.1f} seconds after the original"
            else:
                timing_feedback = f"Started {abs(time_offset):.1f} seconds before the original"
        else:
            timing_feedback = "Timing alignment was good"
        
        prompt = f"""
        Analyze this piano performance and provide constructive feedback:
        
        Performance Statistics:
        - Overall Accuracy: {analysis['accuracy_percentage']:.1f}%
        - Correct Notes: {analysis['correct_notes']}/{analysis['total_golden_notes']}
        - Missed Notes: {analysis['missed_notes']}
        - Extra Notes: {analysis['extra_notes']}
        - Timing Accuracy: {analysis['timing_accuracy']:.1f}%
        - Velocity Accuracy: {analysis['velocity_accuracy']:.1f}%
        
        Tempo Analysis:
        - Tempo Ratio: {tempo_ratio:.2f} (1.0 = perfect match)
        - {tempo_feedback}
        - {timing_feedback}
        
        Timing Errors: {len(analysis['timing_errors'])}
        Velocity Errors: {len(analysis['velocity_errors'])}
        
        Please provide:
        1. Overall assessment of the performance
        2. Specific feedback on tempo and timing
        3. Areas for improvement
        4. Encouraging feedback
        5. Practice suggestions
        """
        return prompt
    
    def _generate_basic_feedback(self, analysis: Dict) -> str:
        """Generate basic feedback without GPT-4."""
        tempo_ratio = analysis.get('tempo_ratio', 1.0)
        time_offset = analysis.get('time_offset', 0.0)
        
        # Get missed notes with letter names
        missed_notes_info = ""
        if 'missed_notes_details' in analysis and analysis['missed_notes_details']:
            missed_notes_info = "\nMissed Notes: " + ", ".join(analysis['missed_notes_details'])
        
        # Tempo feedback
        if tempo_ratio > 1.1:
            tempo_feedback = f"🎵 Tempo: You played {tempo_ratio:.1f}x faster than the original"
        elif tempo_ratio < 0.9:
            tempo_feedback = f"🎵 Tempo: You played {1/tempo_ratio:.1f}x slower than the original"
        else:
            tempo_feedback = "🎵 Tempo: Good tempo matching!"
        
        # Timing feedback
        if abs(time_offset) > 0.5:
            if time_offset > 0:
                timing_feedback = f"⏱️  Timing: You started {time_offset:.1f}s after the original"
            else:
                timing_feedback = f"⏱️  Timing: You started {abs(time_offset):.1f}s before the original"
        else:
            timing_feedback = "⏱️  Timing: Good timing alignment!"
        
        feedback = f"""
        🎵 Performance Analysis
        
        Overall Accuracy: {analysis['accuracy_percentage']:.1f}%
        Correct Notes: {analysis['correct_notes']}/{analysis['total_golden_notes']}
        Missed Notes: {analysis['missed_notes']}{missed_notes_info}
        Extra Notes: {analysis['extra_notes']}
        Timing Accuracy: {analysis['timing_accuracy']:.1f}%
        Velocity Accuracy: {analysis['velocity_accuracy']:.1f}%
        
        {tempo_feedback}
        {timing_feedback}
        
        Areas for Improvement:
        - Timing precision: {len(analysis['timing_errors'])} timing errors detected
        - Dynamic control: {len(analysis['velocity_errors'])} velocity errors detected
        
        Keep practicing! Focus on timing and dynamics for better performance.
        """
        return feedback
    
    def midi_to_note_name(self, midi_pitch: int) -> str:
        """Convert MIDI pitch number to letter note name."""
        note_names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
        octave = (midi_pitch // 12) - 1
        note_index = midi_pitch % 12
        return f"{note_names[note_index]}{octave}"
    
    def create_piano_roll_visualization(self, comparison_result: Dict, output_path: str):
        """Create a piano roll visualization with color-coded feedback."""
        user_notes = comparison_result['user_notes']
        golden_notes = comparison_result['golden_notes']
        analysis = comparison_result['analysis']
        
        # Create figure
        fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(15, 10))
        fig.suptitle('Piano Performance Analysis', fontsize=16, fontweight='bold')
        
        # Plot golden copy (top)
        self._plot_piano_roll(ax1, golden_notes, 'Golden Copy', 'green', alpha=0.7)
        
        # Plot user performance (bottom) with improved color coding
        self._plot_piano_roll_improved(ax2, user_notes, golden_notes, 'Your Performance', analysis)
        
        # Add simplified legend
        legend_elements = [
            patches.Patch(color='green', alpha=0.7, label='Correct Notes'),
            patches.Patch(color='red', alpha=0.7, label='Missed/Wrong Notes'),
            patches.Patch(color='yellow', alpha=0.7, label='Timing Errors')
        ]
        ax2.legend(handles=legend_elements, loc='upper right')
        
        plt.tight_layout()
        plt.savefig(output_path, dpi=300, bbox_inches='tight')
        print(f"📊 Piano roll visualization saved: {output_path}")
        
        return output_path
    
    def generate_complete_report(self, user_midi_path: str, golden_midi_path: str, 
                                output_dir: str = "generated_files") -> Dict:
        """Generate a complete comparison report with visualization and feedback."""
        print("📊 Generating complete MIDI comparison report...")
        
        os.makedirs(output_dir, exist_ok=True)
        
        # Compare MIDI files
        comparison_result = self.compare_midi_files(user_midi_path, golden_midi_path)
        
        # Generate feedback
        feedback = self.generate_gpt_feedback(comparison_result['analysis'])
        
        # Create visualization
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        viz_path = os.path.join(output_dir, f"piano_roll_analysis_{timestamp}.png")
        self.create_piano_roll_visualization(comparison_result, viz_path)
        
        # Create formatted report
        formatted_report = self._create_formatted_report(comparison_result, feedback)
        
        # Save detailed report
        report_path = os.path.join(output_dir, f"performance_report_{timestamp}.json")
        report = {
            'timestamp': timestamp,
            'user_midi_path': user_midi_path,
            'golden_midi_path': golden_midi_path,
            'analysis': comparison_result['analysis'],
            'feedback': feedback,
            'formatted_report': formatted_report,
            'visualization_path': viz_path,
            'report_path': report_path
        }
        
        with open(report_path, 'w') as f:
            json.dump(report, f, indent=2)
        
        # Save formatted report as text file
        formatted_report_path = os.path.join(output_dir, f"performance_summary_{timestamp}.txt")
        with open(formatted_report_path, 'w') as f:
            f.write(formatted_report)
        
        print(f"📄 Detailed report saved: {report_path}")
        print(f"📋 Formatted summary saved: {formatted_report_path}")
        
        return report
    
    def _create_formatted_report(self, comparison_result: Dict, feedback: str) -> str:
        """Create a nicely formatted performance report."""
        analysis = comparison_result['analysis']
        user_notes = comparison_result['user_notes']
        golden_notes = comparison_result['golden_notes']
        
        # Get missed notes with letter names
        missed_notes_info = ""
        if 'missed_notes_details' in analysis and analysis['missed_notes_details']:
            missed_notes_info = "\n   📝 Specific Missed Notes: " + ", ".join(analysis['missed_notes_details'])
        
        # Get timing errors with note names
        timing_errors_info = ""
        if analysis['timing_errors']:
            timing_note_names = [self.midi_to_note_name(error['note']) for error in analysis['timing_errors']]
            timing_errors_info = f"\n   ⏱️  Timing Issues: {', '.join(timing_note_names)}"
        
        # Get velocity errors with note names
        velocity_errors_info = ""
        if analysis['velocity_errors']:
            velocity_note_names = [self.midi_to_note_name(error['note']) for error in analysis['velocity_errors']]
            velocity_errors_info = f"\n   🎚️  Dynamic Issues: {', '.join(velocity_note_names)}"
        
        # Tempo analysis
        tempo_ratio = analysis.get('tempo_ratio', 1.0)
        time_offset = analysis.get('time_offset', 0.0)
        
        if tempo_ratio > 1.1:
            tempo_feedback = f"🎵 Tempo: You played {tempo_ratio:.1f}x faster than the original"
        elif tempo_ratio < 0.9:
            tempo_feedback = f"🎵 Tempo: You played {1/tempo_ratio:.1f}x slower than the original"
        else:
            tempo_feedback = "🎵 Tempo: Good tempo matching!"
        
        # Timing feedback
        if abs(time_offset) > 0.5:
            if time_offset > 0:
                timing_feedback = f"⏱️  Timing: You started {time_offset:.1f}s after the original"
            else:
                timing_feedback = f"⏱️  Timing: You started {abs(time_offset):.1f}s before the original"
        else:
            timing_feedback = "⏱️  Timing: Good timing alignment!"
        
        # Create formatted report
        report = f"""
╔══════════════════════════════════════════════════════════════════════════════╗
║                           🎵 GRACEAI PERFORMANCE REPORT 🎵                    ║
╚══════════════════════════════════════════════════════════════════════════════╝

📊 PERFORMANCE STATISTICS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   🎯 Overall Accuracy: {analysis['accuracy_percentage']:.1f}%
   ✅ Correct Notes: {analysis['correct_notes']}/{analysis['total_golden_notes']}
   ❌ Missed Notes: {analysis['missed_notes']}{missed_notes_info}
   ➕ Extra Notes: {analysis['extra_notes']}
   ⏱️  Timing Accuracy: {analysis['timing_accuracy']:.1f}%
   🎚️  Velocity Accuracy: {analysis['velocity_accuracy']:.1f}%

🎵 TEMPO & TIMING ANALYSIS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   {tempo_feedback}
   {timing_feedback}

🔍 DETAILED ANALYSIS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   📈 Performance Breakdown:
   • Total notes in piece: {analysis['total_golden_notes']}
   • Notes you played: {len(user_notes)}
   • Perfect matches: {analysis['correct_notes']}
   • Timing errors: {len(analysis['timing_errors'])}
   • Velocity errors: {len(analysis['velocity_errors'])}{timing_errors_info}{velocity_errors_info}

💬 AI FEEDBACK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{feedback}

🎯 PRACTICE RECOMMENDATIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   📝 Focus Areas:
   • Practice the missed notes: {', '.join(analysis.get('missed_notes_details', []))}
   • Work on timing precision for better rhythm
   • Pay attention to dynamics (loudness/softness)
   • Practice with a metronome to improve tempo consistency

   🎵 Practice Tips:
   • Start slowly and gradually increase speed
   • Practice difficult sections in isolation
   • Record yourself and listen back
   • Use the piano roll visualization to see your performance

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   📅 Report generated: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
   🎼 GraceAI Music Analysis System
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"""
        return report

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

# ============================================================================
# SHEET MUSIC PROCESSING FUNCTIONS (from heic_to_midi.py)
# ============================================================================

def check_dependencies():
    """Check if Audiveris and MuseScore are installed."""
    try:
        checker = DependencyChecker()
        all_ok, results = checker.check_all_dependencies()
        return all_ok
    except Exception as e:
        print(f"⚠️  Dependency check failed: {e}")
        return False

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
    checker = DependencyChecker()
    audiveris_installed, audiveris_path = checker.check_audiveris()
    if not audiveris_installed:
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
        
        try:
            result2 = subprocess.run(cmd2, capture_output=True, text=True, check=True)
            print("✅ Step 2 completed - MusicXML should be created")
        except subprocess.CalledProcessError as e:
            print(f"⚠️  Export command failed, trying alternative export method...")
            print(f"stdout: {e.stdout}")
            print(f"stderr: {e.stderr}")
            
            # Try alternative export command
            cmd2_alt = [
                audiveris_path,
                "-batch",
                "-export",
                "-output", output_dir,
                "-format", "musicxml",
                omr_path
            ]
            
            print(f"🔧 Trying alternative command: {' '.join(cmd2_alt)}")
            result2 = subprocess.run(cmd2_alt, capture_output=True, text=True, check=False)
            print(f"Alternative export result: {result2.returncode}")
            print(f"stdout: {result2.stdout}")
            print(f"stderr: {result2.stderr}")
        
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
    checker = DependencyChecker()
    musescore_installed, musescore_path = checker.check_musescore()
    if not musescore_installed:
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

def convert_pdf_to_jpeg(pdf_path, output_dir):
    """Convert PDF to JPEG using pdf2image."""
    try:
        from pdf2image import convert_from_path
        images = convert_from_path(pdf_path)
        jpeg_path = os.path.join(output_dir, Path(pdf_path).stem + ".jpeg")
        images[0].save(jpeg_path, 'JPEG')
        print(f"✅ Converted PDF to JPEG: {jpeg_path}")
        return jpeg_path
    except ImportError:
        print("❌ pdf2image not installed. Please install with: pip install pdf2image pillow")
        return None
    except Exception as e:
        print(f"❌ PDF conversion failed: {e}")
        return None

def convert_heic_to_jpeg(heic_path, jpeg_path):
    """Convert HEIC to JPEG using pyheif."""
    try:
        # Import inside try block to avoid linter error when pyheif not installed
        import pyheif  # type: ignore
        from PIL import Image
        heif_file = pyheif.read(heic_path)
        image = Image.frombytes(
            heif_file.mode,
            heif_file.size,
            heif_file.data,
            "raw",
            heif_file.mode,
            heif_file.stride,
        )
        image.save(jpeg_path, "JPEG")
        print(f"✅ Converted HEIC to JPEG: {jpeg_path}")
        return jpeg_path
    except ImportError:
        print("⚠️  HEIC conversion not available. Please convert HEIC to JPEG manually.")
        print("💡 Alternative: Install libheif and pyheif, or use online converters.")
        return None
    except Exception as e:
        print(f"❌ HEIC conversion failed: {e}")
        return None

def find_file_by_ext(directory, exts):
    """Find first file with given extensions in directory."""
    for file in os.listdir(directory):
        if any(file.lower().endswith(ext) for ext in exts):
            return os.path.join(directory, file)
    return None

def run_full_pipeline(audio_path=None, sheet_path=None):
    """Run the complete GraceAI pipeline."""
    print("🎵 GraceAI Full Pipeline (Audiveris + MuseScore)")
    print("=" * 50)
    print("📄 Real sheet music processing with Audiveris")
    print("🎼 MusicXML to MIDI conversion with MuseScore")
    print("=" * 50)
    
    # Check dependencies using the dependency checker
    from heic_to_midi import check_dependencies
    if not check_dependencies():
        print("❌ Required dependencies not found. Please install Audiveris and MuseScore.")
        print("💡 Run: python3 audio_transcriber/check_system_requirements.py")
        return False
    
    # Get the directory where this script is located
    script_dir = os.path.dirname(os.path.abspath(__file__))
    # Go up one level to the parent directory, then into generated_files
    output_dir = os.path.join(os.path.dirname(script_dir), "generated_files")
    os.makedirs(output_dir, exist_ok=True)
    
    # Use provided file paths or fall back to searching in generated_files
    if audio_path and os.path.exists(audio_path):
        user_audio = audio_path
        print(f"📱 User audio: {os.path.basename(user_audio)}")
    else:
        # Find user audio file in generated_files directory
        user_audio = find_file_by_ext(output_dir, ['.m4a', '.wav', '.mp3'])
        if not user_audio:
            print("❌ No user audio file found in generated_files/")
            print("💡 Please add an audio file (.m4a, .wav, .mp3) to the generated_files/ directory")
            return False
        print(f"📱 User audio: {os.path.basename(user_audio)}")
    
    if sheet_path and os.path.exists(sheet_path):
        sheet_music = sheet_path
        print(f"📄 Sheet music: {os.path.basename(sheet_music)}")
    else:
        # Find sheet music file in generated_files directory
        sheet_music = find_file_by_ext(output_dir, ['.pdf'])
        if not sheet_music:
            # Fallback to other formats
            sheet_music = find_file_by_ext(output_dir, ['.jpeg', '.jpg', '.png', '.heic'])
            if not sheet_music:
                print("❌ No sheet music file found in generated_files/")
                print("💡 Please add a sheet music file (.pdf, .jpeg, .jpg, .png, .heic) to the generated_files/ directory")
                return False
        print(f"📄 Sheet music: {os.path.basename(sheet_music)}")
    
    # Convert PDF/HEIC to JPEG if needed
    if sheet_music.lower().endswith('.pdf'):
        print(f"\n📄 Converting PDF to JPEG...")
        jpeg_path = convert_pdf_to_jpeg(sheet_music, output_dir)
        if not jpeg_path:
            return False
        sheet_music = jpeg_path
    elif sheet_music.lower().endswith('.heic'):
        print(f"\n📱 Converting HEIC to JPEG...")
        jpeg_path = os.path.join(output_dir, Path(sheet_music).stem + ".jpeg")
        jpeg_path = convert_heic_to_jpeg(sheet_music, jpeg_path)
        if not jpeg_path:
            return False
        sheet_music = jpeg_path
    

    

    
    # Step 1: Transcribe user audio using transcriber.py
    print("\n📱 Step 1: Transcribing user audio...")
    try:
        from transcriber import transcribe_audio
        user_midi = transcribe_audio(user_audio, output_dir)
        if not user_midi or not os.path.exists(user_midi):
            print("❌ Audio transcription failed - no MIDI file created")
            return False
        print(f"✅ User MIDI created: {os.path.basename(user_midi)}")
    except Exception as e:
        print(f"❌ Audio transcription failed: {e}")
        return False
    
    # Step 2: Process sheet music using heic_to_midi.py
    print("\n📄 Step 2: Processing sheet music with Audiveris + MuseScore...")
    try:
        from heic_to_midi import jpeg_to_midi_pipeline
        results = jpeg_to_midi_pipeline(sheet_music, output_dir)
        golden_midi = results.get('midi')
        if not golden_midi or not os.path.exists(golden_midi):
            print("❌ Sheet music processing failed - no MIDI file created")
            print("💡 This might be due to image quality or complexity. Try a clearer image.")
            return False
        print(f"✅ Golden copy MIDI created: {os.path.basename(golden_midi)}")
    except Exception as e:
        print(f"❌ Sheet music processing failed: {e}")
        return False
    
    # Step 3: Compare MIDI files using local MIDIComparator
    print("\n📊 Step 3: Comparing MIDI files...")
    try:
        # Use the local MIDIComparator class defined in this file
        api_key = os.getenv('OPENAI_API_KEY')
        print(f"🔑 API Key available: {'Yes' if api_key else 'No'}")
        comparator = MIDIComparator(openai_api_key=api_key)
        report = comparator.generate_complete_report(user_midi, golden_midi, output_dir)
        
        if report.get('visualization_path'):
            print(f"✅ Piano roll visualization: {os.path.basename(report['visualization_path'])}")
        if report.get('report_path'):
            print(f"✅ Performance report: {os.path.basename(report['report_path'])}")
        if report.get('feedback'):
            print(f"💬 AI Feedback: {report['feedback'][:200]}...")
            
    except Exception as e:
        print(f"❌ Comparison failed: {e}")
        return False
    
    print("\n🎉 Full pipeline completed successfully!")
    return True

def main():
    """Main function to run the GraceAI pipeline."""
    print("🎵 Welcome to GraceAI Full Pipeline!")
    print("=" * 50)
    print("📄 Real sheet music processing with Audiveris")
    print("🎼 MusicXML to MIDI conversion with MuseScore")
    print("📱 Audio transcription with Basic Pitch")
    print("📊 Smart MIDI comparison with tempo detection")
    print("=" * 50)
    
    success = run_full_pipeline()
    if success:
        print("\n🎉 Success! All steps completed.")
        print("📊 Check generated_files/ for all output files:")
        print("   - *_userRecording.mid (your performance)")
        print("   - *_goldencopy.mid (sheet music)")
        print("   - piano_roll_comparison.png (visualization)")
        print("   - performance_report.json (detailed analysis)")
    else:
        print("\n❌ Pipeline failed. See errors above.")

if __name__ == "__main__":
    main() 