# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

SliceIt is a modern expense-splitting Flutter app with Firebase integration. It supports multiple authentication methods (Google Sign-In and phone/SMS OTP) and is designed to run on Android, iOS, web, macOS, Linux, and Windows.

## Development Commands

### Setup & Dependencies
```bash
# Install Flutter dependencies
flutter pub get

# Generate Firebase configuration files (if needed)
flutterfire configure --project=sliceit-124

# Check Flutter setup and connected devices
flutter doctor
```

### Building & Running
```bash
# Run on default device (debug mode)
flutter run

# Run on specific device
flutter run -d <device-id>

# Build for specific platforms
flutter build apk                    # Android APK
flutter build appbundle             # Android App Bundle
flutter build ios                   # iOS (requires macOS)
flutter build web                   # Web application
flutter build macos                 # macOS app
flutter build linux                 # Linux app
flutter build windows               # Windows app
```

### Testing & Quality Assurance
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Analyze code for issues
flutter analyze

# Check code formatting
dart format --set-exit-if-changed .

# Format all Dart files
dart format .
```

### Firebase Integration
```bash
# Update Firebase configuration
flutterfire configure

# Deploy Firebase functions (if added later)
firebase deploy --only functions

# View Firebase project info
firebase projects:list
```

## Architecture Overview

### Authentication Flow
The app implements a two-step authentication system:
1. **Login Flow**: Existing users sign in with Google directly → HomeScreen
2. **Signup Flow**: New users sign up with Google → Phone verification (optional) → HomeScreen

**Login (Existing Users)**:
- Google Sign-In only
- Direct access to HomeScreen after successful authentication

**Signup (New Users)**:
- Google Sign-In first (creates account)
- Phone verification step (can be skipped)
- OTP verification if phone number provided
- All authentication data saved to both Firestore and Realtime Database

### Core Structure
- **`lib/main.dart`**: App entry point with Firebase initialization and splash screen
- **`lib/services/auth_service.dart`**: Centralized authentication logic handling both Google and phone auth
- **`lib/screens/`**: UI screens following the login/signup flow pattern:
  - `login_screen.dart`: Google Sign-In for existing users
  - `signup_screen.dart`: Google Sign-In for new users
  - `phone_verification_screen.dart`: Phone number entry (post-signup)
  - `otp_verification_screen.dart`: SMS OTP verification
  - `home_screen.dart`: Main app screen
- **`lib/utils/`**: Shared utilities for colors and text styles
- **`lib/widgets/`**: Reusable UI components

### Screen Navigation Flow
```
SplashScreen → OnboardingScreen → LoginScreen (Google Sign-In) → HomeScreen
                                      ↓
                               SignupScreen (Google Sign-In) → PhoneVerificationScreen → OtpVerificationScreen → HomeScreen
                                                                         ↓
                                                                 "Skip for now" → HomeScreen
```

### Firebase Configuration
- **Project ID**: `sliceit-124`
- **Services Used**: Authentication, Firestore, Realtime Database, Storage
- **Platforms**: Android, iOS, Web, macOS, Windows configured
- **Authentication Methods**: Google OAuth, Phone/SMS

### Design System
The app uses a consistent design system defined in `lib/utils/`:
- **Color Palette**: Olive green primary (#A4B640), with complementary colors
- **Typography**: Poppins for headings/buttons, Roboto for body text
- **Component Styling**: Rounded corners (12px), consistent spacing (24px padding)

### State Management
Currently using Provider package for state management, though no complex state is implemented yet in the current codebase.

## Development Guidelines

### File Organization
- Place new screens in `lib/screens/`
- Add reusable widgets to `lib/widgets/`
- Put services and business logic in `lib/services/`
- Store constants and utilities in `lib/utils/`

### Authentication Implementation
When extending authentication features:
- Always update both Firestore and Realtime Database in `AuthService._saveUser()`
- Handle authentication errors gracefully with user-friendly messages
- Maintain consistency between Google and phone auth flows

### Firebase Integration
- Use `firebase_options.dart` for platform-specific configuration
- Handle offline scenarios appropriately
- Implement proper error handling for Firebase operations

### UI/UX Patterns
- Use `AppColors` and `AppTextStyles` constants for consistency
- Follow the established navigation patterns with `MaterialPageRoute`
- Implement loading states and error handling for async operations
- Maintain the clean, modern design established in existing screens

### Asset Management
Assets are organized in the `assets/` directory:
- Images: `assets/images/`
- Fonts: `assets/fonts/` (Poppins and Roboto families)

### Platform-Specific Considerations
- Android: Uses `build.gradle.kts` with Google Services plugin
- iOS/macOS: GoogleService-Info.plist configured
- Web: Firebase web configuration included
- All platforms share the same Firebase project configuration