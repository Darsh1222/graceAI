//
//  ContentView.swift
//  GraceAI
//
//  Created by Darsh Senthil on 7/17/25.
//

import GoogleSignIn
import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import Supabase

// MARK: - Backend Configuration
struct BackendConfig {
    // Toggle between local and cloud backend
    static let useLocalBackend = false // Set to true for local development
    
    static var baseURL: String {
        if useLocalBackend {
            return "http://localhost:8000"
        } else {
            return "http://tunein-backend-alb-1055077303.us-east-1.elb.amazonaws.com"
        }
    }
}

// MARK: - Supabase Configuration
struct SupabaseConfig {
    static let url = "https://cjqmnznipjwdxgqdegov.supabase.co"
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNqcW1uem5pcGp3ZHhncWRlZ292Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ1MDQ5NzEsImV4cCI6MjA3MDA4MDk3MX0.2de1-z-UxDP9EkBq4DfGSponnioTLtOy1Vy4y9lsZWg"
}

// MARK: - Supabase Service
class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    private let client: SupabaseClient
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    
    private init() {
        self.client = SupabaseClient(
            supabaseURL: URL(string: SupabaseConfig.url)!,
            supabaseKey: SupabaseConfig.anonKey
        )
        checkAuthStatus()
    }
    
    func checkAuthStatus() {
        Task {
            do {
                let session = try await client.auth.session
                await MainActor.run {
                    self.currentUser = session.user
                    self.isAuthenticated = true
                }
            } catch {
                await MainActor.run {
                    self.currentUser = nil
                    self.isAuthenticated = false
                }
            }
        }
    }
    
    func signIn(email: String, password: String) async throws -> (UserProfile, String) {
        do {
            let authResult = try await client.auth.signIn(email: email, password: password)
        await MainActor.run {
                self.currentUser = authResult.user
            self.isAuthenticated = true
        }
        
            // Try to fetch user profile from database first
            do {
                let profiles: [UserProfile] = try await client.database
                    .from("profiles")  // Use the actual profiles table
                    .select()
                    .eq("id", value: authResult.user.id.uuidString)
                    .execute()
                    .value
                
                if let dbProfile = profiles.first {
                    print("✅ Found existing profile: \(dbProfile.name)")
                    return (dbProfile, authResult.accessToken)
                }
            } catch {
                print("⚠️ Could not fetch profile from database: \(error)")
            }
            
            // Fallback to creating profile from user metadata
        let profile = UserProfile(
                id: authResult.user.id.uuidString,
            email: email,
                name: authResult.user.userMetadata["full_name"] as? String ?? 
                      authResult.user.userMetadata["name"] as? String ?? 
                      email.components(separatedBy: "@").first ?? "User",
                skillLevel: "beginner",
                instruments: []
            )
            
            return (profile, authResult.accessToken)
            
        } catch {
            // Handle specific Supabase auth errors
            let errorMessage = error.localizedDescription.lowercased()
            
            if errorMessage.contains("user not found") || 
               errorMessage.contains("email not found") ||
               errorMessage.contains("invalid login credentials") && errorMessage.contains("email") {
                throw AuthError.accountDoesNotExist
            } else if errorMessage.contains("invalid login credentials") || 
                      errorMessage.contains("wrong password") ||
                      errorMessage.contains("invalid password") {
                throw AuthError.invalidCredentials
            } else {
                throw AuthError.networkError
            }
        }
    }
    
    func signUp(email: String, password: String, name: String) async throws -> (UserProfile, String) {
        print("🔄 Starting signup for email: \(email)")
        do {
            let authResult = try await client.auth.signUp(
                email: email, 
                password: password,
                data: ["name": .string(name)]
            )
            print("✅ Supabase signup successful for user: \(authResult.user.id)")
        await MainActor.run {
                self.currentUser = authResult.user
            self.isAuthenticated = true
        }
        
            // Wait a moment for the trigger to create the profile
            print("⏳ Waiting for profile creation trigger...")
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Try to fetch the profile created by the trigger
            do {
                print("🔍 Fetching profile from database...")
                let profiles: [UserProfile] = try await client.database
                    .from("profiles")  // Use the actual profiles table
                    .select()
                    .eq("id", value: authResult.user.id.uuidString)
                    .execute()
                    .value
                
                if let dbProfile = profiles.first {
                    print("✅ Profile found in database: \(dbProfile.name)")
                    return (dbProfile, authResult.session?.accessToken ?? "")
                } else {
                    print("⚠️ No profile found in database, creating fallback...")
                }
            } catch {
                print("⚠️ Could not fetch profile from database after signup: \(error)")
            }
            
            // Fallback: create profile locally if trigger didn't work
        let profile = UserProfile(
                id: authResult.user.id.uuidString,
            email: email,
                name: name,
                skillLevel: "beginner",
                instruments: []
            )
            
            return (profile, authResult.session?.accessToken ?? "")
            
        } catch {
            // Handle specific Supabase auth errors
            let errorMessage = error.localizedDescription.lowercased()
            
            if errorMessage.contains("user already registered") || 
               errorMessage.contains("email already registered") ||
               errorMessage.contains("user already exists") {
                throw AuthError.accountAlreadyExists
            } else if errorMessage.contains("password") && errorMessage.contains("6") {
                throw AuthError.passwordTooShort
            } else if errorMessage.contains("email") && errorMessage.contains("invalid") {
                throw AuthError.invalidEmail
            } else {
                print("⚠️ Signup error details: \(error)")
                throw AuthError.signUpFailed
            }
        }
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
        await MainActor.run {
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }
    
    // MARK: - File Storage
    func uploadFile(_ data: Data, fileName: String, bucket: String = "user-audio") async throws -> String {
        let filePath = "\(currentUser?.id.uuidString ?? "anonymous")/\(fileName)"
        try await client.storage.from(bucket).upload(path: filePath, file: data)
        return filePath
    }
    
    func downloadFile(filePath: String, bucket: String = "user-audio") async throws -> Data {
        return try await client.storage.from(bucket).download(path: filePath)
    }
    
    func getPublicURL(filePath: String, bucket: String = "user-audio") -> URL? {
        return try? client.storage.from(bucket).getPublicURL(path: filePath)
    }
    
    // MARK: - Practice Sessions
    func savePracticeSession(_ session: PracticeSession) async throws {
        try await client.database
            .from("practice_sessions")
            .insert(session)
            .execute()
    }
    
    func fetchPracticeSessions() async throws -> [PracticeSession] {
        let response: [PracticeSession] = try await client.database
            .from("practice_sessions")
            .select()
            .eq("user_id", value: currentUser?.id.uuidString ?? "")
            .order("date", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    func fetchUserSessions(userId: String) async throws -> [BackendSession] {
        // Guard against empty user ID
        guard !userId.isEmpty else {
            print("⚠️ Cannot fetch sessions: user ID is empty")
            return []
        }
        
        print("🔍 Fetching sessions from 'sessions' table for user: \(userId)")
        
        let response: [BackendSession] = try await client.database
            .from("sessions")  // Read from the actual sessions table
            .select()
            .eq("user_id", value: userId)  // Use snake_case field name for database
            .order("date", ascending: false)
            .execute()
            .value
        
        print("📊 Raw response from database: \(response.count) sessions")
        return response
    }
    
    func saveSession(_ session: BackendSession) async throws {
        try await client.database
            .from("sessions")
            .insert(session)
            .execute()
    }
    
    func createUserProfile(_ profile: UserProfile) async throws {
        // Create a properly encodable profile structure
        struct DatabaseProfile: Encodable {
            let user_id: String
            let name: String
            let email: String
            let skill_level: String
            let instruments: [String]
        }
        
        let dbProfile = DatabaseProfile(
            user_id: profile.id,
            name: profile.name,
            email: profile.email,
            skill_level: profile.skillLevel,
            instruments: profile.instruments
        )
        
        try await client.database
            .from("profiles")
            .insert(dbProfile)
            .execute()
    }
}

// MARK: - Backend Service
class BackendService: ObservableObject {
    @Published var progressMessage = "Initializing analysis..."
    private let supabaseService = SupabaseService.shared
    
    func analyzePerformance(audioURL: URL, sheetMusicURL: URL, userId: String, appState: AppState) async throws -> (authResult: AnalysisResult, audioURL: String, sheetMusicURL: String) {
        print("🎵 BackendService: Starting analysis...")
        
        await MainActor.run {
            progressMessage = "Uploading files to Supabase..."
        }
        
        let audioData = try Data(contentsOf: audioURL)
        let sheetMusicData = try Data(contentsOf: sheetMusicURL)
        
        let audioFileName = "audio_\(UUID().uuidString).m4a"
        let sheetMusicFileName = "sheet_\(UUID().uuidString).pdf"
        
        let audioPath = try await supabaseService.uploadFile(audioData, fileName: audioFileName, bucket: "user-audio")
        let sheetMusicPath = try await supabaseService.uploadFile(sheetMusicData, fileName: sheetMusicFileName, bucket: "user-sheet-music")
        
        // Get the public URLs for the uploaded files
        guard let audioURL = supabaseService.getPublicURL(filePath: audioPath, bucket: "user-audio"),
              let sheetMusicURL = supabaseService.getPublicURL(filePath: sheetMusicPath, bucket: "user-sheet-music") else {
            throw BackendError.networkError
        }
        
        await MainActor.run {
            progressMessage = "Analyzing performance..."
        }
        
        let authResult = try await callAnalyzeEndpoint(audioPath: audioURL.absoluteString, sheetMusicPath: sheetMusicURL.absoluteString)
        
        await MainActor.run {
            progressMessage = "Analysis complete!"
        }
        
        return (authResult: authResult, audioURL: audioPath, sheetMusicURL: sheetMusicPath)
    }
    
    private func callAnalyzeEndpoint(audioPath: String, sheetMusicPath: String) async throws -> AnalysisResult {
        let url = URL(string: "\(BackendConfig.baseURL)/analyze/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = [
            "audio_url": audioPath,
            "sheet_music_url": sheetMusicPath
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.networkError
        }
        
        if httpResponse.statusCode == 200 {
            let analysisResult = try JSONDecoder().decode(AnalysisResult.self, from: data)
            return analysisResult
        } else {
            print("❌ Backend returned status: \(httpResponse.statusCode)")
            if let errorData = String(data: data, encoding: .utf8) {
                print("❌ Backend error: \(errorData)")
            }
            throw BackendError.serverError
        }
    }
}

// MARK: - Backend Models
struct UploadResponse: Codable {
    let filename: String
    let message: String
}

struct AnalysisResult: Codable {
    let accuracy: Double
    let correctNotes: Int
    let totalNotes: Int
    let totalUserNotes: Int
    let missedNotes: [String]
    let extraNotes: [String]
    let allSheetNotes: [String]
    let allAudioNotes: [String]
    let overallFeedback: String
    let tips: [String]
    let rhythmicAnalysis: RhythmicAnalysis
    let pieceTitle: String
    let duration: Double
    let analysisMethod: String
    let toolsUsed: ToolsUsed
}

struct RhythmicAnalysis: Codable {
    let tempoAccuracy: Double
    let timingAccuracy: Double
    let rhythmicFeedback: String
    let timingAnalysis: String
    let rhythmErrors: [RhythmError]
}

struct RhythmError: Codable {
    let timestamp: Double
    let expectedNote: String
    let actualNote: String
    let severity: String
}

struct ToolsUsed: Codable {
    let audioProcessing: String
    let sheetMusicAnalysis: String
    let comparison: String
    let rhythmAnalysis: String
}

enum BackendError: Error, LocalizedError {
    case networkError
    case serverError
    case invalidResponse
    case fileUploadError
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network connection error"
        case .serverError:
            return "Server error occurred"
        case .invalidResponse:
            return "Invalid response from server"
        case .fileUploadError:
            return "File upload failed"
        }
    }
}

// MARK: - Data Manager
class DataManager: ObservableObject {
    @Published var practiceSessions: [PracticeSession] = []
    @Published var userProfile: UserProfile?
    
    private let userDefaults = UserDefaults.standard
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private let supabaseService = SupabaseService.shared
    
    init() {
        loadData()
    }
    
    func saveUserProfile(_ profile: UserProfile) {
        userProfile = profile
        if let encoded = try? JSONEncoder().encode(profile) {
            userDefaults.set(encoded, forKey: "userProfile")
        }
    }
    
    func loadUserProfile() -> UserProfile? {
        if let userData = userDefaults.data(forKey: "userProfile"),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: userData) {
            userProfile = profile
            return profile
        }
        return nil
    }
    
    func savePracticeSession(_ session: PracticeSession) {
        practiceSessions.append(session)
        saveSessionsToDisk()
        updateUserStats()
        
        Task {
            do {
                try await supabaseService.saveSession(session.toBackendSession())
                print("✅ Practice session saved to Supabase")
            } catch {
                print("❌ Failed to save practice session to Supabase: \(error)")
            }
        }
    }
    
    func loadSessionsFromDisk() {
        let sessionsURL = documentsPath.appendingPathComponent("practice_sessions.json")
        if let data = try? Data(contentsOf: sessionsURL),
           let sessions = try? JSONDecoder().decode([PracticeSession].self, from: data) {
            practiceSessions = sessions
        }
    }
    
    func saveSessionsToDisk() {
        let sessionsURL = documentsPath.appendingPathComponent("practice_sessions.json")
        if let data = try? JSONEncoder().encode(practiceSessions) {
            try? data.write(to: sessionsURL)
        }
    }
    
    func saveAudioFile(_ audioURL: URL) -> String {
        let fileName = "audio_\(Date().timeIntervalSince1970).m4a"
        let destinationURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: audioURL, to: destinationURL)
            return fileName
        } catch {
            print("Error saving audio file: \(error)")
            return ""
        }
    }
    
    func saveSheetMusicFile(_ fileURL: URL) -> String {
        let fileName = "sheet_music_\(Date().timeIntervalSince1970).\(fileURL.pathExtension)"
        let destinationURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: fileURL, to: destinationURL)
            return fileName
        } catch {
            print("Error saving sheet music file: \(error)")
            return ""
        }
    }
    
    func getFileURL(for fileName: String) -> URL? {
        let fileURL = documentsPath.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }
    
    func updateUserStats() {
        guard var profile = userProfile else { return }
        
        profile.totalSessions = practiceSessions.count
        profile.totalPracticeTime = practiceSessions.reduce(0) { $0 + $1.duration }
        
        if !practiceSessions.isEmpty {
            profile.averageAccuracy = practiceSessions.reduce(0) { $0 + $1.accuracy } / Double(practiceSessions.count)
            profile.bestAccuracy = practiceSessions.map { $0.accuracy }.max() ?? 0.0
        }
        
        let sortedSessions = practiceSessions.sorted { $0.date > $1.date }
        var streak = 0
        let calendar = Calendar.current
        var currentDate = Date()
        
        for session in sortedSessions {
            if calendar.isDate(session.date, inSameDayAs: currentDate) {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        } else {
                break
            }
        }
        
        profile.currentStreak = streak
        saveUserProfile(profile)
    }
    
    func loadData() {
        _ = loadUserProfile()
        loadSessionsFromDisk()
        
        Task {
            do {
                let supabaseSessions = try await supabaseService.fetchPracticeSessions()
                await MainActor.run {
                    let existingIds = Set(self.practiceSessions.map { $0.id })
                    let newSessions = supabaseSessions.filter { !existingIds.contains($0.id) }
                    self.practiceSessions.append(contentsOf: newSessions)
                    self.practiceSessions.sort { $0.date > $1.date }
                }
            } catch {
                print("❌ Failed to load practice sessions from Supabase: \(error)")
            }
        }
    }
    
    func clearAllData() {
        practiceSessions.removeAll()
        userProfile = nil
        userDefaults.removeObject(forKey: "userProfile")
        
        let fileManager = FileManager.default
        let files = try? fileManager.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
        files?.forEach { url in
            if url.lastPathComponent.hasPrefix("audio_") || url.lastPathComponent.hasPrefix("sheet_music_") {
                try? fileManager.removeItem(at: url)
            }
        }
        
        saveSessionsToDisk()
    }
}

// MARK: - User Profile Model
struct UserProfile: Codable {
    let id: String
    let email: String
    let name: String
    let skillLevel: String
    let instruments: [String]
    let practiceGoals: [String]
    var totalSessions: Int
    var totalPracticeTime: TimeInterval
    var averageAccuracy: Double
    let favoriteGenres: [String]
    let createdAt: Date
    let updatedAt: Date
    var currentStreak: Int
    var bestAccuracy: Double
    
    init(id: String, email: String, name: String, skillLevel: String = "beginner", instruments: [String] = [], practiceGoals: [String] = []) {
        self.id = id
        self.email = email
        self.name = name
        self.skillLevel = skillLevel
        self.instruments = instruments
        self.practiceGoals = practiceGoals
        self.totalSessions = 0
        self.totalPracticeTime = 0
        self.averageAccuracy = 0.0
        self.favoriteGenres = []
        self.createdAt = Date()
        self.updatedAt = Date()
        self.currentStreak = 0
        self.bestAccuracy = 0.0
    }
}

// MARK: - Practice Session Model
struct PracticeSession: Codable, Identifiable {
    let id: String
    let userId: String
    let date: Date
    let audioFileName: String
    let sheetMusicFileName: String
    let accuracy: Double
    let correctNotes: Int
    let totalNotes: Int
    let missedNotes: [String]
    let tempoFeedback: String
    let timingFeedback: String
    let duration: TimeInterval
    let pieceTitle: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case date
        case audioFileName = "audio_file_name"
        case sheetMusicFileName = "sheet_music_file_name"
        case accuracy
        case correctNotes = "correct_notes"
        case totalNotes = "total_notes"
        case missedNotes = "missed_notes"
        case tempoFeedback = "tempo_feedback"
        case timingFeedback = "timing_feedback"
        case duration
        case pieceTitle = "piece_title"
    }
    
    init(userId: String, audioFileName: String, sheetMusicFileName: String, analysisResult: AnalysisResult, duration: TimeInterval, pieceTitle: String? = nil) {
        self.id = UUID().uuidString
        self.userId = userId
        self.date = Date()
        self.audioFileName = audioFileName
        self.sheetMusicFileName = sheetMusicFileName
        self.accuracy = analysisResult.accuracy
        self.correctNotes = analysisResult.correctNotes
        self.totalNotes = analysisResult.totalNotes
        self.missedNotes = analysisResult.missedNotes
        self.tempoFeedback = analysisResult.rhythmicAnalysis.rhythmicFeedback
        self.timingFeedback = analysisResult.rhythmicAnalysis.timingAnalysis
        self.duration = duration
        self.pieceTitle = pieceTitle
    }
    
    func toBackendSession() -> BackendSession {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        
        return BackendSession(
            id: id,
            userId: userId,
            date: formatter.string(from: date),
            audioFileName: audioFileName,
            sheetMusicFileName: sheetMusicFileName,
            pieceTitle: pieceTitle,
            duration: duration,
            accuracy: accuracy,
            correctNotes: correctNotes,
            totalNotes: totalNotes,
            missedNotes: missedNotes,
            tempoFeedback: tempoFeedback,
            timingFeedback: timingFeedback
        )
    }
}

// MARK: - Backend Session Model
struct BackendSession: Codable, Identifiable {
    let id: String
    let userId: String
    let date: String
    let audioFileName: String?
    let sheetMusicFileName: String?
    let pieceTitle: String?
    let duration: Double?
    let accuracy: Double?
    let correctNotes: Int?
    let totalNotes: Int?
    let missedNotes: [String]?
    let tempoFeedback: String?
    let timingFeedback: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case date
        case audioFileName = "audio_file_name"
        case sheetMusicFileName = "sheet_music_file_name"
        case pieceTitle = "piece_title"
        case duration
        case accuracy
        case correctNotes = "correct_notes"
        case totalNotes = "total_notes"
        case missedNotes = "missed_notes"
        case tempoFeedback = "tempo_feedback"
        case timingFeedback = "timing_feedback"
    }
    
    var createdAt: Date {
        return DateFormatter.iso8601.date(from: date) ?? Date()
    }
    
    func toAnalysisResult() -> AnalysisResult? {
        guard let accuracy = accuracy,
              let correctNotes = correctNotes,
              let totalNotes = totalNotes else {
            return nil
        }
        
        let missedNotesArray = missedNotes ?? []
        
        let rhythmicAnalysis = RhythmicAnalysis(
            tempoAccuracy: 0.0,
            timingAccuracy: 0.0,
            rhythmicFeedback: tempoFeedback ?? "No tempo data",
            timingAnalysis: timingFeedback ?? "No timing data",
            rhythmErrors: []
        )
        
        return AnalysisResult(
            accuracy: accuracy,
            correctNotes: correctNotes,
            totalNotes: totalNotes,
            totalUserNotes: correctNotes,
            missedNotes: missedNotesArray,
            extraNotes: [],
            allSheetNotes: [],
            allAudioNotes: [],
            overallFeedback: "Historical session data",
            tips: [],
            rhythmicAnalysis: rhythmicAnalysis,
            pieceTitle: pieceTitle ?? "Unknown Piece",
            duration: duration ?? 0.0,
            analysisMethod: "Historical Data",
            toolsUsed: ToolsUsed(audioProcessing: "Unknown", sheetMusicAnalysis: "Unknown", comparison: "Unknown", rhythmAnalysis: "Unknown")
        )
    }
}

// MARK: - Error Types
enum SupabaseError: Error, LocalizedError {
    case networkError
    case serverError
    case authError(String)
    case notFound(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network connection failed"
        case .serverError:
            return "Server error occurred"
        case .authError(let message):
            return message
        case .notFound(let message):
            return message
        }
    }
}

enum AuthError: Error, LocalizedError {
    case accountDoesNotExist
    case invalidCredentials
    case networkError
    case signUpFailed
    case accountAlreadyExists
    case passwordTooShort
    case invalidEmail
    
    var errorDescription: String? {
        switch self {
        case .accountDoesNotExist:
            return "❌ Account doesn't exist. Please check your email or sign up for a new account."
        case .invalidCredentials:
            return "❌ Invalid password. Please check your password and try again."
        case .networkError:
            return "❌ Network error. Please check your connection and try again."
        case .signUpFailed:
            return "❌ Sign up failed. Please try again."
        case .accountAlreadyExists:
            return "❌ Account already exists. Please sign in instead or use a different email."
        case .passwordTooShort:
            return "❌ Password must be at least 6 characters long."
        case .invalidEmail:
            return "❌ Please enter a valid email address."
        }
    }
}

// MARK: - Date Formatter Extension
extension DateFormatter {
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return formatter
    }()
}

// MARK: - App State Management
class AppState: ObservableObject {
    @Published var currentScreen: AppScreen = .splash
    @Published var isLoggedIn = false
    @Published var dataManager = DataManager()
    @Published var isLoading = false
    @Published var currentUserId: String = ""
    @Published var supabaseAccessToken: String = ""
    
    let supabaseService = SupabaseService.shared
    
    enum AppScreen {
        case splash, onboarding, login, main
    }
    
    init() {
        generateOrRetrieveUserId()
        
        if let savedToken = UserDefaults.standard.string(forKey: "supabaseAccessToken") {
            self.supabaseAccessToken = savedToken
            print("🔑 Loaded saved access token: \(savedToken.prefix(20))...")
        } else {
            print("🔍 Debug - No saved access token found in UserDefaults")
        }
        
        checkAuthenticationStatus()
    }
    
    private func checkAuthenticationStatus() {
        if let profile = dataManager.loadUserProfile() {
            self.currentUserId = profile.id
            UserDefaults.standard.set(profile.id, forKey: "currentUserId")
            dataManager.userProfile = profile
            self.isLoggedIn = true
            self.currentScreen = .main
            print("🆔 Restored user ID from saved profile: \(self.currentUserId)")
        } else {
            self.currentScreen = .login
            self.isLoggedIn = false
        }
    }
    
    func saveUserProfile(_ profile: UserProfile) {
        self.currentUserId = profile.id
        UserDefaults.standard.set(profile.id, forKey: "currentUserId")
        dataManager.saveUserProfile(profile)
        self.isLoggedIn = true
        print("🆔 Updated current user ID to: \(self.currentUserId)")
        print("✅ User profile saved and authentication state updated")
    }
    
    func logout() {
        dataManager.clearAllData()
        self.isLoggedIn = false
        self.currentScreen = .login
        self.supabaseAccessToken = ""
        UserDefaults.standard.removeObject(forKey: "supabaseAccessToken")
        print("🔑 Cleared access token on logout")
    }
    
    func resetToSplash() {
        dataManager.clearAllData()
        self.isLoggedIn = false
        self.currentScreen = .splash
        self.supabaseAccessToken = ""
        UserDefaults.standard.removeObject(forKey: "supabaseAccessToken")
    }
    
    var userProfile: UserProfile? {
        return dataManager.userProfile
    }
    
    private func generateOrRetrieveUserId() {
        if let existingUserId = UserDefaults.standard.string(forKey: "currentUserId") {
            self.currentUserId = existingUserId
        } else {
            let uniqueUserId = "user-\(UUID().uuidString)"
            UserDefaults.standard.set(uniqueUserId, forKey: "currentUserId")
            self.currentUserId = uniqueUserId
        }
        print("🆔 Current User ID: \(self.currentUserId)")
    }
    
    func resetUserId() {
        UserDefaults.standard.removeObject(forKey: "currentUserId")
        generateOrRetrieveUserId()
        print("🔄 User ID reset to: \(self.currentUserId)")
    }
    
    func resetAppState() {
        UserDefaults.standard.removeObject(forKey: "currentUserId")
        UserDefaults.standard.removeObject(forKey: "userProfile")
        self.currentUserId = ""
        self.currentScreen = .login
        print("🔄 Complete app state reset - ready for fresh test")
    }
    
    func signInWithTestAccount() async {
        print("🧪 Signing in with test account...")
        
        UserDefaults.standard.removeObject(forKey: "currentUserId")
        
        let testUserId = "test-user-\(UUID().uuidString.prefix(8))"
        UserDefaults.standard.set(testUserId, forKey: "currentUserId")
        self.currentUserId = testUserId
        
        self.supabaseAccessToken = "test-token-\(UUID().uuidString)"
        
        print("🆔 Generated test user ID: \(self.currentUserId)")
        print("🔑 Set test access token: \(self.supabaseAccessToken.prefix(20))...")
        
        let testProfile = UserProfile(
            id: currentUserId,
            email: "test@graceai.com",
            name: "Test User"
        )
        
        saveUserProfile(testProfile)
        
        await MainActor.run {
            self.currentScreen = .main
            self.isLoggedIn = true
        }
        
        print("✅ Test account signed in successfully!")
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var appState = AppState()
    
    var body: some View {
        let _ = print("🎨 ContentView body rendered")
        let _ = print("📱 Current screen: \(appState.currentScreen)")
        Group {
            switch appState.currentScreen {
            case .splash:
                SplashScreen(appState: appState)
            case .onboarding:
                OnboardingScreen(appState: appState)
            case .login:
                LoginScreen(appState: appState)
            case .main:
                MainTabView(appState: appState)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: appState.currentScreen)
    }
}

// MARK: - Splash Screen
struct SplashScreen: View {
    @ObservedObject var appState: AppState
    @State private var animateIcon = false
    @State private var showText = false
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                VStack(spacing: 20) {
                    Image(systemName: "music.note.list")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.purple)
                        .shadow(color: Color.purple.opacity(0.5), radius: 15, x: 0, y: 8)
                        .scaleEffect(animateIcon ? 1.2 : 0.8)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animateIcon)
                    
                    if showText {
                        VStack(spacing: 8) {
                            Text("GraceAI")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Your AI Music Learning Companion")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                
                Spacer()
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                    .scaleEffect(1.2)
            }
        }
        .onAppear {
            animateIcon = true
            
            withAnimation(.easeInOut(duration: 0.8).delay(0.5)) {
                showText = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation {
                    appState.currentScreen = .onboarding
                }
            }
        }
    }
}

// MARK: - Onboarding Screen
struct OnboardingScreen: View {
    @ObservedObject var appState: AppState
    @State private var currentPage = 0
    
    let onboardingPages = [
        OnboardingPage(
            icon: "music.note.list",
            title: "AI-Powered Analysis",
            description: "Get instant feedback on your piano performance with advanced AI technology"
        ),
        OnboardingPage(
            icon: "chart.bar.fill",
            title: "Detailed Insights",
            description: "See exactly which notes you missed and get specific practice recommendations"
        ),
        OnboardingPage(
            icon: "person.fill.checkmark",
            title: "Track Progress",
            description: "Monitor your improvement over time with detailed performance analytics"
        )
    ]
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    ForEach(0..<onboardingPages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.purple : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 50)
                
                Spacer()
                
                TabView(selection: $currentPage) {
                    ForEach(0..<onboardingPages.count, id: \.self) { index in
                        OnboardingPageView(page: onboardingPages[index])
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                Spacer()
                
                HStack {
                    if currentPage > 0 {
                                            Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(12)
                    }
                    
                    Spacer()
                    
                    Button(currentPage == onboardingPages.count - 1 ? "Get Started" : "Next") {
                        if currentPage == onboardingPages.count - 1 {
                            withAnimation {
                                appState.currentScreen = .login
                            }
                        } else {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.purple)
                    .cornerRadius(12)
                    .shadow(color: Color.purple.opacity(0.5), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 50)
            }
        }
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundColor(.purple)
                .shadow(color: Color.purple.opacity(0.3), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(page.description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 40)
            }
        }
        .padding()
    }
}

// MARK: - Login Screen
struct LoginScreen: View {
    @ObservedObject var appState: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var isSignUp = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    
    var body: some View {
        ZStack {
            backgroundGradient
            
            ScrollView {
                VStack(spacing: 30) {
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 60))
                            .foregroundColor(.purple)
                        
                        Text("Welcome to GraceAI")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(isSignUp ? "Create your account" : "Sign in to continue")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .animation(.easeInOut(duration: 0.3), value: isSignUp)
                    }
                    .padding(.top, 60)
                    
                    VStack(spacing: 20) {
                        VStack(spacing: 16) {
                            CustomTextField(
                                text: $email,
                                placeholder: "Email",
                                icon: "envelope.fill"
                            )
                            
                            if isSignUp {
                                CustomTextField(
                                    text: $name,
                                    placeholder: "Full Name",
                                    icon: "person.fill"
                                )
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .top)),
                                    removal: .opacity.combined(with: .move(edge: .top))
                                ))
                            }
                            
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.purple.opacity(0.7))
                                    .frame(width: 20)
                                
                                ZStack(alignment: .leading) {
                                    if password.isEmpty {
                                        Text("Password")
                                            .foregroundColor(.white.opacity(0.6))
                                            .font(.body)
                                    }
                                    
                                    if showPassword {
                                        TextField("", text: $password)
                                            .foregroundColor(.white)
                                            .accentColor(.purple)
                                    } else {
                                        SecureField("", text: $password)
                                            .foregroundColor(.white)
                                            .accentColor(.purple)
                                    }
                                }
                                
                                Button(action: { showPassword.toggle() }) {
                                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.purple.opacity(0.7))
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(12)
                            
                            if isSignUp {
                                HStack {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.purple.opacity(0.7))
                                        .frame(width: 20)
                                    
                                    ZStack(alignment: .leading) {
                                        if confirmPassword.isEmpty {
                                            Text("Confirm Password")
                                                .foregroundColor(.white.opacity(0.6))
                                                .font(.body)
                                        }
                                        
                                        if showConfirmPassword {
                                            TextField("", text: $confirmPassword)
                                                .foregroundColor(.white)
                                                .accentColor(.purple)
                                        } else {
                                            SecureField("", text: $confirmPassword)
                                                .foregroundColor(.white)
                                                .accentColor(.purple)
                                        }
                                    }
                                    
                                    Button(action: { showConfirmPassword.toggle() }) {
                                        Image(systemName: showConfirmPassword ? "eye.slash.fill" : "eye.fill")
                                            .foregroundColor(.purple.opacity(0.7))
                                    }
                                }
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(12)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .top)),
                                    removal: .opacity.combined(with: .move(edge: .top))
                                ))
                            }
                        }
                        
                        Button(action: {
                            print("🔘 Auth button pressed!")
                            handleAuth()
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                if isSignUp {
                                    Image(systemName: "person.badge.plus")
                                } else {
                                    Image(systemName: "arrow.right")
                                }
                                }
                                Text(isSignUp ? (isLoading ? "Creating Account..." : "Create Account") : (isLoading ? "Signing In..." : "Sign In"))
                                    .fontWeight(.semibold)
                                    .animation(.easeInOut(duration: 0.3), value: isSignUp)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isLoading ? Color.gray : Color.purple)
                            .cornerRadius(12)
                            .shadow(color: Color.purple.opacity(0.5), radius: 10, x: 0, y: 5)
                        }
                        .disabled(isLoading)
                        
                        Button(action: { 
                            withAnimation(.easeInOut(duration: 0.4)) {
                                isSignUp.toggle()
                            }
                            email = ""
                            password = ""
                            confirmPassword = ""
                            name = ""
                            showPassword = false
                            showConfirmPassword = false
                        }) {
                            Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.subheadline)
                                .animation(.easeInOut(duration: 0.3), value: isSignUp)
                        }
                        
                        VStack(spacing: 16) {
                            Text("Or continue with")
                                .foregroundColor(.white.opacity(0.6))
                                .font(.subheadline)
                            
                            Button(action: {
                                print("🔘 Google Sign-In button pressed!")
                                signInWithGoogle()
                            }) {
                                HStack {
                                    Image(systemName: "globe")
                                        .font(.title3)
                                    Text("Continue with Google")
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                print("🧪 Test Account Sign-In button pressed!")
                                Task {
                                    await appState.signInWithTestAccount()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .font(.title3)
                                    Text("Sign in with Test Account")
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                print("🔄 Reset App State button pressed!")
                                appState.resetAppState()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                        .font(.title3)
                                    Text("Reset App State")
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.8))
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.top, 20)
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer()
                }
            }
        }
        .alert("Authentication", isPresented: $showingAlert) {
            Button("OK") { }
            if alertMessage.contains("No account found") || alertMessage.contains("already exists") {
                Button(isSignUp ? "Switch to Sign In" : "Switch to Sign Up") {
                    isSignUp.toggle()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func handleAuth() {
        print("🔐 handleAuth() called")
        
        if email.isEmpty || password.isEmpty {
            alertMessage = "❌ Please fill in all fields"
            showingAlert = true
            return
        }
        
        if isSignUp && name.isEmpty {
            alertMessage = "📝 Please enter your full name"
            showingAlert = true
            return
        }
        
        if !isValidEmail(email) {
            alertMessage = "📧 Please enter a valid email address"
            showingAlert = true
            return
        }
        
        if password.count < 6 {
            alertMessage = "🔒 Password must be at least 6 characters"
            showingAlert = true
            return
        }
        
        if isSignUp && password != confirmPassword {
            alertMessage = "🔒 Passwords do not match"
            showingAlert = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let profile: UserProfile
                
                if isSignUp {
                    let (userProfile, accessToken) = try await appState.supabaseService.signUp(email: email, password: password, name: name)
                    profile = userProfile
                    
                    // Note: Profile creation is handled by Supabase trigger automatically
                    // No need to manually create profile - this was causing the database error
                    
                    await MainActor.run {
                        self.appState.supabaseAccessToken = accessToken
                        UserDefaults.standard.set(accessToken, forKey: "supabaseAccessToken")
                    }
                } else {
                    let (userProfile, accessToken) = try await appState.supabaseService.signIn(email: email, password: password)
                    profile = userProfile
                    
                    await MainActor.run {
                        self.appState.supabaseAccessToken = accessToken
                        UserDefaults.standard.set(accessToken, forKey: "supabaseAccessToken")
                    }
                }
                
                await MainActor.run {
                    self.isLoading = false
                    
                    // Save profile and login immediately for faster experience
                        self.appState.saveUserProfile(profile)
                        self.appState.isLoggedIn = true
        
                    // Show success message and navigate
                    self.alertMessage = isSignUp ? "🎉 Account created successfully! Welcome to GraceAI!" : "✅ Welcome back, \(profile.name)!"
                    self.showingAlert = true
                    
                    // Navigate to main screen with shorter delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            self.appState.currentScreen = .main
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    
                    // Handle specific authentication errors
                    if let authError = error as? AuthError {
                        self.alertMessage = authError.localizedDescription
                    } else {
                        // Fallback to generic error handling
                        let errorMessage = error.localizedDescription.lowercased()
                        
                        if isSignUp {
                            // Signup-specific error handling
                            if errorMessage.contains("user already registered") || 
                               errorMessage.contains("email already exists") {
                                self.alertMessage = "❌ Account already exists. Please try signing in instead."
                            } else if errorMessage.contains("password") {
                                self.alertMessage = "❌ Password must be at least 6 characters long."
                            } else {
                                self.alertMessage = "❌ Sign up failed: \(error.localizedDescription)"
                            }
                        } else {
                            // Login-specific error handling
                            if errorMessage.contains("user not found") || 
                               errorMessage.contains("email not found") {
                                self.alertMessage = "❌ Account doesn't exist. Please check your email or sign up for a new account."
                            } else if errorMessage.contains("invalid login credentials") || 
                                      errorMessage.contains("wrong password") {
                                self.alertMessage = "❌ Invalid password. Please check your password and try again."
                            } else {
                                self.alertMessage = "❌ Login failed: \(error.localizedDescription)"
                            }
                        }
                    }
                    
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func signInWithGoogle() {
        print("🔐 signInWithGoogle() called")
        isLoading = true
        
        if GIDSignIn.sharedInstance.configuration == nil {
            print("❌ Google Sign-In not configured")
            isLoading = false
            alertMessage = "Google Sign-In not configured properly"
            showingAlert = true
            return
        }
        
        guard let presentingViewController = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController else { 
            print("❌ Could not get presenting view controller")
            isLoading = false
            alertMessage = "Could not present Google Sign-In"
            showingAlert = true
            return 
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { authResult, error in
            Task {
                if let error = error {
                    await MainActor.run {
                        self.isLoading = false
                        self.alertMessage = "Google Sign-In failed: \(error.localizedDescription)"
                        self.showingAlert = true
                    }
                    return
                }
                
                guard let user = authResult?.user,
                      let idToken = user.idToken?.tokenString else {
                    await MainActor.run {
                        self.isLoading = false
                        self.alertMessage = "Failed to get Google token"
                        self.showingAlert = true
                    }
                    return
                }
                
                // Handle Google Sign-In success
                    await MainActor.run {
                        self.isLoading = false
                    // Create a profile from Google user data
                    let profile = UserProfile(
                        id: user.userID ?? UUID().uuidString,
                        email: user.profile?.email ?? "user@gmail.com",
                        name: user.profile?.name ?? "Google User"
                    )
                    
                        self.appState.saveUserProfile(profile)
                        self.appState.isLoggedIn = true
                        
                        withAnimation {
                            self.appState.currentScreen = .main
                    }
                }
            }
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.05, green: 0.05, blue: 0.1),
                Color(red: 0.1, green: 0.05, blue: 0.15),
                Color(red: 0.05, green: 0.05, blue: 0.1)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct CustomTextField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String
    var isSecure: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.purple.opacity(0.7))
                .frame(width: 20)
            
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.white.opacity(0.6))
                        .font(.body)
                }
                
                if isSecure {
                    SecureField("", text: $text)
                        .foregroundColor(.white)
                        .accentColor(.purple)
                } else {
                    TextField("", text: $text)
                        .foregroundColor(.white)
                        .accentColor(.purple)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
}

// MARK: - Main Tab Navigation
struct MainTabView: View {
    @ObservedObject var appState: AppState
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeScreen(appState: appState, selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            PracticeScreen(appState: appState, selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "music.note.list")
                    Text("Practice")
                }
                .tag(1)
            
            HistoryScreen(appState: appState)
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("History")
                }
                .tag(2)
            
            ProfileScreen(appState: appState)
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(3)
        }
        .accentColor(.purple)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemGray6
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

// MARK: - Home Screen
struct HomeScreen: View {
    @ObservedObject var appState: AppState
    @Binding var selectedTab: Int
    @State private var showingQuickPractice = false
    @State private var showingFAQ = false
    @State private var showingUploadGuide = false
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                
                ScrollView {
                    VStack(spacing: 24) {
                        appHeader
                        welcomeMessage
                        ModernStatsCards(appState: appState)
                        QuickActionsSection(showingQuickPractice: $showingQuickPractice)
                        quickActionsSection
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingQuickPractice) {
            QuickPracticeScreen(appState: appState)
        }
        .sheet(isPresented: $showingFAQ) {
            FAQView()
        }
        .sheet(isPresented: $showingUploadGuide) {
            UploadInstructionsView()
        }
    }
    
    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.1),
                    Color(red: 0.1, green: 0.05, blue: 0.15),
                    Color(red: 0.05, green: 0.05, blue: 0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            GeometryReader { geometry in
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let gridSize: CGFloat = 40
                    
                    for x in stride(from: 0, through: width, by: gridSize) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                    }
                    
                    for y in stride(from: 0, through: height, by: gridSize) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.03), lineWidth: 0.5)
            }
        }
        .ignoresSafeArea()
    }
    
    private var appHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                appIcon
                appTitle
                Spacer()
            }
            
            Text("Ready to practice?")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.top)
    }
    
    private var appIcon: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.purple, Color.blue]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 60, height: 60)
                .shadow(color: Color.purple.opacity(0.5), radius: 10, x: 0, y: 5)
            
            Image(systemName: "brain.head.profile")
                .font(.title)
                .foregroundColor(.white)
        }
    }
    
    private var appTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
                            Text("GraceAI")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.purple, Color.blue]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
            Text("AI Music Learning Companion")
                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
    }
                        
    private var welcomeMessage: some View {
                        VStack(spacing: 8) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.purple)
                            Text("Welcome back, \(appState.userProfile?.name ?? "User")!")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                Spacer()
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private var quickActionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.purple)
                Text("Quick Actions & Insights")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                QuickActionCard(
                    title: "Start Practice",
                    subtitle: "Record new session",
                    icon: "mic.fill",
                    color: .green,
                    action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedTab = 1
                        }
                    }
                )
                
                QuickActionCard(
                    title: "View Progress",
                    subtitle: "See your analytics",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .blue,
                    action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedTab = 2
                        }
                    }
                )
                
                QuickActionCard(
                    title: "FAQ",
                    subtitle: "Common questions",
                    icon: "questionmark.circle.fill",
                    color: .orange,
                    action: {
                        showingFAQ = true
                    }
                )
                
                QuickActionCard(
                    title: "Upload Guide",
                    subtitle: "How to upload files",
                    icon: "doc.text.fill",
                    color: .purple,
                    action: {
                        showingUploadGuide = true
                    }
                )
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(gradient: Gradient(colors: [color, color.opacity(0.7)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 50, height: 50)
                        .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(gradient: Gradient(colors: [color.opacity(0.3), color.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ModernStatsCards: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.purple)
                Text("Your Progress")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
                ModernStatCard(
                    title: "Total Sessions",
                    value: "\(appState.userProfile?.totalSessions ?? 0)",
                    subtitle: "sessions",
                    icon: "music.note",
                    color: .purple,
                    gradient: Gradient(colors: [Color.purple, Color.blue])
                )
                ModernStatCard(
                    title: "Avg Accuracy",
                    value: "\(Int(appState.userProfile?.averageAccuracy ?? 0))%",
                    subtitle: "overall",
                    icon: "target",
                    color: .green,
                    gradient: Gradient(colors: [Color.green, Color.blue])
                )
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct ModernStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let gradient: Gradient
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(gradient: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 50, height: 50)
                    .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(gradient: gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
        )
    }
}

struct QuickActionsSection: View {
    @Binding var showingQuickPractice: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quick Actions")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            Button(action: { showingQuickPractice = true }) {
                HStack {
                    Image(systemName: "play.fill")
                        .foregroundColor(.white)
                    Text("Start Practice Session")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .foregroundColor(.white)
                }
                .padding()
                .background(LinearGradient(gradient: Gradient(colors: [.purple, .blue]), startPoint: .leading, endPoint: .trailing))
                .cornerRadius(12)
                .shadow(color: Color.purple.opacity(0.5), radius: 10, x: 0, y: 5)
            }
        }
    }
}

// MARK: - Practice Screen
struct PracticeScreen: View {
    @ObservedObject var appState: AppState
    @Binding var selectedTab: Int
    @State private var isRecording = false
    @State private var showingFilePicker = false
    @State private var selectedAudioURL: URL?
    @State private var selectedSheetMusicURL: URL?
    @State private var analysisResult: AnalysisResult?
    @State private var isAnalyzing = false
    @State private var showingResults = false
    @State private var recentSessions: [BackendSession] = []
    @State private var isLoadingHistory = false
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Text("Practice")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.purple, Color.blue]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text("Record and analyze your performance")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.top)
                        
                        RecordingSection(
                            isRecording: $isRecording,
                            selectedAudioURL: $selectedAudioURL
                        )
                        
                        SheetMusicSection(
                            selectedSheetMusicURL: $selectedSheetMusicURL,
                            showingImagePicker: $showingFilePicker
                        )
                        
                        if selectedAudioURL != nil && selectedSheetMusicURL != nil {
                            AnalysisButton(
                                isAnalyzing: $isAnalyzing,
                                analysisResult: $analysisResult,
                                showingResults: $showingResults,
                                audioURL: selectedAudioURL!,
                                sheetMusicURL: selectedSheetMusicURL!,
                                appState: appState
                            )
                        }
                        
                        PracticeTipsSection()
                        
                        RecentSessionsSection(
                            sessions: recentSessions,
                            isLoading: isLoadingHistory,
                            onSessionTap: { session in
                                if let analysisResult = session.toAnalysisResult() {
                                    self.analysisResult = analysisResult
                                    self.showingResults = true
                                }
                            },
                            onViewAll: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    selectedTab = 2
                                }
                            }
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    .refreshable {
                        await loadRecentSessionsAsync()
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .background(
            NavigationLink(
                destination: Group {
                    if let authResult = analysisResult {
                        ResultsView(
                            analysisResult: authResult,
                            sheetMusicURL: selectedSheetMusicURL
                        )
                    } else {
                        VStack {
                            Text("No authResults available")
                                .foregroundColor(.white)
                                .font(.title2)
                            
                            Button("Back") {
                                showingResults = false
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.purple)
                            .cornerRadius(12)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                    }
                },
                isActive: $showingResults
            ) {
                EmptyView()
            }
        )
        .onAppear {
            print("🔄 PracticeScreen appeared - loading recent sessions")
            print("🆔 Current user ID: \(appState.currentUserId)")
            print("🔐 Is authenticated: \(appState.isLoggedIn)")
            loadRecentSessions()
        }
    }
    
    private var backgroundGradient: some View {
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.05, green: 0.05, blue: 0.1),
                            Color(red: 0.1, green: 0.05, blue: 0.15),
                            Color(red: 0.05, green: 0.05, blue: 0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    GeometryReader { geometry in
                        Path { path in
                            let width = geometry.size.width
                            let height = geometry.size.height
                            let gridSize: CGFloat = 40
                            
                            for x in stride(from: 0, through: width, by: gridSize) {
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: height))
                            }
                            
                            for y in stride(from: 0, through: height, by: gridSize) {
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: width, y: y))
                            }
                        }
                        .stroke(Color.white.opacity(0.03), lineWidth: 0.5)
                    }
                }
                    .ignoresSafeArea()
    }
    
    private func loadRecentSessions() {
        Task {
            await loadRecentSessionsAsync()
        }
    }
    
    private func loadRecentSessionsAsync() async {
        print("🔄 Starting to load recent sessions...")
        print("🆔 User ID: '\(appState.currentUserId)'")
        
        // Guard against empty user ID
        guard !appState.currentUserId.isEmpty else {
            print("⚠️ Cannot load recent sessions: user ID is empty")
            await MainActor.run {
                self.isLoadingHistory = false
            }
            return
        }
        
        print("✅ User ID is valid, proceeding with session load")
        isLoadingHistory = true
        
        do {
            print("📡 Fetching sessions from Supabase...")
            let sessions = try await SupabaseService.shared.fetchUserSessions(userId: appState.currentUserId)
            print("✅ Successfully loaded \(sessions.count) sessions")
            
            await MainActor.run {
                self.recentSessions = sessions
                self.isLoadingHistory = false
                print("🔄 Updated UI with \(sessions.count) recent sessions")
            }
        } catch {
            await MainActor.run {
                print("❌ Failed to load sessions: \(error)")
                self.isLoadingHistory = false
            }
        }
    }
}

// MARK: - Recording Section
struct RecordingSection: View {
    @Binding var isRecording: Bool
    @Binding var selectedAudioURL: URL?
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer?
    @State private var showingFilePicker = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "mic.fill")
                    .foregroundColor(.purple)
                Text("Record Your Performance")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 16) {
                // Recording button
            VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 4)
                            .frame(width: 120, height: 120)
                        
                        Circle()
                            .fill(isRecording ? Color.red : Color.purple.opacity(0.3))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.title)
                        .foregroundColor(.white)
                    }
                    .onTapGesture {
                        toggleRecording()
                    }
                    
                    Text(isRecording ? "Tap to Stop" : "Tap to Record")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                        if isRecording {
                                Text(formatDuration(recordingDuration))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                            }
                        }
                        
                // Upload option
                        Button(action: {
                    showingFilePicker = true
                        }) {
                            HStack {
                        Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                        Text("Upload Audio File")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(12)
                            .shadow(color: .blue.opacity(0.5), radius: 10, x: 0, y: 5)
                }
                
                if selectedAudioURL != nil {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Audio file selected")
                            .foregroundColor(.white)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(16)
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { authResult in
            switch authResult {
            case .success(let files):
                if let file = files.first {
                    selectedAudioURL = file
                }
            case .failure(let error):
                print("Error selecting file: \(error)")
            }
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
            isRecording = true
            recordingDuration = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingDuration += 0.1
        }
    }
    
    private func stopRecording() {
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Here you would typically save the recorded audio
        // For now, we'll create a mock URL
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let audioURL = documentsPath.appendingPathComponent("recorded_audio_\(Date().timeIntervalSince1970).m4a")
            selectedAudioURL = audioURL
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}








// MARK: - Sheet Music Section
struct SheetMusicSection: View {
    @Binding var selectedSheetMusicURL: URL?
    @Binding var showingImagePicker: Bool
    @State private var showingDocumentPicker = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.purple)
                Text("Upload Sheet Music")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    showingDocumentPicker = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                        Text("Select PDF")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(12)
                    .shadow(color: .blue.opacity(0.5), radius: 10, x: 0, y: 5)
                }
                
                if selectedSheetMusicURL != nil {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Sheet music uploaded")
                            .foregroundColor(.white)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(16)
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(selectedURL: $selectedSheetMusicURL)
        }
    }
}

// MARK: - Document Picker
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [
            .pdf,
            .jpeg,
            .heic,
            .image
        ]
        
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = url.lastPathComponent
            let destinationURL = documentsPath.appendingPathComponent(fileName)
            
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: url, to: destinationURL)
                parent.selectedURL = destinationURL
            } catch {
                print("Error copying file: \(error)")
            }
            
            parent.dismiss()
        }
    }
}

// MARK: - Analysis Button
struct AnalysisButton: View {
    @Binding var isAnalyzing: Bool
    @Binding var analysisResult: AnalysisResult?
    @Binding var showingResults: Bool
    @StateObject private var backendService = BackendService()
    @State private var showingError = false
    @State private var errorMessage = ""
    
    let audioURL: URL
    let sheetMusicURL: URL
    let appState: AppState
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: {
                performAnalysis()
            }) {
                HStack {
                    if isAnalyzing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "wand.and.stars")
                            .font(.title2)
                    }
                    Text(isAnalyzing ? "Analyzing..." : "Analyze Performance")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(isAnalyzing ? Color.gray : Color.purple)
                .cornerRadius(12)
                .shadow(color: Color.purple.opacity(0.5), radius: 10, x: 0, y: 5)
            }
            .disabled(isAnalyzing)
            
            if isAnalyzing {
                Text(backendService.progressMessage)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .alert("Analysis Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func performAnalysis() {
        print("🚀 Starting analysis...")
        
        Task {
            await MainActor.run {
                isAnalyzing = true
            }
            do {
                print("📡 Calling backend service...")
                let analysisWithFiles = try await backendService.analyzePerformance(audioURL: audioURL, sheetMusicURL: sheetMusicURL, userId: appState.currentUserId, appState: appState)
                let authResult = analysisWithFiles.authResult
                
                await MainActor.run {
                    print("✅ Analysis completed successfully!")
                    analysisResult = authResult
                    isAnalyzing = false
                    
                    Task {
                        do {
                            let session = BackendSession(
                                id: UUID().uuidString,
                                userId: appState.currentUserId,
                                date: DateFormatter.iso8601.string(from: Date()),
                                audioFileName: analysisWithFiles.audioURL,
                                sheetMusicFileName: analysisWithFiles.sheetMusicURL,
                                pieceTitle: "Session \(Date().timeIntervalSince1970)",
                                duration: 120.0,
                                accuracy: authResult.accuracy,
                                correctNotes: authResult.correctNotes,
                                totalNotes: authResult.totalNotes,
                                missedNotes: authResult.missedNotes,
                                tempoFeedback: authResult.rhythmicAnalysis.rhythmicFeedback,
                                timingFeedback: authResult.rhythmicAnalysis.timingAnalysis
                            )
                            
                            try await SupabaseService.shared.saveSession(session)
                            print("✅ Session saved to Supabase")
                        } catch {
                            print("❌ Failed to save session to Supabase: \(error)")
                        }
                    }
                    
                    showingResults = true
                }
            } catch {
                await MainActor.run {
                    print("❌ Analysis failed with error: \(error)")
                    errorMessage = "Analysis failed: \(error.localizedDescription)"
                    showingError = true
                    isAnalyzing = false
                }
            }
        }
    }
}

// MARK: - Practice Tips Section
struct PracticeTipsSection: View {
    @State private var showingInstructions = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.purple)
                Text("Practice Tips")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                
                Button(action: { showingInstructions = true }) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.purple)
                        .font(.title3)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            VStack(alignment: .leading, spacing: 12) {
                TipRow(icon: "metronome", title: "Use a Metronome", description: "Practice with consistent tempo")
                TipRow(icon: "repeat", title: "Start Slowly", description: "Begin at a comfortable pace")
                TipRow(icon: "target", title: "Focus on Accuracy", description: "Prioritize correct notes over speed")
                TipRow(icon: "music.note.list", title: "Record Yourself", description: "Listen back to identify issues")
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(16)
        .sheet(isPresented: $showingInstructions) {
            UploadInstructionsView()
        }
    }
}

struct TipRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
    }
}

// MARK: - Recent Sessions Section
struct RecentSessionsSection: View {
    let sessions: [BackendSession]
    let isLoading: Bool
    let onSessionTap: (BackendSession) -> Void
    let onViewAll: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.purple)
                Text("Recent Sessions")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                
                if !sessions.isEmpty {
                    HStack(spacing: 8) {
                        Text("\(sessions.count)")
                            .font(.caption)
                            .foregroundColor(.purple)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.2))
                            .cornerRadius(8)
                        
                        if sessions.count > 5 {
                            Button("View All") {
                                onViewAll?()
                            }
                            .font(.caption)
                            .foregroundColor(.purple)
                        }
                    }
                }
            }
            
            if isLoading {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                    Text("Loading sessions...")
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding()
            } else if sessions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "music.note.list")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Text("No practice sessions yet")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("Complete your first analysis to see it here")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.7))
                }
                .padding()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(sessions.prefix(5)) { session in
                        SessionRow(session: session) {
                            onSessionTap(session)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(16)
    }
}

// MARK: - Session Row
struct SessionRow: View {
    let session: BackendSession
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack {
                    Image(systemName: "music.note")
                        .font(.title2)
                        .foregroundColor(.purple)
                }
                .frame(width: 40, height: 40)
                .background(Color.purple.opacity(0.2))
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.pieceTitle ?? "Practice Session")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    if let accuracy = session.accuracy {
                        Text("\(Int(accuracy))% accuracy")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("Analysis pending")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    Text(formatDate(session.date))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(formatDuration(session.duration ?? 0.0))
                    .font(.caption)
                    .foregroundColor(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.2))
                    .cornerRadius(6)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            displayFormatter.timeZone = TimeZone.current
            displayFormatter.locale = Locale.current
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

// MARK: - Upload Instructions View
struct UploadInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.purple)
                            
                            Text("How to Upload Files")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Follow these steps to get the best authResults")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.top, 20)
                        
                        InstructionCard(
                            title: "📱 Recording Audio",
                            subtitle: "How to record your piano performance",
                            steps: [
                                "1. Open Voice Memos app on your iPhone",
                                "2. Record yourself playing the piece",
                                "3. Tap the 3 dots (⋯) next to your recording",
                                "4. Select 'Save to Files'",
                                "5. Choose a location (iCloud Drive recommended)",
                                "6. Come back to GraceAI and tap 'Select Voice Memo'"
                            ]
                        )
                        
                        InstructionCard(
                            title: "📄 Sheet Music Upload",
                            subtitle: "How to convert sheet music to PDF",
                            steps: [
                                "1. Take a clear photo of your sheet music",
                                "2. Open the photo and tap 'Share' button",
                                "3. Scroll down and tap 'Print'",
                                "4. In the print preview, tap 'Share' at the top",
                                "5. Select 'Save to Files' as PDF",
                                "6. Come back to GraceAI and upload the PDF"
                            ]
                        )
                        
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.yellow)
                                Text("Pro Tips")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                TipRow(icon: "mic.fill", title: "Audio Quality", description: "Record in a quiet room for best authResults")
                                TipRow(icon: "camera.fill", title: "Photo Quality", description: "Ensure sheet music is well-lit and in focus")
                                TipRow(icon: "doc.text.fill", title: "PDF Format", description: "PDF format works best for analysis")
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Upload Instructions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

struct InstructionCard: View {
    let title: String
    let subtitle: String
    let steps: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(steps, id: \.self) { step in
                    Text(step)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.leading, 8)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

// MARK: - FAQ View
struct FAQView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var expandedQuestions: Set<String> = []
    
    let faqs = [
        FAQItem(
            question: "What do I do if I get errors?",
            answer: "Try uploading a clearer picture of the sheet music. Make sure the image is well-lit, in focus, and shows the complete piece. If the error persists, try converting the image to PDF format using the Print → Share method."
        ),
        FAQItem(
            question: "How do I record my piano performance?",
            answer: "Use the Voice Memos app on your iPhone to record your playing. Then tap the 3 dots (⋯) next to your recording and select 'Save to Files'. Come back to GraceAI and tap 'Select Voice Memo' to upload it."
        ),
        FAQItem(
            question: "What file formats are supported?",
            answer: "For audio: M4A files from Voice Memos. For sheet music: PDF format works best. You can convert photos to PDF using the Print → Share method in your Photos app."
        ),
        FAQItem(
            question: "How accurate is the AI analysis?",
            answer: "The AI provides detailed feedback on note accuracy, timing, and tempo. For best authResults, record in a quiet environment and ensure your sheet music is clear and complete."
        ),
        FAQItem(
            question: "Can I practice without sheet music?",
            answer: "Currently, GraceAI requires both audio recording and sheet music for analysis. The sheet music helps the AI understand what you're supposed to play and provide accurate feedback."
        ),
        FAQItem(
            question: "How long does analysis take?",
            answer: "Analysis typically takes 30-60 seconds depending on the length of your recording and complexity of the piece. The app will show you progress updates during the process."
        ),
        FAQItem(
            question: "What if my analysis authResults seem wrong?",
            answer: "Check that your audio recording is clear and the sheet music matches what you played. Try re-recording in a quieter environment or with clearer sheet music images."
        ),
        FAQItem(
            question: "How do I track my progress over time?",
            answer: "Visit the History tab to see your practice sessions over time. You can filter by Week, Month, or Year to see your improvement trends and accuracy scores."
        ),
        FAQItem(
            question: "Can I use GraceAI for any instrument?",
            answer: "GraceAI is currently optimized for piano/keyboard instruments. The AI is trained to recognize piano notes and provide feedback specific to piano playing."
        ),
        FAQItem(
            question: "Is my data private and secure?",
            answer: "Yes, your recordings and analysis data are stored locally on your device. When you use cloud features, data is encrypted and handled according to our privacy policy."
        )
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.purple)
                            
                            Text("Frequently Asked Questions")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Find answers to common questions")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.top, 20)
                        
                        VStack(spacing: 16) {
                            ForEach(faqs, id: \.question) { faq in
                                FAQCard(
                                    faq: faq,
                                    isExpanded: expandedQuestions.contains(faq.question),
                                    onTap: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            if expandedQuestions.contains(faq.question) {
                                                expandedQuestions.remove(faq.question)
                                            } else {
                                                expandedQuestions.insert(faq.question)
                                            }
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("FAQ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

struct FAQItem {
    let question: String
    let answer: String
}

struct FAQCard: View {
    let faq: FAQItem
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onTap) {
                HStack {
                    Text(faq.question)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.purple)
                        .font(.caption)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Text(faq.answer)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - History Screen
struct HistoryScreen: View {
    @ObservedObject var appState: AppState
    @State private var selectedTimeframe = "Week"
    @State private var sessions: [BackendSession] = []
    @State private var isLoading = false
    @State private var selectedSession: BackendSession?
    @State private var showingSessionDetail = false
    @State private var analysisResult: AnalysisResult?
    
    let timeframes = ["Week", "Month", "Year"]
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        timeframeSelector
                        InteractiveProgressChart(sessions: filteredSessions, timeframe: selectedTimeframe)
                        sessionHistorySection
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .refreshable {
                await loadSessionsAsync()
            }
        }
        .background(navigationLink)
        .onAppear {
            print("🔄 HistoryScreen appeared - loading sessions")
            print("🆔 Current user ID: \(appState.currentUserId)")
            print("🔐 Is authenticated: \(appState.isLoggedIn)")
            loadSessionsForTimeframe(selectedTimeframe)
        }
    }
    
    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.1),
                    Color(red: 0.1, green: 0.05, blue: 0.15),
                    Color(red: 0.05, green: 0.05, blue: 0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            GeometryReader { geometry in
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let gridSize: CGFloat = 40
                    
                    for x in stride(from: 0, through: width, by: gridSize) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                    }
                    
                    for y in stride(from: 0, through: height, by: gridSize) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.03), lineWidth: 0.5)
            }
        }
        .ignoresSafeArea()
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Performance Analytics")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.purple, Color.blue]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("Track your musical journey")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.top)
    }
    
    private var timeframeSelector: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.purple)
                Text("Time Period")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            HStack(spacing: 8) {
                            ForEach(timeframes, id: \.self) { timeframe in
                    timeframeButton(for: timeframe)
                            }
                        }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
                        .padding(.horizontal)
    }
    
    private func timeframeButton(for timeframe: String) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedTimeframe = timeframe
            }
            loadSessionsForTimeframe(timeframe)
        }) {
            Text(timeframe)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(selectedTimeframe == timeframe ? .white : .white.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    selectedTimeframe == timeframe ?
                    LinearGradient(gradient: Gradient(colors: [Color.purple, Color.blue]), startPoint: .leading, endPoint: .trailing) :
                    LinearGradient(gradient: Gradient(colors: [Color.clear, Color.clear]), startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(selectedTimeframe == timeframe ? Color.clear : Color.white.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    private var sessionHistorySection: some View {
        ModernSessionHistorySection(
            sessions: filteredSessions,
            isLoading: isLoading,
            onSessionTap: { session in
                selectedSession = session
                if let authResult = session.toAnalysisResult() {
                    analysisResult = authResult
                    showingSessionDetail = true
                }
            }
        )
    }
    
    private var navigationLink: some View {
        NavigationLink(
            destination: Group {
                if let authResult = analysisResult {
                    ResultsView(
                        analysisResult: authResult,
                        sheetMusicURL: nil
                    )
                } else {
                    VStack {
                        Text("No authResults available")
                            .foregroundColor(.white)
                            .font(.title2)
                        
                        Button("Back") {
                            showingSessionDetail = false
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(12)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                }
            },
            isActive: $showingSessionDetail
        ) {
            EmptyView()
        }
    }
    
    private func loadSessionsForTimeframe(_ timeframe: String) {
        Task {
            await loadSessionsAsync()
        }
    }
    
    private var filteredSessions: [BackendSession] {
        print("🔍 Filtering \(sessions.count) sessions for timeframe: \(selectedTimeframe)")
        let calendar = Calendar.current
        let now = Date()
        
        let filteredSessions = sessions.filter { session in
            let formatter = DateFormatter.iso8601
            guard let sessionDate = formatter.date(from: session.date) else { 
                print("⚠️ Failed to parse session date: \(session.date)")
                return false 
            }
            
            switch selectedTimeframe {
            case "Week":
                return calendar.isDate(sessionDate, equalTo: now, toGranularity: .weekOfYear)
            case "Month":
                return calendar.isDate(sessionDate, equalTo: now, toGranularity: .month)
            case "Year":
                return calendar.isDate(sessionDate, equalTo: now, toGranularity: .year)
            default:
                return true
            }
        }
        
        print("✅ Filtered to \(filteredSessions.count) sessions")
        return filteredSessions.sorted { session1, session2 in
            let formatter = DateFormatter.iso8601
            let date1 = formatter.date(from: session1.date) ?? Date.distantPast
            let date2 = formatter.date(from: session2.date) ?? Date.distantPast
            return date1 > date2
        }
    }
    
    private func loadSessionsAsync() async {
        print("🔄 Starting to load sessions for History page...")
        print("🆔 User ID: '\(appState.currentUserId)'")
        
        // Guard against empty user ID
        guard !appState.currentUserId.isEmpty else {
            print("⚠️ Cannot load sessions: user ID is empty")
            await MainActor.run {
                self.isLoading = false
            }
            return
        }
        
        print("✅ User ID is valid, proceeding with session load for History")
        isLoading = true
        
        do {
            print("📡 Fetching sessions from Supabase for History...")
            let fetchedSessions = try await SupabaseService.shared.fetchUserSessions(userId: appState.currentUserId)
            print("✅ Successfully loaded \(fetchedSessions.count) sessions for History")
            
            await MainActor.run {
                self.sessions = fetchedSessions
                self.isLoading = false
                print("🔄 Updated History UI with \(fetchedSessions.count) sessions")
            }
        } catch {
            await MainActor.run {
                print("❌ Failed to load sessions for History: \(error)")
                self.isLoading = false
            }
        }
    }
}

struct InteractiveProgressChart: View {
    let sessions: [BackendSession]
    let timeframe: String
    @State private var selectedPoint: Int?
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.purple)
                Text("Performance Trend")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                
                if let averageAccuracy = calculateAverageAccuracy() {
                    HStack(spacing: 4) {
                        Text("Avg:")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(Int(averageAccuracy))%")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            
            ZStack {
                // Grid lines
                VStack(spacing: 0) {
                    ForEach(0..<6, id: \.self) { i in
                        HStack {
                        Rectangle()
                                .fill(Color.white.opacity(0.1))
                            .frame(height: 1)
                        }
                        if i < 5 {
                        Spacer()
                        }
                    }
                }
                .frame(height: 160)
                
                // Y-axis labels
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(0..<6, id: \.self) { i in
                            Text("\(100 - (i * 20))")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                                .frame(height: 32)
                        }
                    }
                    Spacer()
                }
                .frame(height: 160)
                .padding(.leading, 8)
                
                if sessions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 40))
                            .foregroundColor(.purple.opacity(0.5))
                        Text("No data available")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        Text("Complete practice sessions to see your progress")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                } else if sessions.filter({ $0.accuracy != nil }).isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 40))
                            .foregroundColor(.purple.opacity(0.5))
                        Text("No data for \(timeframe.lowercased())")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        Text("Try selecting a different time period")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                } else {
                    ChartView(sessions: sessions, selectedPoint: $selectedPoint)
                }
            }
            .frame(height: 200)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.03)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [.purple.opacity(0.4), .blue.opacity(0.4)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: .purple.opacity(0.1), radius: 10, x: 0, y: 5)
            )
            
            HStack(spacing: 16) {
                ChartLegendItem(color: .purple, text: "Accuracy")
                ChartLegendItem(color: .blue, text: "Sessions")
                ChartLegendItem(color: .green, text: "Trend")
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private func calculateAverageAccuracy() -> Double? {
        let validSessions = sessions.compactMap { $0.accuracy }
        guard !validSessions.isEmpty else { return nil }
        return validSessions.reduce(0, +) / Double(validSessions.count)
    }
}

struct ChartView: View {
    let sessions: [BackendSession]
    @Binding var selectedPoint: Int?
    
    var body: some View {
        GeometryReader { geometry in
            let chartData = prepareChartData(sessions: sessions, geometry: geometry)
            
            ZStack {
                if chartData.dataPoints.count > 1 {
                    // Gradient fill underneath the line
                    Path { path in
                        path.move(to: CGPoint(x: chartData.dataPoints[0].x, y: chartData.dataPoints[0].y))
                        for point in chartData.dataPoints.dropFirst() {
                            path.addLine(to: point)
                        }
                        // Close the path to create a fill area
                        path.addLine(to: CGPoint(x: chartData.dataPoints.last!.x, y: geometry.size.height - 20))
                        path.addLine(to: CGPoint(x: chartData.dataPoints[0].x, y: geometry.size.height - 20))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.purple.opacity(0.3),
                                Color.blue.opacity(0.2),
                                Color.clear
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Main line stroke
                    Path { path in
                        path.move(to: chartData.dataPoints[0])
                        for point in chartData.dataPoints.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.purple, Color.blue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                }
                
                ForEach(Array(chartData.dataPoints.enumerated()), id: \.offset) { index, point in
                    ChartDataPoint(
                        point: point,
                        isSelected: selectedPoint == index,
                        accuracy: chartData.sortedSessions[index].accuracy ?? 0,
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedPoint = selectedPoint == index ? nil : index
                            }
                        }
                    )
                }
            }
        }
    }
    
    private func prepareChartData(sessions: [BackendSession], geometry: GeometryProxy) -> ChartData {
        let width = geometry.size.width - 40
        let height = geometry.size.height - 40
        let maxAccuracy = 100.0
        let minAccuracy = 0.0
        
        let sortedSessions = sessions.sorted { session1, session2 in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let date1 = formatter.date(from: session1.date) ?? Date.distantPast
            let date2 = formatter.date(from: session2.date) ?? Date.distantPast
            return date1 < date2
        }
        
        let dataPoints = sortedSessions.enumerated().compactMap { index, session -> CGPoint? in
            guard let accuracy = session.accuracy else { return nil }
            let x = CGFloat(index) / CGFloat(max(1, sortedSessions.count - 1)) * width
            let y = height - (CGFloat(accuracy - minAccuracy) / CGFloat(maxAccuracy - minAccuracy) * height)
            return CGPoint(x: x + 20, y: y + 20)
        }
        
        return ChartData(dataPoints: dataPoints, sortedSessions: sortedSessions)
    }
}

struct ChartData {
    let dataPoints: [CGPoint]
    let sortedSessions: [BackendSession]
}

struct ChartDataPoint: View {
    let point: CGPoint
    let isSelected: Bool
    let accuracy: Double
    let onTap: () -> Void
    
    var body: some View {
        Circle()
            .fill(isSelected ? Color.white : Color.purple)
            .frame(width: isSelected ? 12 : 8, height: isSelected ? 12 : 8)
            .position(point)
            .onTapGesture(perform: onTap)
            .overlay(
                isSelected ?
                VStack(spacing: 4) {
                    Text("\(Int(accuracy))%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(6)
                }
                .offset(y: -25)
                : nil
            )
    }
}

struct ChartLegendItem: View {
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

struct ModernSessionHistorySection: View {
    let sessions: [BackendSession]
    let isLoading: Bool
    let onSessionTap: (BackendSession) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.purple)
                Text("Practice Sessions")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                
                if !sessions.isEmpty {
                    HStack(spacing: 4) {
                        Text("\(sessions.count)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                        Text("sessions")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                        .scaleEffect(1.2)
                    Text("Loading sessions...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(height: 120)
            } else if sessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 40))
                        .foregroundColor(.purple.opacity(0.5))
                    Text("No practice sessions yet")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    Text("Complete your first analysis to see it here")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .frame(height: 120)
            } else {
            LazyVStack(spacing: 12) {
                    ForEach(sessions) { session in
                        ModernSessionRow(session: session) {
                            onSessionTap(session)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct ModernSessionRow: View {
    let session: BackendSession
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.purple, Color.blue]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "music.note")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.pieceTitle ?? "Practice Session")
                    .font(.subheadline)
                        .fontWeight(.semibold)
                    .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 12) {
                        if let accuracy = session.accuracy {
                            HStack(spacing: 4) {
                                Image(systemName: "target")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text("\(Int(accuracy))%")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Text(formatDuration(session.duration ?? 0.0))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    Text(formatDate(session.date))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            // Small chart icon on the right
            VStack(spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                    .foregroundColor(.purple)
                
                if let accuracy = session.accuracy {
                    Text("\(Int(accuracy))%")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                }
            }
        }
        .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            displayFormatter.timeZone = TimeZone.current
            displayFormatter.locale = Locale.current
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

// MARK: - Profile Screen
struct ProfileScreen: View {
    @ObservedObject var appState: AppState
    @State private var showingLogoutAlert = false
    @State private var showingResetAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        ProfileHeader(appState: appState)
                        ProfileStats(appState: appState)
                        SettingsSection()
                        
                        VStack(spacing: 12) {
                            LogoutButton(showingLogoutAlert: $showingLogoutAlert, appState: appState)
                            ResetButton(showingResetAlert: $showingResetAlert, appState: appState)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("Logout", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Logout", role: .destructive) {
                appState.logout()
            }
        } message: {
            Text("Are you sure you want to logout?")
        }
        .alert("Reset App", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                appState.resetToSplash()
            }
        } message: {
            Text("This will reset the app to the splash screen. Are you sure?")
        }
    }
}

struct ProfileHeader: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.purple)
                .shadow(color: Color.purple.opacity(0.3), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 4) {
                Text(appState.userProfile?.name ?? "User")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(appState.userProfile?.email ?? "user@example.com")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                
                Text("Member since \(appState.userProfile?.createdAt ?? Date(), style: .date)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(16)
        .shadow(color: .purple.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

struct ProfileStats: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ProfileStatCard(title: "Sessions", value: "\(appState.userProfile?.totalSessions ?? 0)", icon: "music.note")
            ProfileStatCard(title: "Accuracy", value: "\(Int(appState.userProfile?.averageAccuracy ?? 0))%", icon: "target")
            ProfileStatCard(title: "Streak", value: "\(appState.userProfile?.currentStreak ?? 0) days", icon: "flame")
        }
    }
}

struct ProfileStatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.purple)
                .shadow(color: .purple.opacity(0.3), radius: 5, x: 0, y: 2)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
        .shadow(color: .purple.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

struct SettingsSection: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Settings")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 0) {
                SettingsRow(icon: "bell", title: "Notifications", subtitle: "Practice reminders")
                SettingsRow(icon: "gear", title: "Preferences", subtitle: "App settings")
                SettingsRow(icon: "questionmark.circle", title: "Help", subtitle: "Support & FAQ")
                SettingsRow(icon: "info.circle", title: "About", subtitle: "App version 1.0.0")
            }
            .background(Color.gray.opacity(0.2))
            .cornerRadius(16)
            .shadow(color: .purple.opacity(0.2), radius: 10, x: 0, y: 5)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.7))
                .font(.caption)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
    }
}

struct LogoutButton: View {
    @Binding var showingLogoutAlert: Bool
    @ObservedObject var appState: AppState
    
    var body: some View {
        Button(action: { showingLogoutAlert = true }) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundColor(.red)
                Text("Logout")
                    .foregroundColor(.red)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
            .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}

struct ResetButton: View {
    @Binding var showingResetAlert: Bool
    @ObservedObject var appState: AppState
    
    var body: some View {
        Button(action: { showingResetAlert = true }) {
            HStack {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.orange)
                Text("Reset App")
                    .foregroundColor(.orange)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
            .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Quick Practice Screen
struct QuickPracticeScreen: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var isRecording = false
    @State private var selectedSheetMusicURL: URL?
    @State private var showingFilePicker = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.purple)
                        
                        Text("Quick Practice")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Record a quick practice session")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 40)
                    
                    VStack(spacing: 20) {
                        Button(action: {
                            if isRecording {
                                stopRecording()
                            } else {
                                startRecording()
                            }
                        }) {
                            HStack {
                                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                    .font(.title2)
                                Text(isRecording ? "Stop Recording" : "Start Recording")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isRecording ? Color.red : Color.green)
                            .cornerRadius(12)
                            .shadow(color: isRecording ? Color.red.opacity(0.5) : Color.green.opacity(0.5), radius: 10, x: 0, y: 5)
                        }
                        
                        if selectedSheetMusicURL != nil {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Sheet music uploaded")
                                    .foregroundColor(.white)
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(16)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Quick Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private func startRecording() {
        isRecording = true
        // Add recording logic here
    }
    
    private func stopRecording() {
        isRecording = false
        // Add stop recording logic here
    }
}

// MARK: - Results View
struct ResultsView: View {
    let analysisResult: AnalysisResult
    let sheetMusicURL: URL?
    @Environment(\.presentationMode) private var presentationMode
    @State private var aiFeedback = ""
    @State private var isLoadingAI = false
    @State private var showingSheetMusic = false
    @State private var selectedTimeframe = "Overall"
    
    var body: some View {
        NavigationView {
        ZStack {
                backgroundGradient
                gridPattern
            
            ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        accuracyCard
                        performanceMetricsSection
                        detectedNotesSection
                        feedbackSection
                        
                        if !analysisResult.missedNotes.isEmpty {
                            missedNotesSection
                        }
                        
                        aiFeedbackSection
                        practiceRecommendationsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                            .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            generateAIFeedback()
        }
    }
    
    private var detectedNotesSection: some View {
        DetectedNotesSection(analysisResult: analysisResult)
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.05, green: 0.05, blue: 0.1),
                Color(red: 0.1, green: 0.05, blue: 0.15),
                Color(red: 0.05, green: 0.05, blue: 0.1)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var gridPattern: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let gridSize: CGFloat = 40
                
                for x in stride(from: 0, through: width, by: gridSize) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }
                
                for y in stride(from: 0, through: height, by: gridSize) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(Color.white.opacity(0.03), lineWidth: 0.5)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.green, Color.blue]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: .green.opacity(0.5), radius: 15, x: 0, y: 8)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            
            Text("Analysis Complete!")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.green, Color.blue]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("Your performance breakdown")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 20)
    }
    
    private var accuracyCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 12)
                    .frame(width: 140, height: 140)
                
                Circle()
                    .trim(from: 0, to: analysisResult.accuracy / 100)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.green, Color.blue]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.5), value: analysisResult.accuracy)
                
                VStack(spacing: 4) {
                    Text("\(Int(analysisResult.accuracy))%")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        Text("Accuracy")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { index in
                    Image(systemName: index < Int(analysisResult.accuracy / 20) ? "star.fill" : "star")
                        .foregroundColor(index < Int(analysisResult.accuracy / 20) ? .yellow : .gray.opacity(0.3))
                        .font(.title3)
                }
            }
            
            Text(getPerformanceLevel())
                            .font(.headline)
                .foregroundColor(getPerformanceColor())
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(getPerformanceColor().opacity(0.2))
                .cornerRadius(20)
                    }
                    .padding()
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [.green.opacity(0.3), .blue.opacity(0.3)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    private var performanceMetricsSection: some View {
        VStack(spacing: 16) {
                        HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.purple)
                Text("Performance Metrics")
                    .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                EnhancedPerformanceStatCard(
                    title: "Correct Notes",
                    value: "\(analysisResult.correctNotes)",
                    subtitle: "out of \(analysisResult.totalNotes)",
                    icon: "music.note",
                    color: .green,
                    percentage: Double(analysisResult.correctNotes) / Double(analysisResult.totalNotes) * 100
                )
                
                EnhancedPerformanceStatCard(
                    title: "Total Notes",
                    value: "\(analysisResult.totalNotes)",
                    subtitle: "played",
                    icon: "music.note.list",
                    color: .blue,
                    percentage: 100
                )
                
                EnhancedPerformanceStatCard(
                    title: "Missed Notes",
                    value: "\(analysisResult.missedNotes.count)",
                    subtitle: "to practice",
                    icon: "exclamationmark.triangle",
                    color: .orange,
                    percentage: Double(analysisResult.missedNotes.count) / Double(analysisResult.totalNotes) * 100
                )
                
                EnhancedPerformanceStatCard(
                    title: "Success Rate",
                    value: "\(Int(Double(analysisResult.correctNotes) / Double(analysisResult.totalNotes) * 100))%",
                    subtitle: "notes hit",
                    icon: "target",
                    color: .purple,
                    percentage: Double(analysisResult.correctNotes) / Double(analysisResult.totalNotes) * 100
                )
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(20)
    }
    
    private var feedbackSection: some View {
        VStack(spacing: 16) {
                        HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Performance Feedback")
                    .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
            }
            
            VStack(spacing: 12) {
                EnhancedFeedbackCard(
                    title: "Tempo",
                    feedback: analysisResult.rhythmicAnalysis.rhythmicFeedback,
                    icon: "metronome",
                    color: .blue,
                    rating: getTempoRating()
                )
                
                EnhancedFeedbackCard(
                    title: "Timing",
                    feedback: analysisResult.rhythmicAnalysis.timingAnalysis,
                    icon: "clock",
                    color: .purple,
                    rating: getTimingRating()
                )
                        }
                    }
                    .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(20)
    }
    
    private var missedNotesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Notes to Practice")
                                .font(.headline)
                                .foregroundColor(.white)
                Spacer()
                            
                Text("\(analysisResult.missedNotes.count)")
                    .font(.caption)
                                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(8)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(analysisResult.missedNotes, id: \.self) { note in
                    Text(note)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.orange.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
                            }
                        }
                        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(20)
    }
    
    private var aiFeedbackSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Text("AI Insights")
                            .font(.headline)
                            .foregroundColor(.white)
                Spacer()
                
                if isLoadingAI {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                        .scaleEffect(0.8)
                }
            }
            
            if aiFeedback.isEmpty && !isLoadingAI {
                Button(action: generateAIFeedback) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Generate AI Feedback")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.purple, Color.blue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
            } else if !aiFeedback.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.purple)
                        Text("AI Analysis")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    
                    Text(aiFeedback)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .lineSpacing(4)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(20)
    }
    
    private var practiceRecommendationsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(.green)
                Text("Practice Recommendations")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 12) {
                RecommendationCard(
                    icon: "metronome",
                    title: "Use a Metronome",
                    description: "Practice with consistent tempo to improve timing accuracy",
                    color: .blue
                )
                
                RecommendationCard(
                    icon: "repeat",
                    title: "Practice Slowly",
                    description: "Start at 60% tempo and gradually increase speed",
                    color: .orange
                )
                
                RecommendationCard(
                    icon: "music.note.list",
                    title: "Focus on Problem Areas",
                    description: "Spend extra time on the \(analysisResult.missedNotes.count) missed notes",
                    color: .red
                )
            }
        }
                    .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(20)
    }
    
    private func getPerformanceLevel() -> String {
        let accuracy = analysisResult.accuracy
        switch accuracy {
        case 90...100:
            return "🎉 Excellent"
        case 75..<90:
            return "👍 Good"
        case 60..<75:
            return "📈 Fair"
        default:
            return "🎯 Needs Practice"
        }
    }
    
    private func getPerformanceColor() -> Color {
        let accuracy = analysisResult.accuracy
        switch accuracy {
        case 90...100:
            return .green
        case 75..<90:
            return .blue
        case 60..<75:
            return .orange
        default:
            return .red
        }
    }
    
    private func getTempoRating() -> Int {
        return Int(analysisResult.accuracy / 20)
    }
    
    private func getTimingRating() -> Int {
        return Int(analysisResult.accuracy / 20)
    }
    
    private func generateAIFeedback() {
        isLoadingAI = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isLoadingAI = false
            
            let accuracy = self.analysisResult.accuracy
            let missedCount = self.analysisResult.missedNotes.count
            let correctNotes = self.analysisResult.correctNotes
            let totalNotes = self.analysisResult.totalNotes
            
            if accuracy >= 90 {
                self.aiFeedback = "🎉 **Excellent Performance!** Your \(Int(accuracy))% accuracy demonstrates exceptional technical proficiency. You correctly played \(correctNotes) out of \(totalNotes) notes. Your musical foundation is solid - now focus on expressive playing, dynamics, and musical interpretation to elevate your performance to the next level."
            } else if accuracy >= 75 {
                self.aiFeedback = "👍 **Good Work!** With \(Int(accuracy))% accuracy, you're showing strong progress. You hit \(correctNotes) out of \(totalNotes) notes correctly. Focus on the \(missedCount) missed notes by practicing them slowly and gradually increasing tempo. Consider using a metronome for consistent timing and rhythm."
            } else if accuracy >= 60 {
                self.aiFeedback = "📈 **Solid Foundation!** At \(Int(accuracy))% accuracy, you have a good base to build upon. You played \(correctNotes) out of \(totalNotes) notes correctly. Break down the \(missedCount) missed notes into smaller sections and practice each part separately before combining them. Focus on accuracy before speed."
            } else {
                self.aiFeedback = "🎯 **Keep Practicing!** With \(Int(accuracy))% accuracy, you're in the learning phase. You correctly played \(correctNotes) out of \(totalNotes) notes. Start with the basics: practice each of the \(missedCount) missed notes individually, then work on simple passages before tackling the full piece. Remember: slow and steady wins the race!"
            }
        }
    }
}

// MARK: - Detected Notes Section
struct DetectedNotesSection: View {
    let analysisResult: AnalysisResult
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "music.note.list")
                    .foregroundColor(.purple)
                Text("Detected Notes")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
            HStack {
                        Text("All Notes Detected")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    .foregroundColor(.white)
                Spacer()
                        Text("\(analysisResult.allAudioNotes.count) total")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(analysisResult.allAudioNotes.enumerated()), id: \.offset) { index, note in
                                let isMissed = analysisResult.missedNotes.contains { missedNote in
                                    let noteName = missedNote.components(separatedBy: " ").first ?? missedNote
                                    return noteName == note
                                }
                                let isCorrect = !isMissed
                                
                                Text(note)
                                    .font(.caption)
                                    .fontWeight(.medium)
                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(isCorrect ? Color.green.opacity(0.3) : Color.red.opacity(0.3))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
            HStack {
                        Text("Performance Summary")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                        Spacer()
                        Text("\(analysisResult.correctNotes)/\(analysisResult.totalNotes) correct")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
                    Text("Based on advanced analysis for accurate feedback")
                    .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(16)
    }
}

// MARK: - Enhanced Performance Stat Card
struct EnhancedPerformanceStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let percentage: Double
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(gradient: Gradient(colors: [color, color.opacity(0.7)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 50, height: 50)
                    .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [color, color.opacity(0.7)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(percentage / 100), height: 4)
                        .cornerRadius(2)
                        .animation(.easeInOut(duration: 1.0), value: percentage)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(gradient: Gradient(colors: [color.opacity(0.3), color.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
        )
    }
}

struct EnhancedFeedbackCard: View {
    let title: String
    let feedback: String
    let icon: String
    let color: Color
    let rating: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                    .frame(width: 24)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { index in
                        Image(systemName: index < rating ? "star.fill" : "star")
                            .foregroundColor(index < rating ? .yellow : .gray.opacity(0.3))
                            .font(.caption)
                    }
                }
            }
            
            Text(feedback)
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct RecommendationCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Custom Button Styles
struct HoverButtonStyle: ButtonStyle {
    let backgroundColor: Color
    let hoverColor: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .background(configuration.isPressed ? hoverColor : backgroundColor)
            .cornerRadius(12)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct GlowButtonStyle: ButtonStyle {
    let backgroundColor: Color
    let glowColor: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .background(backgroundColor)
            .cornerRadius(12)
            .shadow(color: glowColor.opacity(configuration.isPressed ? 0.3 : 0.5), radius: 10, x: 0, y: 5)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Supporting Views
struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct FeedbackCard: View {
    let title: String
    let feedback: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(feedback)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct FeedbackRow: View {
    let icon: String
    let title: String
    let feedback: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text(feedback)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
    }
}

struct RecommendationRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
    }
}

// MARK: - Additional Supporting Models
struct AnalysisWithFiles {
    let authResult: AnalysisResult
    let audioURL: String
    let sheetMusicURL: String
}

struct SupabaseUser: Codable {
    let id: String
    let email: String
    let user_metadata: [String: String]?
}

// MARK: - Additional Data Models
struct AppMetadata: Codable {
    let provider: String
    let providers: [String]
}

struct SignUpUserMetadata: Codable {
    let email: String
    let email_verified: Bool
    let name: String
    let phone_verified: Bool
    let sub: String
}

struct Identity: Codable {
    let identity_id: String
    let id: String
    let user_id: String
    let identity_data: IdentityData
    let provider: String
    let last_sign_in_at: String
    let created_at: String
    let updated_at: String
    let email: String
}

struct IdentityData: Codable {
    let email: String
    let email_verified: Bool
    let name: String
    let phone_verified: Bool
    let sub: String
}

struct SignInResponse: Codable {
    let access_token: String
    let token_type: String
    let expires_in: Int
    let expires_at: Int
    let refresh_token: String
    let user: SignInUser
}

struct SignInUser: Codable {
    let id: String
    let aud: String
    let role: String
    let email: String
    let email_confirmed_at: String?
    let phone: String
    let confirmation_sent_at: String?
    let confirmed_at: String?
    let last_sign_in_at: String?
    let app_metadata: SignInAppMetadata
    let user_metadata: SignInUserMetadata
    let identities: [SignInIdentity]
    let created_at: String
    let updated_at: String
    let is_anonymous: Bool
}

struct SignInUserMetadata: Codable {
    let email: String
    let email_verified: Bool
    let name: String
    let phone_verified: Bool
    let sub: String
}

struct SignInAppMetadata: Codable {
    let provider: String
    let providers: [String]
}

struct SignInIdentity: Codable {
    let identity_id: String
    let id: String
    let user_id: String
    let identity_data: SignInIdentityData
    let provider: String
    let last_sign_in_at: String
    let created_at: String
    let updated_at: String
    let email: String
}

struct SignInIdentityData: Codable {
    let email: String
    let email_verified: Bool
    let name: String
    let phone_verified: Bool
    let sub: String
}

struct SupabaseSessionData: Codable {
    let access_token: String
    let refresh_token: String
}

struct SupabaseProfile: Codable {
    let user_id: String
    let name: String
    let email: String
    let created_at: String
}

struct SupabaseSession: Codable {
    let user_id: String
    let accuracy: Double
    let correct_notes: Int
    let total_notes: Int
    let missed_notes: [String]
    let tempo_feedback: String
    let timing_feedback: String
    let audio_url: String?
    let sheet_music_url: String?
    let created_at: String
    
    func toBackendSession() -> BackendSession {
        return BackendSession(
            id: UUID().uuidString,
            userId: user_id,
            date: created_at,
            audioFileName: audio_url ?? "",
            sheetMusicFileName: sheet_music_url ?? "",
            pieceTitle: nil,
            duration: 120.0,
            accuracy: accuracy,
            correctNotes: correct_notes,
            totalNotes: total_notes,
            missedNotes: missed_notes,
            tempoFeedback: tempo_feedback,
            timingFeedback: timing_feedback
        )
    }
}

// MARK: - End of File (Duplicates removed)

#Preview {
    ContentView()
}
