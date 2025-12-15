#!/usr/bin/env python3
"""
MIDI Comparison and Feedback System
Compares user performance MIDI with golden copy and provides detailed feedback.
"""

import os
import json
import subprocess
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patches as patches
from pathlib import Path
import mido
from datetime import datetime
import openai
from typing import Dict, List, Tuple, Optional

class MIDIComparator:
    """Compares two MIDI files and generates feedback."""
    
    def __init__(self, openai_api_key: Optional[str] = None):
        self.openai_api_key = openai_api_key or os.getenv('OPENAI_API_KEY')
        if self.openai_api_key:
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
            'alignment_info': {}
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
        analysis['extra_notes'] = len(user_notes) - len(matched_user)
        
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
    
    def generate_gpt_feedback(self, analysis: Dict) -> str:
        """Generate detailed feedback using GPT-4."""
        if not self.openai_api_key:
            return self._generate_basic_feedback(analysis)
        
        try:
            prompt = self._create_feedback_prompt(analysis)
            
            from openai import OpenAI
            client = OpenAI(api_key=self.openai_api_key)
            
            response = client.chat.completions.create(
                model="gpt-4",
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
        Missed Notes: {analysis['missed_notes']}
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
        
        # Plot user performance (bottom) with color coding
        self._plot_piano_roll_with_feedback(ax2, user_notes, golden_notes, 'Your Performance', analysis)
        
        # Add legend
        legend_elements = [
            patches.Patch(color='green', alpha=0.7, label='Golden Copy'),
            patches.Patch(color='blue', alpha=0.7, label='Correct Notes'),
            patches.Patch(color='red', alpha=0.7, label='Timing Errors'),
            patches.Patch(color='orange', alpha=0.7, label='Velocity Errors'),
            patches.Patch(color='purple', alpha=0.7, label='Extra Notes')
        ]
        ax2.legend(handles=legend_elements, loc='upper right')
        
        plt.tight_layout()
        plt.savefig(output_path, dpi=300, bbox_inches='tight')
        print(f"📊 Piano roll visualization saved: {output_path}")
        
        return output_path
    
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
    
    def _plot_piano_roll_with_feedback(self, ax, user_notes: List[Dict], golden_notes: List[Dict], 
                                      title: str, analysis: Dict):
        """Plot piano roll with color-coded feedback."""
        # Create a mapping of golden notes for comparison
        golden_note_map = {}
        for note in golden_notes:
            key = (note['note'], round(note['start_seconds'], 1))
            golden_note_map[key] = note
        
        for note in user_notes:
            y_pos = note['note']
            x_start = note['start_seconds']
            x_end = note['end_seconds']
            
            # Determine color based on comparison
            color = 'purple'  # Extra note (default)
            alpha = 0.7
            
            # Check if this note matches a golden note
            key = (note['note'], round(x_start, 1))
            if key in golden_note_map:
                golden_note = golden_note_map[key]
                timing_diff = abs(x_start - golden_note['start_seconds'])
                velocity_diff = abs(note['velocity'] - golden_note['velocity'])
                
                if timing_diff <= 0.1 and velocity_diff <= 10:
                    color = 'blue'  # Correct
                elif timing_diff > 0.1:
                    color = 'red'    # Timing error
                else:
                    color = 'orange'  # Velocity error
            
            rect = patches.Rectangle((x_start, y_pos - 0.5), x_end - x_start, 1,
                                   facecolor=color, alpha=alpha, edgecolor='black', linewidth=0.5)
            ax.add_patch(rect)
        
        ax.set_title(title, fontweight='bold')
        ax.set_xlabel('Time (seconds)')
        ax.set_ylabel('Note (MIDI pitch)')
        ax.grid(True, alpha=0.3)
        
        # Set reasonable y-axis limits
        if user_notes:
            min_note = min(note['note'] for note in user_notes)
            max_note = max(note['note'] for note in user_notes)
            ax.set_ylim(min_note - 5, max_note + 5)
    
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
        
        # Save detailed report
        report_path = os.path.join(output_dir, f"performance_report_{timestamp}.json")
        report = {
            'timestamp': timestamp,
            'user_midi_path': user_midi_path,
            'golden_midi_path': golden_midi_path,
            'analysis': comparison_result['analysis'],
            'feedback': feedback,
            'visualization_path': viz_path,
            'report_path': report_path
        }
        
        with open(report_path, 'w') as f:
            json.dump(report, f, indent=2)
        
        print(f"📄 Detailed report saved: {report_path}")
        
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

def main():
    """Test the MIDI comparison system."""
    # Find files dynamically by suffix
    user_midi, golden_midi = find_midi_files_by_suffix()
    
    if not user_midi:
        print("❌ No user recording MIDI found (*_userRecording.mid)")
        print("Please run the audio transcription pipeline first.")
        return
    
    if not golden_midi:
        print("❌ No golden copy MIDI found (*_goldencopy.mid)")
        print("Please run the sheet music pipeline first.")
        return
    
    print(f"🎵 Found user recording: {user_midi}")
    print(f"🎵 Found golden copy: {golden_midi}")
    
    comparator = MIDIComparator()
    
    try:
        report = comparator.generate_complete_report(user_midi, golden_midi)
        print("\n🎉 Comparison complete!")
        print(f"📊 Visualization: {report['visualization_path']}")
        print(f"📄 Report: {report['report_path']}")
        print(f"💬 Feedback: {report['feedback']}")
    except Exception as e:
        print(f"❌ Comparison failed: {e}")

if __name__ == "__main__":
    main() 