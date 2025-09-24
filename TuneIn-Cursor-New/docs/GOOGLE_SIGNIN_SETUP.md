# 🔍 Google Sign-In Setup for TuneIn Cursor

## 📋 Overview
This guide will help you set up Google Sign-In for your iOS app with Supabase. **Everything is FREE!**

## 🔍 Google Cloud Console Setup

### 1. Create Google Cloud Project
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click **Select a project** → **New Project**
3. Name it: `TuneIn Cursor`
4. Click **Create**

### 2. Enable Google+ API
1. Go to **APIs & Services** → **Library**
2. Search for "Google+ API"
3. Click on it and click **Enable**

### 3. Create OAuth 2.0 Credentials
1. Go to **APIs & Services** → **Credentials**
2. Click **Create Credentials** → **OAuth 2.0 Client IDs**
3. If prompted, configure OAuth consent screen:
   - **User Type**: External
   - **App name**: TuneIn Cursor
   - **User support email**: Your email
   - **Developer contact information**: Your email
   - Click **Save and Continue** through all steps

### 4. Create iOS Client
1. Click **Create Credentials** → **OAuth 2.0 Client IDs**
2. Select **iOS** as application type
3. Fill in:
   - **Name**: TuneIn Cursor iOS
   - **Bundle ID**: Your app's bundle ID (e.g., `com.yourname.tuneincursor`)
4. Click **Create**
5. **Note your Client ID** (you'll need this)

### 5. Create Web Client (for Supabase)
1. Click **Create Credentials** → **OAuth 2.0 Client IDs**
2. Select **Web application**
3. Fill in:
   - **Name**: TuneIn Cursor Web
   - **Authorized redirect URIs**: 
     - `https://cjqmnznipjwdxgqdegov.supabase.co/auth/v1/callback`
4. Click **Create**
5. **Note your Client ID and Client Secret**

## 🔧 Supabase Configuration

### 1. Enable Google Provider
1. Go to your Supabase dashboard
2. Navigate to **Authentication** → **Providers**
3. Find **Google** and click **Enable**
4. Fill in:
   - **Client ID**: Your Google Web Client ID
   - **Client Secret**: Your Google Web Client Secret
5. Click **Save**

## 📱 iOS App Setup

### 1. Add GoogleSignIn SDK
1. Open your project in Xcode
2. Go to **File** → **Add Package Dependencies**
3. Enter URL: `https://github.com/google/GoogleSignIn-iOS`
4. Click **Add Package**

### 2. Update Info.plist
Add to your `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>google</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

Replace `YOUR_CLIENT_ID` with your Google iOS Client ID.

### 3. Initialize Google Sign-In
Add this to your `TuneIn_CursorApp.swift`:

```swift
import GoogleSignIn

@main
struct TuneIn_CursorApp: App {
    init() {
        // Configure Google Sign-In
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: "YOUR_IOS_CLIENT_ID"
        )
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## 🚀 Implementation

### 1. Update the Google Sign-In Function
Replace the placeholder function in your `LoginScreen` with:

```swift
private func signInWithGoogle() {
    isLoading = true
    
    guard let presentingViewController = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController else { 
        isLoading = false
        return 
    }
    
    GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
        Task {
            if let error = error {
                await MainActor.run {
                    self.isLoading = false
                    self.alertMessage = "Google Sign-In failed: \(error.localizedDescription)"
                    self.showingAlert = true
                }
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                await MainActor.run {
                    self.isLoading = false
                    self.alertMessage = "Failed to get Google token"
                    self.showingAlert = true
                }
                return
            }
            
            do {
                let profile = try await self.appState.supabaseService.signInWithGoogle(idToken: idToken)
                
                await MainActor.run {
                    self.isLoading = false
                    self.appState.saveUserProfile(profile)
                    self.appState.isLoggedIn = true
                    
                    withAnimation {
                        self.appState.currentScreen = .main
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.alertMessage = error.localizedDescription
                    self.showingAlert = true
                }
            }
        }
    }
}
```

## 🧪 Testing

### 1. Test Google Sign-In
1. Run your app
2. Tap the "Continue with Google" button
3. Complete the Google authentication flow
4. Verify user is created in Supabase

### 2. Check Supabase Dashboard
1. Go to **Authentication** → **Users**
2. You should see the new Google user
3. Check **Table Editor** → **profiles** table

## 🔧 Troubleshooting

### Common Issues:
- **"Invalid client ID"**: Check your OAuth credentials
- **"Redirect URI mismatch"**: Verify redirect URIs in Google Console
- **"API not enabled"**: Ensure Google+ API is enabled
- **"Bundle ID mismatch"**: Check your iOS Client ID bundle ID

## ✅ Success Checklist

- [ ] Google Cloud project created
- [ ] Google+ API enabled
- [ ] OAuth credentials created (iOS + Web)
- [ ] Supabase Google provider enabled
- [ ] GoogleSignIn SDK added to Xcode
- [ ] Info.plist updated
- [ ] App initialized with Google config
- [ ] Google Sign-In function implemented
- [ ] Test user can sign in with Google
- [ ] User appears in Supabase

## 💰 Cost: $0
Everything in this setup is completely free! 🎉

Your Google Sign-In is now ready to use! 🚀 