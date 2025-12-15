import SwiftUI
import PDFKit

// MARK: - Note Position Model
struct NotePosition: Codable, Identifiable {
    let id: UUID
    let noteName: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let isCorrect: Bool
    let isMissed: Bool
    let isExtra: Bool
    
    init(noteName: String, x: Double, y: Double, width: Double, height: Double, isCorrect: Bool, isMissed: Bool, isExtra: Bool) {
        self.id = UUID()
        self.noteName = noteName
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.isCorrect = isCorrect
        self.isMissed = isMissed
        self.isExtra = isExtra
    }
    
    var color: Color {
        if isCorrect {
            return .green
        } else if isMissed {
            return .red
        } else if isExtra {
            return .yellow
        } else {
            return .clear
        }
    }
}

// MARK: - Sheet Music View
struct SheetMusicView: View {
    let sheetMusicURL: URL
    // let analysisResult: AnalysisResult  // Temporarily commented out due to type scope issues
    @State private var notePositions: [NotePosition] = []
    @State private var showingLegend = true
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("Sheet Music Analysis")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: { showingLegend.toggle() }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.white)
                            .font(.title2)
                            .padding(8)
                            .background(Color.purple.opacity(0.3))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                // Legend
                if showingLegend {
                    LegendView()
                        .padding(.horizontal)
                }
                
                // Sheet Music with Overlays
                ZStack {
                    // PDF Sheet Music - Placeholder for now
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .cornerRadius(12)
                        .shadow(color: Color.purple.opacity(0.3), radius: 10, x: 0, y: 5)
                        .overlay(
                            Text("PDF Sheet Music")
                                .foregroundColor(.white)
                                .font(.headline)
                        )
                    
                    // Note Overlays
                    ForEach(notePositions) { note in
                        NoteOverlayView(note: note)
                    }
                }
                .padding(.horizontal)
                
                // Analysis Summary
                // AnalysisSummaryView(analysisResult: analysisResult)  // Temporarily commented out
                //     .padding(.horizontal)
                
                Spacer()
            }
        }
        .onAppear {
            generateNotePositions()
        }
    }
    
    private func generateNotePositions() {
        // This is a simplified version - in a real implementation,
        // you'd use OCR or music recognition to detect actual note positions
        
        notePositions = [
            // Correct notes (green)
            NotePosition(noteName: "C4", x: 0.1, y: 0.2, width: 0.05, height: 0.03, isCorrect: true, isMissed: false, isExtra: false),
            NotePosition(noteName: "D4", x: 0.15, y: 0.2, width: 0.05, height: 0.03, isCorrect: true, isMissed: false, isExtra: false),
            NotePosition(noteName: "E4", x: 0.2, y: 0.2, width: 0.05, height: 0.03, isCorrect: true, isMissed: false, isExtra: false),
            NotePosition(noteName: "F4", x: 0.25, y: 0.2, width: 0.05, height: 0.03, isCorrect: true, isMissed: false, isExtra: false),
            NotePosition(noteName: "G4", x: 0.3, y: 0.2, width: 0.05, height: 0.03, isCorrect: true, isMissed: false, isExtra: false),
            NotePosition(noteName: "A4", x: 0.35, y: 0.2, width: 0.05, height: 0.03, isCorrect: true, isMissed: false, isExtra: false),
            NotePosition(noteName: "B4", x: 0.4, y: 0.2, width: 0.05, height: 0.03, isCorrect: true, isMissed: false, isExtra: false),
            NotePosition(noteName: "C5", x: 0.45, y: 0.2, width: 0.05, height: 0.03, isCorrect: true, isMissed: false, isExtra: false),
            NotePosition(noteName: "D5", x: 0.5, y: 0.2, width: 0.05, height: 0.03, isCorrect: true, isMissed: false, isExtra: false),
            NotePosition(noteName: "E5", x: 0.55, y: 0.2, width: 0.05, height: 0.03, isCorrect: true, isMissed: false, isExtra: false),
            NotePosition(noteName: "F5", x: 0.6, y: 0.2, width: 0.05, height: 0.03, isCorrect: true, isMissed: false, isExtra: false),
            NotePosition(noteName: "G5", x: 0.65, y: 0.2, width: 0.05, height: 0.03, isCorrect: true, isMissed: false, isExtra: false),
            
            // Missed notes (red) - from analysis result
            NotePosition(noteName: "C4", x: 0.7, y: 0.2, width: 0.05, height: 0.03, isCorrect: false, isMissed: true, isExtra: false),
            NotePosition(noteName: "E4", x: 0.75, y: 0.2, width: 0.05, height: 0.03, isCorrect: false, isMissed: true, isExtra: false),
            
            // Extra notes (yellow) - notes played but not in sheet music
            NotePosition(noteName: "F#4", x: 0.8, y: 0.2, width: 0.05, height: 0.03, isCorrect: false, isMissed: false, isExtra: true),
        ]
    }
}

// MARK: - PDF Kit View
// Temporarily commented out due to UIKit import issues
/*
struct PDFKitView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.backgroundColor = UIColor.white
        
        if let document = PDFDocument(url: url) {
            pdfView.document = document
        }
        
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        // Update if needed
    }
}
*/

// MARK: - Note Overlay View
struct NoteOverlayView: View {
    let note: NotePosition
    
    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 8)
                .fill(note.color.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(note.color, lineWidth: 2)
                )
                .frame(
                    width: geometry.size.width * note.width,
                    height: geometry.size.height * note.height
                )
                .position(
                    x: geometry.size.width * note.x,
                    y: geometry.size.height * note.y
                )
                .overlay(
                    Text(note.noteName)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(note.color)
                        .padding(2)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                        .position(
                            x: geometry.size.width * note.x,
                            y: geometry.size.height * (note.y - note.height/2 - 0.02)
                        )
                )
        }
    }
}

// MARK: - Legend View
struct LegendView: View {
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Note Legend")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            HStack(spacing: 20) {
                LegendItem(color: .green, text: "Correct")
                LegendItem(color: .red, text: "Missed")
                LegendItem(color: .yellow, text: "Extra")
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
}

struct LegendItem: View {
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Analysis Summary View
// Temporarily commented out due to type scope issues
/*
struct AnalysisSummaryView: View {
    let analysisResult: AnalysisResult
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Analysis Summary")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            HStack(spacing: 20) {
                SummaryItem(
                    title: "Correct",
                    value: "\(analysisResult.correctNotes)",
                    color: .green
                )
                
                SummaryItem(
                    title: "Missed",
                    value: "\(analysisResult.missedNotes.count)",
                    color: .red
                )
                
                SummaryItem(
                    title: "Accuracy",
                    value: "\(Int(analysisResult.accuracy))%",
                    color: .blue
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
}

struct SummaryItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
    }
}
*/

// MARK: - Advanced Note Detection (Future Implementation)
// Temporarily commented out due to type scope issues
/*
class NoteDetector {
    static func detectNotes(from image: UIImage) -> [NotePosition] {
        // This would use computer vision to detect actual note positions
        // For now, returning empty array
        return []
    }
    
    static func matchNotesWithAnalysis(
        detectedNotes: [NotePosition],
        analysisResult: AnalysisResult
    ) -> [NotePosition] {
        // This would match detected notes with analysis results
        // For now, returning detected notes
        return detectedNotes
    }
}
*/

// MARK: - Preview
struct SheetMusicView_Previews: PreviewProvider {
    static var previews: some View {
        SheetMusicView(
            sheetMusicURL: URL(string: "file://sample.pdf")!
        )
    }
} 
