// Test Supabase Connection
// Add this to your ContentView.swift temporarily to test the connection

import SwiftUI

// Add this function to your SupabaseService class
extension SupabaseService {
    func testConnection() async {
        print("🔍 Testing Supabase connection...")
        
        let url = URL(string: "\(baseURL)/rest/v1/profiles?select=count")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 Connection test response: \(httpResponse.statusCode)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 Response data: \(responseString)")
                }
                
                if httpResponse.statusCode == 200 {
                    print("✅ Supabase connection successful!")
                } else {
                    print("❌ Supabase connection failed: \(httpResponse.statusCode)")
                }
            }
        } catch {
            print("❌ Connection test error: \(error)")
        }
    }
}

// Add this button to your LoginScreen temporarily
struct TestConnectionButton: View {
    let supabaseService: SupabaseService
    
    var body: some View {
        Button("Test Supabase Connection") {
            Task {
                await supabaseService.testConnection()
            }
        }
        .foregroundColor(.white)
        .padding()
        .background(Color.blue)
        .cornerRadius(12)
    }
} 