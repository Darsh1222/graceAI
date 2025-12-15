# TuneIn Data Storage Strategy

## Overview

This document outlines the data storage strategy for the TuneIn music practice app, which combines local iOS storage with a backend database for persistent user data and practice session history.

## Current Implementation

### 1. iOS App (Local Storage)
- **User Profiles**: Stored in `UserDefaults`
- **Practice Sessions**: Stored as JSON files in app's documents directory
- **Audio/Sheet Music Files**: Stored locally in app's documents directory
- **Data Models**: Well-defined Swift structs for `PracticeSession`, `UserProfile`, and `AnalysisResult`

### 2. Backend Server (New Database Storage)
- **SQLite Database**: `tunein_data.db` for persistent storage
- **User Management**: User profiles with statistics tracking
- **Session Storage**: All practice sessions stored with analysis results
- **File References**: Audio and sheet music file names stored (files remain local to iOS)

## Database Schema

### Users Table
```sql
CREATE TABLE users (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE,
    join_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_sessions INTEGER DEFAULT 0,
    average_accuracy REAL DEFAULT 0.0,
    total_practice_time REAL DEFAULT 0.0,
    current_streak INTEGER DEFAULT 0,
    best_accuracy REAL DEFAULT 0.0,
    favorite_pieces TEXT
);
```

### Practice Sessions Table
```sql
CREATE TABLE practice_sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    audio_file_name TEXT NOT NULL,
    sheet_music_file_name TEXT NOT NULL,
    piece_title TEXT,
    duration REAL DEFAULT 0.0,
    accuracy REAL,
    correct_notes INTEGER,
    total_notes INTEGER,
    missed_notes TEXT,
    tempo_feedback TEXT,
    timing_feedback TEXT,
    FOREIGN KEY (user_id) REFERENCES users (id)
);
```

## API Endpoints

### User Management
- `POST /users` - Create new user
- `GET /users/<user_id>` - Get user profile
- `GET /users/<user_id>/sessions` - Get user's practice sessions

### Analysis
- `POST /analyze` - Analyze practice session (includes user_id in form data)

### Health
- `GET /health` - Server health check

## Data Flow

### 1. User Registration
1. iOS app creates user profile locally
2. iOS app sends user data to backend (`POST /users`)
3. Backend creates user record in database
4. iOS app stores user_id for future requests

### 2. Practice Session
1. User records audio and selects sheet music
2. iOS app uploads files to backend (`POST /analyze`)
3. Backend processes files and runs analysis
4. Backend stores session data in database
5. Backend updates user statistics
6. Backend returns analysis results to iOS app
7. iOS app displays results and stores locally as backup

### 3. Data Retrieval
1. iOS app can fetch user profile from backend
2. iOS app can fetch practice history from backend
3. Local storage serves as backup/offline cache

## Benefits of This Approach

### 1. **Hybrid Storage Strategy**
- **Local Storage**: Fast access, works offline, reduces server load
- **Backend Storage**: Centralized data, cross-device sync, analytics

### 2. **Scalability**
- SQLite is lightweight but can handle thousands of users
- Easy to migrate to PostgreSQL/MySQL later if needed
- File storage remains local to reduce bandwidth

### 3. **Data Integrity**
- User statistics calculated server-side
- Consistent data across devices
- Backup and restore capabilities

### 4. **Privacy**
- Audio files stay on user's device
- Only metadata and analysis results stored on server
- User controls their data

## Implementation Steps

### Phase 1: Backend Database (Current)
- ✅ SQLite database setup
- ✅ User management endpoints
- ✅ Session storage in analyze endpoint
- ✅ Basic API testing

### Phase 2: iOS Integration
- [ ] Update iOS app to send user_id with analysis requests
- [ ] Add backend API client to iOS app
- [ ] Implement user registration/login flow
- [ ] Add session history fetching from backend

### Phase 3: Enhanced Features
- [ ] Cross-device synchronization
- [ ] Data export/import functionality
- [ ] Advanced analytics and insights
- [ ] Social features (leaderboards, sharing)

## Testing

### API Testing
```bash
cd audio_transcriber
python api_client.py
```

### Database Inspection
```bash
sqlite3 tunein_data.db
.tables
SELECT * FROM users;
SELECT * FROM practice_sessions;
```

## Future Considerations

### 1. **Authentication**
- Add JWT tokens for secure API access
- Implement user login/logout flow
- Add password hashing and security

### 2. **File Storage**
- Consider cloud storage for audio files (AWS S3, Google Cloud)
- Implement file compression and optimization
- Add file versioning and backup

### 3. **Analytics**
- Track user engagement and feature usage
- Generate practice insights and recommendations
- Create progress reports and goals

### 4. **Performance**
- Add database indexing for faster queries
- Implement caching for frequently accessed data
- Add pagination for large result sets

## Migration Strategy

### From Local-Only to Hybrid
1. **Backup Current Data**: Export existing local data
2. **User Registration**: Create backend accounts for existing users
3. **Data Sync**: Upload existing practice sessions to backend
4. **Gradual Migration**: New sessions go to backend, old ones remain local

### From SQLite to Production Database
1. **Schema Migration**: Export SQLite schema to PostgreSQL/MySQL
2. **Data Migration**: Transfer all data to new database
3. **Connection Update**: Update backend to use new database
4. **Testing**: Verify all functionality works with new database

## Security Considerations

### 1. **Data Protection**
- Encrypt sensitive user data
- Implement proper access controls
- Regular security audits

### 2. **Privacy Compliance**
- GDPR compliance for EU users
- Data retention policies
- User data deletion capabilities

### 3. **API Security**
- Rate limiting to prevent abuse
- Input validation and sanitization
- HTTPS enforcement

## Monitoring and Maintenance

### 1. **Database Maintenance**
- Regular backups
- Performance monitoring
- Storage optimization

### 2. **Error Handling**
- Comprehensive logging
- Error tracking and alerting
- Graceful degradation

### 3. **User Support**
- Data recovery procedures
- User data export tools
- Support for data migration

## Conclusion

This hybrid storage strategy provides the best of both worlds: fast local access for the user experience and reliable backend storage for data persistence and cross-device synchronization. The implementation is scalable, secure, and user-friendly while maintaining privacy and performance. 