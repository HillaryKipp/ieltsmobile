# Implementation Plan - Fix Unit Display and Ordering

This plan addresses two issues:
1. "Available Units" displaying as 0 when a user is not signed in on the Home Screen.
2. Units being displayed in the wrong order (free units should be first).

## Proposed Changes

### [Home Screen]

#### [MODIFY] [home_screen.dart](file:///C:/Users/hillary.kipkorir/.gemini/antigravity/scratch/ielts_prep/lib/screens/home_screen.dart)
- Update `_loadDashboardData` to fetch units even if the user is not authenticated.
- Ensure skill summaries correctly calculate `availableTests` from the fetched units for guest users.

### [Skill Screen]

#### [MODIFY] [skill_screen.dart](file:///C:/Users/hillary.kipkorir/.gemini/antigravity/scratch/ielts_prep/lib/screens/skill_screen.dart)
- Update the unit query to sort by `is_free` (descending) so that free units appear first.
- Keep `order_index` (ascending) as a secondary sort to maintain the intended sequence within free and premium categories.

## Verification Plan

### Automated Tests
- I will verify the code changes by checking the logic in `_loadDashboardData` and the Supabase query in `SkillScreen`.

### Manual Verification
- Verify that "Available Units" is non-zero on the Home Screen when logged out.
- Verify that units in the Skill Screen start with "Free" units.
