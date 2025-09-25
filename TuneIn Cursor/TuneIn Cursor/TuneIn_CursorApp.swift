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
        // Configure Google Sign-In using iOS Client ID from GoogleService-Info.plist
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            return
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
    }
    
    var body: some Scene {
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
