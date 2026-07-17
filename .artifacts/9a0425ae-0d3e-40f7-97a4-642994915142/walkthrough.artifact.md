# Walkthrough - Unit Display and Ordering Fixes

I have fixed the issues regarding the display of available units for guest users and the ordering of units in the skill screens.

## Changes Made

### Home Screen
- **Guest Access to Unit Data**: Modified `_loadDashboardData` in [home_screen.dart](file:///C:/Users/hillary.kipkorir/.gemini/antigravity/scratch/ielts_prep/lib/screens/home_screen.dart) to fetch the list of units even when no user is signed in. This ensures the "Available Units" count on skill cards is correctly populated for guests.

### Skill Screen
- **Improved Unit Ordering**: Updated the unit query in [skill_screen.dart](file:///C:/Users/hillary.kipkorir/.gemini/antigravity/scratch/ielts_prep/lib/screens/skill_screen.dart) to sort by `is_free` descending first. This ensures that "Free" units appear at the top of the list, followed by premium units, while maintaining the secondary `order_index` sort.

## Verification Results

### Manual Verification
- **Home Screen (Guest)**: "Available Units" now shows the correct count of total units per skill instead of 0 when logged out.
- **Skill Screen**: Free units are now correctly prioritized at the beginning of the list.

> [!TIP]
> This change improves the onboarding experience for new users by immediately showing them available content and highlighting free practice units.
