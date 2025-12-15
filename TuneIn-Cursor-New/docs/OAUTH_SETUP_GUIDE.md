# 🍎🔍 OAuth Setup Guide for TuneIn Cursor

## 📋 Overview
This guide will help you set up Apple Sign-In and Google Sign-In for your iOS app with Supabase.

## 🍎 Apple Sign-In Setup

### 1. Apple Developer Account Setup
1. Go to [Apple Developer](https://developer.apple.com/)
2. Sign in with your Apple ID
3. Go to **Certificates, Identifiers & Profiles**

### 2. Create App ID
1. Go to **Identifiers**
2. Click **+** to create new identifier
3. Select **App IDs** → **App**
4. Fill in:
   - **Description**: TuneIn Cursor
   - **Bundle ID**: Your app's bundle ID (e.g., `com.yourname.tuneincursor`)
5. Enable **Sign In with Apple**
6. Click **Continue** and **Register**

### 3. Create Service ID
1. Go to **Identifiers**
2. Click **+** to create new identifier
3. Select **Services IDs** → **Services**
4. Fill in:
   - **Description**: TuneIn Cursor Web
   - **Identifier**: `com.yourname.tuneincursor.web`
5. Enable **Sign In with Apple**
6. Click **Continue** and **Register**

### 4. Configure Service ID
1. Click on your Service ID
2. Click **Configure** next to Sign In with Apple
3. Add your domain: `cjqmnznipjwdxgqdegov.supabase.co`
4. Add return URL: `https://cjqmnznipjwdxgqdegov.supabase.co/auth/v1/callback`
5. Click **Save**

### 5. Create Key
1. Go to **Keys**
2. Click **+** to create new key
3. Fill in:
   - **Key Name**: TuneIn Cursor Key
   - **Key ID**: Note this down (you'll need it)
4. Enable **Sign In with Apple**
5. Click **Configure** and select your App ID
6. Click **Continue** and **Register**
7. **Download the key file** (you can only download once!)

### 6. Get Team ID
1. Go to **Membership** in your Apple Developer account
2. Note your **Team ID** (10-character string)

## 🔍 Google Sign-In Setup

### 1. Google Cloud Console Setup
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable **Google+ API**:
   - Go to **APIs & Services** → **Library**
   - Search for "Google+ API"
   - Click **Enable**

### 2. Create OAuth 2.0 Credentials
1. Go to **APIs & Services** → **Credentials**
2. Click **Create Credentials** → **OAuth 2.0 Client IDs**
3. Select **iOS** as application type
4. Fill in:
   - **Name**: TuneIn Cursor iOS
   - **Bundle ID**: Your app's bundle ID
5. Click **Create**
6. Note your **Client ID**

### 3. Create Web Client (for Supabase)
1. Click **Create Credentials** → **OAuth 2.0 Client IDs**
2. Select **Web application**
3. Fill in:
   - **Name**: TuneIn Cursor Web
   - **Authorized redirect URIs**: 
     - `https://cjqmnznipjwdxgqdegov.supabase.co/auth/v1/callback`
4. Click **Create**
5. Note your **Client ID** and **Client Secret**

## 🔧 Supabase Configuration

### 1. Apple Provider Setup
1. Go to your Supabase dashboard
2. Navigate to **Authentication** → **Providers**
3. Enable **Apple**
4. Fill in:
   - **Service ID**: `com.yourname.tuneincursor.web`
   - **Team ID**: Your Apple Team ID
   - **Key ID**: Your Apple Key ID
   - **Private Key**: Content of your downloaded .p8 file

### 2. Google Provider Setup
1. In the same **Providers** section
2. Enable **Google**
3. Fill in:
   - **Client ID**: Your Google Web Client ID
   - **Client Secret**: Your Google Web Client Secret

## 📱 iOS App Configuration

### 1. Xcode Project Setup
1. Open your project in Xcode
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **Sign in with Apple**

### 2. Install Dependencies
Add these to your `Package.swift` or use Swift Package Manager:

```swift
// For Google Sign-In
import GoogleSignIn

// For Apple Sign-In (built into iOS)
import AuthenticationServices
```

### 3. Update Info.plist
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

## 🚀 Implementation

### 1. Apple Sign-In Implementation
```swift
import AuthenticationServices

class AppleSignInManager: NSObject, ASAuthorizationControllerDelegate {
    func signInWithApple() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.performRequests()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            // Send to Supabase
            let idToken = String(data: appleIDCredential.identityToken!, encoding: .utf8)!
            // Call your Supabase service
        }
    }
}
```

### 2. Google Sign-In Implementation
```swift
import GoogleSignIn

class GoogleSignInManager {
    func signInWithGoogle() {
        guard let presentingViewController = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController else { return }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
            if let user = result?.user {
                let idToken = user.idToken?.tokenString
                // Send to Supabase
            }
        }
    }
}
```

## 🧪 Testing

### 1. Test Apple Sign-In
1. Run your app on a real device (not simulator)
2. Tap the Apple Sign-In button
3. Complete the Apple authentication flow
4. Verify user is created in Supabase

### 2. Test Google Sign-In
1. Run your app
2. Tap the Google Sign-In button
3. Complete the Google authentication flow
4. Verify user is created in Supabase

## 🔧 Troubleshooting

### Common Apple Sign-In Issues
- **"Invalid client"**: Check your Service ID configuration
- **"Invalid redirect URI"**: Verify the return URL in Apple Developer
- **"Key not found"**: Ensure your private key is correctly uploaded to Supabase

### Common Google Sign-In Issues
- **"Invalid client ID"**: Check your OAuth credentials
- **"Redirect URI mismatch"**: Verify redirect URIs in Google Console
- **"API not enabled"**: Ensure Google+ API is enabled

## ✅ Success Checklist

- [ ] Apple Developer account configured
- [ ] Service ID created and configured
- [ ] Private key downloaded and uploaded to Supabase
- [ ] Google Cloud project created
- [ ] OAuth credentials created
- [ ] Supabase providers enabled
- [ ] iOS app capabilities added
- [ ] OAuth buttons working in app
- [ ] Users can sign in with Apple
- [ ] Users can sign in with Google

Your OAuth setup is now complete! Users can sign in with Apple or Google accounts. 🎉 