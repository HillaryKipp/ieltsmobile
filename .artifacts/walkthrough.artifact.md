# Walkthrough - Flutter App Updates

The IELTS Prep Flutter mobile app has been updated to align with the backend parity guide. Key features added include M-Pesa payment integration and improved media handling in practice tests.

## Changes Made

### Backend Parity & Payments
- **Configuration**: Added `webOrigin` to `lib/config.dart` to point to the shared backend API.
- **Payment Logic**: Added `initiateMpesaPayment` to `AuthState` to trigger STK Push via the backend.
- **Profile Screen**:
    - Added an "Upgrade to Premium" section.
    - Dynamically fetches the current price using the `get_public_price` RPC.
    - Allows users to trigger M-Pesa payments directly from the app.

### Practice Experience
- **Media Handling**:
    - Switched to `CachedNetworkImage` for better performance and offline caching.
    - Added support for `media_url` across all question types (MCQ, Writing, etc.), ensuring images are displayed above the question prompts.
- **Dependencies**: Added `cached_network_image`, `url_launcher`, and `http` to `pubspec.yaml`.

## Verification Results

### Code Analysis
- All modified files (`auth_state.dart`, `profile_screen.dart`, `practice_screen.dart`) passed static analysis with no errors.

### UI Improvements
- The Profile screen now correctly displays the membership status and provides an upgrade path if the user is not yet a premium member.
- Practice tests now show images for questions that have a `media_url` defined in the database.

> [!TIP]
> Run `flutter pub get` to install the new dependencies before building the app.
