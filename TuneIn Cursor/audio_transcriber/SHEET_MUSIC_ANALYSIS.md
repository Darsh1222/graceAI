# Sheet Music Analysis Feature

## Overview

The sheet music analysis feature allows users to see their performance visualized directly on the sheet music with color-coded notes.

## Color Coding System

### 🟢 Green - Correct Notes
- Notes that were played correctly
- Matches the sheet music exactly
- Shows user's successful performance

### 🔴 Red - Missed Notes  
- Notes that should have been played but weren't
- From the `missedNotes` array in analysis results
- Shows what the user needs to practice

### 🟡 Yellow - Extra Notes
- Notes that were played but not in the sheet music
- Notes that shouldn't have been played
- Shows user's mistakes

## Implementation

### 1. SheetMusicView.swift
- **PDFKitView**: Displays the sheet music PDF
- **NoteOverlayView**: Renders colored overlays on notes
- **NotePosition**: Data model for note locations and colors

### 2. Integration with ResultsView
- Added `SheetMusicButton` to results screen
- Shows legend and preview of color coding
- Opens full sheet music analysis in modal

### 3. Data Flow
```
Analysis Result → Note Positions → Color Overlays → Visual Display
```

## Current Implementation (Simplified)

### Note Position Generation
Currently uses hardcoded positions for demonstration:

```swift
private func generateNotePositions() {
    notePositions = [
        // Correct notes (green)
        NotePosition(noteName: "C4", x: 0.1, y: 0.2, width: 0.05, height: 0.03, isCorrect: true, isMissed: false, isExtra: false),
        
        // Missed notes (red) - from analysis result
        NotePosition(noteName: "C4", x: 0.7, y: 0.2, width: 0.05, height: 0.03, isCorrect: false, isMissed: true, isExtra: false),
        
        // Extra notes (yellow)
        NotePosition(noteName: "F#4", x: 0.8, y: 0.2, width: 0.05, height: 0.03, isCorrect: false, isMissed: false, isExtra: true),
    ]
}
```

## Future Enhancements

### 1. Real Note Detection
```swift
class NoteDetector {
    static func detectNotes(from image: UIImage) -> [NotePosition] {
        // Use computer vision to detect actual note positions
        // OCR for note names and positions
        // Machine learning for note recognition
    }
}
```

### 2. Integration with MuseScore/Audiveris
```python
# In your Flask backend
def extract_note_positions(sheet_music_path):
    # Use MuseScore to extract note positions
    # Return JSON with note coordinates
    return {
        "notes": [
            {"name": "C4", "x": 0.1, "y": 0.2, "width": 0.05, "height": 0.03},
            {"name": "D4", "x": 0.15, "y": 0.2, "width": 0.05, "height": 0.03},
        ]
    }
```

### 3. Real-time Analysis
```swift
// Match detected notes with analysis results
func matchNotesWithAnalysis(
    detectedNotes: [NotePosition],
    analysisResult: AnalysisResult
) -> [NotePosition] {
    // Compare detected notes with correct/missed/extra notes
    // Return color-coded note positions
}
```

## User Experience

### 1. Results Screen
- User sees "Sheet Music Analysis" button
- Shows legend: Green (Correct), Red (Missed), Yellow (Extra)
- Click "View" to open full analysis

### 2. Sheet Music View
- Full-screen PDF display of sheet music
- Color-coded note overlays
- Note names displayed above each note
- Analysis summary at bottom

### 3. Interactive Features
- Toggle legend on/off
- Zoom and pan sheet music
- Tap notes for detailed information

## Technical Requirements

### iOS App
- **PDFKit**: For displaying sheet music
- **SwiftUI**: For UI components
- **Core Graphics**: For overlay rendering

### Backend Integration
- **Note Position API**: Extract note positions from sheet music
- **Analysis Matching**: Match detected notes with performance analysis
- **File Storage**: Store note position data

## Example Usage

### 1. User Records Performance
```swift
// User records audio and uploads sheet music
let audioURL = recordAudio()
let sheetMusicURL = uploadSheetMusic()
```

### 2. Backend Analysis
```python
# Flask backend processes files
result = analyze_performance(audio_file, sheet_music_file)
note_positions = extract_note_positions(sheet_music_file)
return {
    "analysis": result,
    "note_positions": note_positions
}
```

### 3. Display Results
```swift
// iOS app displays color-coded sheet music
SheetMusicView(
    sheetMusicURL: sheetMusicURL,
    analysisResult: analysisResult,
    notePositions: notePositions
)
```

## Benefits

### For Users
- **Visual Feedback**: See exactly which notes were wrong
- **Practice Focus**: Know exactly what to practice
- **Progress Tracking**: Visual improvement over time

### For Learning
- **Immediate Feedback**: Instant visual analysis
- **Pattern Recognition**: See common mistakes
- **Motivation**: Visual progress indicators

## Next Steps

1. **Implement Real Note Detection**
   - Use computer vision libraries
   - Train ML model for note recognition
   - Integrate with MuseScore API

2. **Enhance User Interface**
   - Add zoom and pan controls
   - Interactive note highlighting
   - Animated transitions

3. **Add Advanced Features**
   - Tempo visualization
   - Timing markers
   - Practice suggestions overlay

This feature transforms your app from simple text feedback to a comprehensive visual learning tool! 