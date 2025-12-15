# 🎵 graceAI - Music Practice Analysis App

A sophisticated iOS application that uses AI to analyze your music practice sessions, providing detailed feedback on accuracy, rhythm, and performance improvement over time.

## 🎯 What Does graceAI Do?

graceAI is a revolutionary music practice companion that transforms how musicians improve their skills. Here's how it works:

### The Process
1. **Record Your Practice**: Use your iPhone to record yourself playing a piece of music
2. **Upload Sheet Music**: Take a photo or upload the sheet music for the piece you're practicing
3. **AI Analysis**: Our advanced AI engine compares your performance against the sheet music
4. **Get Instant Feedback**: Receive detailed analysis on accuracy, timing, rhythm, and missed notes
5. **Track Progress**: View your improvement over time with beautiful charts and statistics
6. **Improve Faster**: Get personalized recommendations to focus your practice sessions

### What Makes It Special
- **Real-time Analysis**: Get feedback instantly as you practice
- **Visual Learning**: See exactly which notes you missed and when
- **Progress Tracking**: Watch your improvement over days, weeks, and months
- **Smart Insights**: AI-powered recommendations tailored to your skill level
- **Cloud Sync**: Access your practice history from any device

## ✨ Features

### 🎯 Core Functionality
- **Real-time Music Analysis**: Record your practice sessions and get instant AI-powered feedback
- **Sheet Music Integration**: Upload sheet music to compare against your performance
- **Performance Metrics**: Detailed accuracy, timing, and rhythm analysis
- **Progress Tracking**: Visual charts and statistics showing your improvement over time
- **Session History**: Complete history of all your practice sessions with filtering options

### 🔐 Authentication & Data
- **Supabase Integration**: Secure user authentication and cloud data storage
- **User Profiles**: Personalized profiles with skill levels and instrument preferences
- **Cloud Sync**: All your data is automatically synced across devices
- **Offline Support**: Practice sessions are saved locally and synced when online

### 📊 Analytics & Insights
- **Performance Charts**: Interactive charts showing accuracy trends over time
- **Timeframe Filtering**: View progress by Week, Month, or Year
- **Detailed Feedback**: AI-generated insights on missed notes, timing issues, and improvement areas
- **Practice Recommendations**: Personalized tips based on your performance patterns

## 🛠 Technical Stack

### Frontend
- **SwiftUI**: Modern iOS user interface framework
- **Combine**: Reactive programming for data flow
- **AVFoundation**: Audio recording and playback
- **Core Data**: Local data persistence

### Backend
- **Supabase**: Backend-as-a-Service for authentication and database
- **PostgreSQL**: Robust database with Row Level Security (RLS)
- **FastAPI**: Python backend for music analysis
- **Docker**: Containerized deployment

### AI & Analysis
- **Custom Music Analysis Engine**: Advanced algorithms for note detection and rhythm analysis
- **Real-time Processing**: Instant feedback during practice sessions
- **Machine Learning**: Pattern recognition for performance improvement suggestions

## 🔬 How The AI Analysis Works

### Step-by-Step Process
1. **Audio Processing**: Your recorded audio is processed to extract musical features
2. **Sheet Music Recognition**: The uploaded sheet music is analyzed to identify notes, timing, and structure
3. **Note Detection**: AI algorithms detect each note you played and when you played it
4. **Comparison Engine**: Your performance is compared against the sheet music note-by-note
5. **Rhythm Analysis**: Timing accuracy is measured against the expected tempo and rhythm
6. **Feedback Generation**: Detailed feedback is generated highlighting:
   - **Accuracy**: Percentage of notes played correctly
   - **Missed Notes**: Specific notes that were skipped or incorrect
   - **Timing Issues**: Notes played too early, too late, or with wrong duration
   - **Rhythm Patterns**: Analysis of your rhythmic accuracy
   - **Improvement Areas**: Specific recommendations for practice focus

### Technical Implementation
- **Audio Feature Extraction**: Uses advanced signal processing to identify musical notes
- **Optical Music Recognition (OMR)**: Converts sheet music images to digital notation
- **Pattern Matching**: Compares audio features against expected musical patterns
- **Machine Learning Models**: Trained on thousands of practice sessions for accurate analysis

## 🚀 Getting Started

### Prerequisites
- iOS 15.0 or later
- Xcode 14.0 or later
- Swift 5.7 or later
- Supabase account
- Python 3.8+ (for backend)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/graceAI.git
   cd graceAI
   ```

2. **Install iOS dependencies**
   ```bash
   cd "TuneIn Cursor"
   open "TuneIn Cursor.xcodeproj"
   ```
   - Open in Xcode
   - Dependencies will be automatically resolved via Swift Package Manager

3. **Configure Supabase**
   - Create a new Supabase project
   - Update `SupabaseConfig` in `ContentView.swift` with your project URL and anon key
   - Run the provided SQL schema in your Supabase SQL editor

4. **Set up Backend (Optional for local development)**
   ```bash
   cd backend
   pip install -r requirements.txt
   python real_music_server.py
   ```

### Database Schema

Run the following SQL in your Supabase SQL editor:

```sql
-- Create profiles table
CREATE TABLE public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT,
    name TEXT,
    skill_level TEXT DEFAULT 'beginner',
    instruments JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create sessions table
CREATE TABLE public.sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    audio_file_name TEXT,
    sheet_music_file_name TEXT,
    piece_title TEXT,
    duration DOUBLE PRECISION,
    analysis_method TEXT,
    total_user_notes INTEGER,
    extra_notes TEXT[],
    all_sheet_notes TEXT[],
    all_audio_notes TEXT[],
    overall_feedback TEXT,
    tips TEXT[],
    accuracy DOUBLE PRECISION,
    correct_notes INTEGER,
    total_notes INTEGER,
    missed_notes TEXT[],
    tempo_feedback TEXT,
    timing_feedback TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can view own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can view own sessions" ON public.sessions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own sessions" ON public.sessions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own sessions" ON public.sessions
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own sessions" ON public.sessions
    FOR DELETE USING (auth.uid() = user_id);

-- Create trigger for new user profile creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (
    id,
    email,
    name,
    skill_level,
    instruments
  )
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', 'User'),
    'beginner',
    '[]'::jsonb
  );
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error creating user profile: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
```

## 📱 Usage

### Getting Started
1. **Sign Up**: Create a new account with your email and password
2. **Set Up Profile**: Choose your skill level and instruments
3. **Record Practice**: Use the Practice tab to record your sessions
4. **Upload Sheet Music**: Add sheet music for comparison
5. **Get Analysis**: Receive detailed feedback on your performance
6. **Track Progress**: View your improvement over time in the History tab

### Practice Session
1. Navigate to the **Practice** tab
2. Record your audio performance
3. Upload corresponding sheet music
4. Tap **Analyze** to get AI feedback
5. Review detailed results and recommendations

### Viewing History
1. Go to the **History** tab
2. Use timeframe filters (Week/Month/Year)
3. View progress charts and session details
4. Tap any session to see full analysis results

## 🏗 Architecture

### App Structure
```
graceAI/
├── TuneIn Cursor/           # iOS App
│   ├── ContentView.swift    # Main UI and business logic
│   ├── Models/              # Data models
│   └── Views/               # SwiftUI views
├── backend/                 # Python Backend
│   ├── real_music_server.py # FastAPI server
│   └── requirements.txt     # Python dependencies
└── README.md               # This file
```

### Key Components
- **SupabaseService**: Handles authentication and data operations
- **DataManager**: Manages local data persistence
- **AnalysisEngine**: Processes audio and provides feedback
- **ChartComponents**: Interactive progress visualization

## 🔧 Configuration

### Supabase Setup
1. Create a new Supabase project
2. Get your project URL and anon key
3. Update `SupabaseConfig` in the app
4. Run the database schema SQL

### Backend Configuration
- Set up Python environment
- Install dependencies: `pip install -r requirements.txt`
- Configure audio processing libraries
- Deploy to your preferred cloud platform

## 🚀 Deployment

### iOS App
1. Configure signing certificates in Xcode
2. Set up App Store Connect
3. Archive and upload to App Store
4. Submit for review

### Backend
1. Deploy FastAPI server to cloud platform (AWS, Google Cloud, etc.)
2. Configure environment variables
3. Set up database connections
4. Configure CORS for mobile app access

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Supabase** for backend infrastructure
- **SwiftUI** for modern iOS development
- **FastAPI** for Python backend framework
- **OpenAI** for AI analysis capabilities

## 📞 Support

For support, email support@graceai.com or create an issue in this repository.

## 🔮 Roadmap

- [ ] Real-time collaboration features
- [ ] Advanced AI analysis algorithms
- [ ] Integration with music streaming services
- [ ] Social features and sharing
- [ ] Advanced practice scheduling
- [ ] Multi-instrument support
- [ ] Custom analysis templates

---

**Made with ❤️ for musicians who want to improve their practice sessions**
