#!/bin/bash

# GraceAI Backend Switcher
# This script helps you switch between local and cloud backend

CONTENT_VIEW_PATH="/Users/darshsenthil/Documents/TuneIn Cursor/TuneIn Cursor/TuneIn Cursor/ContentView.swift"

echo "🔄 GraceAI Backend Switcher"
echo "=========================="
echo ""

if [ "$1" = "local" ]; then
    echo "🏠 Switching to LOCAL backend..."
    sed -i '' 's/static let useLocalBackend = false/static let useLocalBackend = true/' "$CONTENT_VIEW_PATH"
    echo "✅ Switched to local backend (http://localhost:8000)"
    echo ""
    echo "🚀 To start local backend, run:"
    echo "   cd '/Users/darshsenthil/Documents/TuneIn Cursor/TuneIn-Cursor-New/backend'"
    echo "   ./run-local.sh"
    
elif [ "$1" = "cloud" ]; then
    echo "☁️ Switching to CLOUD backend..."
    sed -i '' 's/static let useLocalBackend = true/static let useLocalBackend = false/' "$CONTENT_VIEW_PATH"
    echo "✅ Switched to cloud backend (AWS ECS)"
    
else
    echo "Usage: $0 [local|cloud]"
    echo ""
    echo "Commands:"
    echo "  local  - Switch to local backend (http://localhost:8000)"
    echo "  cloud  - Switch to cloud backend (AWS ECS)"
    echo ""
    echo "Current configuration:"
    if grep -q "static let useLocalBackend = true" "$CONTENT_VIEW_PATH"; then
        echo "  🏠 Currently set to LOCAL backend"
    else
        echo "  ☁️ Currently set to CLOUD backend"
    fi
fi
