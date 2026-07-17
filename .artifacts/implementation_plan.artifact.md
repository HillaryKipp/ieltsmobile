# Implementation Plan - Flutter App Updates

Update the IELTS Prep Flutter mobile app to align with the backend parity guide, specifically focusing on payment integration, deep-link handling improvements, and UI consistency with question media.

## User Review Required

> [!IMPORTANT]
> I will be adding `cached_network_image` and `url_launcher` dependencies to `pubspec.yaml`. Please ensure you have a working Flutter environment to run `flutter pub get`.

> [!NOTE]
> The M-Pesa STK Push integration assumes that the endpoint `${Env.webOrigin}/api/public/mpesa/initiate` exists on your web backend.

## Proposed Changes

### Dependencies

#### [MODIFY] [pubspec.yaml](file:///C:/Users/hillary.kipkorir/.gemini/antigravity/scratch/ielts_prep/pubspec.yaml)
- Add `cached_network_image` and `url_launcher`.

### Configuration

#### [MODIFY] [config.dart](file:///C:/Users/hillary.kipkorir/.gemini/antigravity/scratch/ielts_prep/lib/config.dart)
- Add `webOrigin` constant.

### Auth & State

#### [MODIFY] [auth_state.dart](file:///C:/Users/hillary.kipkorir/.gemini/antigravity/scratch/ielts_prep/lib/auth_state.dart)
- Add `initiateMpesaPayment` method to handle STK push.
- Ensure `refreshProfile` is called after successful payment (handled via polling or manual refresh).

### UI & Screens

#### [MODIFY] [profile_screen.dart](file:///C:/Users/hillary.kipkorir/.gemini/antigravity/scratch/ielts_prep/lib/screens/profile_screen.dart)
- Implement "Upgrade to Premium" section.
- Fetch price using `supabase.rpc('get_public_price')`.
- Add M-Pesa payment flow (Phone input + Trigger button).

#### [MODIFY] [practice_screen.dart](file:///C:/Users/hillary.kipkorir/.gemini/antigravity/scratch/ielts_prep/lib/screens/practice_screen.dart)
- Replace `Image.network` with `CachedNetworkImage`.
- Add a shared `_buildMediaUrlWidget` to show images for all question types if `mediaUrl` is present.
- Integrate `_buildMediaUrlWidget` into the question input rendering logic.

## Verification Plan

### Manual Verification
- Verify `pubspec.yaml` compiles (after `flutter pub get`).
- Verify `Env.webOrigin` is correctly set.
- Check "Profile" screen for the new "Upgrade" section.
- Test deep-link handling by triggering a password reset and clicking the link (simulated via `adb shell am start ...` or similar).
- Verify images in "Practice" screen load using `CachedNetworkImage`.
