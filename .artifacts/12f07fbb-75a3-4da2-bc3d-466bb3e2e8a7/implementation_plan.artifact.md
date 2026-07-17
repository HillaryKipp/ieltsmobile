# Implementation Plan - Enable Guest Browsing

The goal is to allow users to explore the app and try practice tests without being forced to log in immediately. Currently, the app redirects all unauthenticated users to the login screen upon startup.

## User Review Required

> [!IMPORTANT]
> - Unauthenticated users will be able to take tests, but their progress and scores will **not** be saved to the database. They will see their results only for the current session.
> - Certain features like "Stats" and "Profile" will show limited information or a prompt to sign in.

## Proposed Changes

### Navigation & Routing

#### [MODIFY] [routes.dart](file:///C:/Users/hillary.kipkorir/.gemini/antigravity/scratch/ielts_prep/lib/routes.dart)
- Remove the mandatory redirect to `/auth` for unlogged-in users in the `createRouter` function.
- Ensure that if a user is logged in and on the `/auth` page, they are still redirected to the home page.

### Screens

#### [MODIFY] [profile_screen.dart](file:///C:/Users/hillary.kipkorir/.gemini/antigravity/scratch/ielts_prep/lib/screens/profile_screen.dart)
- Add a check for unauthenticated state.
- If not logged in, display a friendly "Sign In" screen with a call-to-action button instead of the profile details and "Logout" button.

#### [MODIFY] [auth_screen.dart](file:///C:/Users/hillary.kipkorir/.gemini/antigravity/scratch/ielts_prep/lib/screens/auth_screen.dart)
- Add a "Continue as Guest" or "Skip" button to allow users who navigated to the auth screen to return to the main app without logging in.
- Alternatively, add an `AppBar` with a back button if it's not the initial screen.

#### [MODIFY] [home_screen.dart](file:///C:/Users/hillary.kipkorir/.gemini/antigravity/scratch/ielts_prep/lib/screens/home_screen.dart)
- Update the welcome message to be more generic if the user is not logged in (e.g., "Welcome, Learner!" instead of using a profile name).

## Verification Plan

### Manual Verification
- **Startup**: Launch the app and verify it opens the Home screen instead of the Auth screen.
- **Guest Usage**: Navigate through Skills, Unit Overview, and Practice screens as a guest.
- **Practice Test**: Complete a practice test as a guest and verify that the band score is shown but not saved to the profile.
- **Profile Redirection**: Click the Profile icon and verify it shows a "Sign In" prompt.
- **Authentication**: Sign in from the Profile prompt and verify it successfully logs in and shows user data.
