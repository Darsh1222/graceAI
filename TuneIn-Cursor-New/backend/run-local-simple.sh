#!/bin/bash

# GraceAI Backend - Simple Local Development Runner
# This script runs a simplified version without heavy dependencies

echo "🚀 Starting GraceAI Backend (Simple Local Version)..."

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3.9 or higher."
    exit 1
fi

# Create minimal virtual environment if it doesn't exist
if [ ! -d "venv_simple" ]; then
    echo "📦 Creating simple virtual environment..."
    python3 -m venv venv_simple
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source venv_simple/bin/activate

# Install only essential dependencies
echo "📥 Installing essential dependencies..."
pip install fastapi uvicorn python-dotenv requests pydantic

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p uploads
mkdir -p generated_files

# Copy local environment file
echo "⚙️ Setting up local environment..."
cp env.local .env

# Start the simplified backend
echo "🌟 Starting simplified backend server..."
echo "📍 Backend will be available at: http://localhost:8000"
echo "🔍 Health check: http://localhost:8000/health/"
echo "📚 API docs: http://localhost:8000/docs"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

python app/main_local.py
