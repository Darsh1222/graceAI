#!/bin/bash

# GraceAI Backend - Local Development Runner
# This script sets up and runs the backend locally for development

echo "🚀 Starting GraceAI Backend locally..."

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3.9 or higher."
    exit 1
fi

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source venv/bin/activate

# Install dependencies
echo "📥 Installing dependencies..."
pip install -r requirements.txt

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p uploads
mkdir -p generated_files

# Copy local environment file
echo "⚙️ Setting up local environment..."
cp env.local .env

# Start the backend
echo "🌟 Starting backend server..."
echo "📍 Backend will be available at: http://localhost:8000"
echo "🔍 Health check: http://localhost:8000/health/"
echo "📚 API docs: http://localhost:8000/docs"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
