//
//  GraceAIApp.swift
//  GraceAI
//
//  Created by Darsh Senthil on 7/17/25.
//

import SwiftUI
import GoogleSignIn

@main
struct GraceAIApp: App {
    init() {
        // Configure Google Sign-In using GoogleService-Info.plist
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else {
            print("❌ GoogleService-Info.plist not found in bundle")
            return
        }
        
        guard let plist = NSDictionary(contentsOfFile: path) else {
            print("❌ Failed to read GoogleService-Info.plist")
            return
        }
        
        guard let clientId = plist["CLIENT_ID"] as? String else {
            print("❌ CLIENT_ID not found in GoogleService-Info.plist")
            return
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
        print("✅ Google Sign-In configured with client ID: \(clientId)")
        
        // Also check if we can access the reversed client ID
        if let reversedClientId = plist["REVERSED_CLIENT_ID"] as? String {
            print("✅ Reversed Client ID: \(reversedClientId)")
        }
    }
    
    var body: some Scene {
        let _ = print("🚀 GraceAIApp body rendered")
        WindowGroup {
            NavigationStack {
                ContentView()
                    .onOpenURL { url in
                        GIDSignIn.sharedInstance.handle(url)
                    }
            }
        }
    }
}
