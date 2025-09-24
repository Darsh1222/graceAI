#!/usr/bin/env python3
"""
Ultra-simple GraceAI backend for local testing
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import random
from datetime import datetime

app = FastAPI(title="GraceAI Local Backend")

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health/")
async def health():
    return {
        "status": "healthy",
        "environment": "local",
        "timestamp": datetime.now().isoformat()
    }

@app.post("/analyze/")
async def analyze():
    # Simulate analysis
    await asyncio.sleep(1)
    
    total_notes = random.randint(10, 20)
    correct_notes = random.randint(8, total_notes)
    accuracy = (correct_notes / total_notes) * 100
    
    return {
        "accuracy": round(accuracy, 1),
        "correctNotes": correct_notes,
        "totalNotes": total_notes,
        "missedNotes": random.sample([
            "C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5", "D5", "E5", 
            "F5", "G5", "A5", "B5", "C6", "D6", "E6", "F6", "G6", "A6"
        ], min(total_notes - correct_notes, 20)),
        "tempoFeedback": "Good tempo!",
        "timingFeedback": "Great timing!",
        "pieceTitle": f"Session {datetime.now().strftime('%H:%M')}",
        "duration": 120.0
    }

if __name__ == "__main__":
    import asyncio
    print("🚀 Starting GraceAI Local Backend...")
    print("📍 http://localhost:8000")
    print("🔍 Health: http://localhost:8000/health/")
    uvicorn.run(app, host="0.0.0.0", port=8000)
