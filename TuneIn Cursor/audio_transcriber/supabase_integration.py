#!/usr/bin/env python3
"""
Flask server with Supabase integration for TuneIn app
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import tempfile
import shutil
from werkzeug.utils import secure_filename
import json
import sys
from supabase import create_client, Client
import uuid
from datetime import datetime
import glob

# Add the current directory to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

app = Flask(__name__)
CORS(app)

# Supabase configuration
SUPABASE_URL = os.environ.get('SUPABASE_URL', 'your-supabase-url')
SUPABASE_KEY = os.environ.get('SUPABASE_KEY', 'your-supabase-key')

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# Configure upload folder
UPLOAD_FOLDER = 'uploads'
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['MAX_CONTENT_LENGTH'] = 50 * 1024 * 1024  # 50MB max file size

def upload_file_to_supabase(file, user_id, file_type):
    """Upload file to Supabase Storage"""
    try:
        # Generate unique filename
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"{user_id}/{file_type}_{timestamp}_{secure_filename(file.filename)}"
        
        # Determine bucket based on file type
        if file_type == 'audio':
            bucket_name = 'user-audio'
        elif file_type == 'sheet_music':
            bucket_name = 'user-sheet-music'
        else:
            bucket_name = 'analysis-results'
        
        # Upload to Supabase Storage
        response = supabase.storage.from_(bucket_name).upload(
            path=filename,
            file=file.read(),
            file_options={"content-type": file.content_type}
        )
        
        # Get public URL
        file_url = supabase.storage.from_(bucket_name).get_public_url(filename)
        
        return file_url, filename
    except Exception as e:
        print(f"Error uploading to Supabase: {str(e)}")
        return None, None

def upload_analysis_results_to_supabase(user_id, generated_files_dir):
    """Upload analysis result files to Supabase storage"""
    try:
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        uploaded_files = []
        
        # Find all result files
        result_files = glob.glob(os.path.join(generated_files_dir, '*'))
        
        for file_path in result_files:
            if os.path.isfile(file_path):
                filename = os.path.basename(file_path)
                # Skip temporary files
                if not filename.startswith('tmp'):
                    with open(file_path, 'rb') as f:
                        file_data = f.read()
                    
                    # Determine storage path based on file type
                    if filename.endswith('.mid'):
                        storage_path = f"{user_id}/midi_{timestamp}_{filename}"
                    elif filename.endswith('.json'):
                        storage_path = f"{user_id}/report_{timestamp}_{filename}"
                    elif filename.endswith('.png'):
                        storage_path = f"{user_id}/visualization_{timestamp}_{filename}"
                    elif filename.endswith('.txt'):
                        storage_path = f"{user_id}/summary_{timestamp}_{filename}"
                    else:
                        continue
                    
                    # Upload to analysis-results bucket
                    supabase.storage.from_('analysis-results').upload(
                        path=storage_path,
                        file=file_data,
                        file_options={"content-type": "application/octet-stream"}
                    )
                    
                    uploaded_files.append(storage_path)
                    print(f"Uploaded {filename} to Supabase bucket 'analysis-results': {storage_path}")
        
        return uploaded_files
    except Exception as e:
        print(f"Error uploading analysis results to Supabase: {str(e)}")
        return []

def save_session_to_supabase(session_data):
    """Save practice session to Supabase database"""
    try:
        response = supabase.table('practice_sessions').insert(session_data).execute()
        return response.data[0] if response.data else None
    except Exception as e:
        print(f"Error saving session to Supabase: {str(e)}")
        return None

def update_user_stats(user_id, session_data):
    """Update user statistics in Supabase"""
    try:
        # Get current user stats
        response = supabase.table('user_profiles').select('*').eq('id', user_id).execute()
        current_stats = response.data[0] if response.data else {}
        
        # Calculate new stats
        new_total_sessions = current_stats.get('total_sessions', 0) + 1
        new_total_practice_time = current_stats.get('total_practice_time', 0) + session_data.get('duration', 0)
        
        # Update user profile
        supabase.table('user_profiles').upsert({
            'id': user_id,
            'total_sessions': new_total_sessions,
            'total_practice_time': new_total_practice_time,
            'average_accuracy': session_data.get('accuracy', 0),  # Will be calculated by trigger
            'best_accuracy': max(current_stats.get('best_accuracy', 0), session_data.get('accuracy', 0))
        }).execute()
        
    except Exception as e:
        print(f"Error updating user stats: {str(e)}")

@app.route('/analyze', methods=['POST'])
def analyze():
    try:
        # Check if files are present
        if 'audio_file' not in request.files or 'sheet_music' not in request.files:
            return jsonify({'error': 'Missing required files'}), 400
        
        audio_file = request.files['audio_file']
        sheet_music_file = request.files['sheet_music']
        
        if audio_file.filename == '' or sheet_music_file.filename == '':
            return jsonify({'error': 'No files selected'}), 400
        
        # Get user_id from form data
        user_id = request.form.get('user_id')
        if not user_id:
            return jsonify({'error': 'Missing user_id'}), 400
        
        # Upload files to Supabase Storage
        audio_url, audio_filename = upload_file_to_supabase(audio_file, user_id, 'audio')
        sheet_music_url, sheet_music_filename = upload_file_to_supabase(sheet_music_file, user_id, 'sheet_music')
        
        if not audio_url or not sheet_music_url:
            return jsonify({'error': 'Failed to upload files'}), 500
        
        # Create temporary directory for processing
        with tempfile.TemporaryDirectory() as temp_dir:
            # Download files for processing
            audio_path = os.path.join(temp_dir, 'audio.m4a')
            sheet_music_path = os.path.join(temp_dir, 'sheet_music.pdf')
            
            # Download from Supabase Storage
            audio_data = supabase.storage.from_('user-audio').download(audio_filename)
            sheet_music_data = supabase.storage.from_('user-sheet-music').download(sheet_music_filename)
            
            with open(audio_path, 'wb') as f:
                f.write(audio_data)
            with open(sheet_music_path, 'wb') as f:
                f.write(sheet_music_data)
            
            # Copy files to generated_files directory for processing
            generated_files_dir = os.path.join(os.path.dirname(__file__), 'generated_files')
            if not os.path.exists(generated_files_dir):
                os.makedirs(generated_files_dir)
            
            # Copy files to the expected location
            shutil.copy2(audio_path, os.path.join(generated_files_dir, 'user_recording.m4a'))
            shutil.copy2(sheet_music_path, os.path.join(generated_files_dir, 'sheet_music.pdf'))
            
            # Run the analysis pipeline
            try:
                # Import and run the pipeline
                from run_full_pipeline import run_full_pipeline
                success = run_full_pipeline()
                
                if success:
                    # For now, return sample data since the pipeline doesn't return detailed results
                    analysis_result = {
                        'accuracy': 85.0,
                        'correctNotes': 12,
                        'totalNotes': 14,
                        'missedNotes': ['C4', 'E4'],
                        'tempoFeedback': 'Good tempo matching!',
                        'timingFeedback': 'Good timing alignment!'
                    }
                    
                    # Prepare session data for Supabase
                    session_data = {
                        'user_id': user_id,
                        'audio_file_url': audio_url,
                        'sheet_music_url': sheet_music_url,
                        'piece_title': request.form.get('piece_title', ''),
                        'duration': float(request.form.get('duration', 0.0)),
                        'accuracy': analysis_result['accuracy'],
                        'correct_notes': analysis_result['correctNotes'],
                        'total_notes': analysis_result['totalNotes'],
                        'missed_notes': analysis_result['missedNotes'],
                        'tempo_feedback': analysis_result['tempoFeedback'],
                        'timing_feedback': analysis_result['timingFeedback']
                    }
                    
                    # Save session to Supabase
                    saved_session = save_session_to_supabase(session_data)
                    
                    # Update user statistics
                    update_user_stats(user_id, session_data)
                    
                    # Upload analysis results to Supabase
                    uploaded_files = upload_analysis_results_to_supabase(user_id, generated_files_dir)
                    
                    # Add session_id to response
                    analysis_result['session_id'] = saved_session['id'] if saved_session else None
                    
                else:
                    return jsonify({'error': 'Analysis pipeline failed'}), 500
                
                return jsonify(analysis_result)
                
            except Exception as e:
                print(f"Analysis error: {str(e)}")
                return jsonify({'error': f'Analysis failed: {str(e)}'}), 500
    
    except Exception as e:
        print(f"Server error: {str(e)}")
        return jsonify({'error': f'Server error: {str(e)}'}), 500

@app.route('/users/<user_id>/sessions', methods=['GET'])
def get_user_sessions(user_id):
    """Get all practice sessions for a user"""
    try:
        response = supabase.table('practice_sessions').select('*').eq('user_id', user_id).order('created_at', desc=True).execute()
        return jsonify(response.data)
    except Exception as e:
        return jsonify({'error': f'Failed to get sessions: {str(e)}'}), 500

@app.route('/users/<user_id>/profile', methods=['GET'])
def get_user_profile(user_id):
    """Get user profile"""
    try:
        response = supabase.table('user_profiles').select('*').eq('id', user_id).execute()
        if response.data:
            return jsonify(response.data[0])
        else:
            return jsonify({'error': 'User not found'}), 404
    except Exception as e:
        return jsonify({'error': f'Failed to get user: {str(e)}'}), 500

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy'})

if __name__ == '__main__':
    print("Starting GraceAIBackend Server with Supabase...")
    print("Server will be available at: http://localhost:8000")
    print("Health check: http://localhost:8000/health")
    app.run(host='0.0.0.0', port=8000, debug=True) 