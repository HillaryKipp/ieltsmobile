# Implementation Plan - Replicate Web Dashboard Home Screen

The goal is to update the Home screen UI to match the professional dashboard design provided in the reference image. This will focus on redesigning the existing components to follow the new layout and styling.

## User Review Required

> [!IMPORTANT]
> - This plan focuses **exclusively on the Home screen**. Navigation (Sidebar/Bottom Nav) will remain as it is currently implemented (mobile-first).
> - I will use placeholder shapes/gradients for the header illustration as original assets are unavailable.

## Proposed Changes

### Home Screen Redesign

#### [MODIFY] [home_screen.dart](file:///C:/Users/hillary.kipkorir/.gemini/antigravity/scratch/ielts_prep/lib/screens/home_screen.dart)
- **Header**: Redesign with a more modern "Welcome" section, potentially using a background color or decorative elements to mimic the web header.
- **Top Dashboard Row**:
    - **Overall Band Card**: A red card with the score and "Good/Great" text on the left, and a circular "65%" progress indicator on the right.
    - **Your Progress Summary**: A row/grid section showing small icons and average band scores for Listening, Reading, Writing, and Speaking.
- **Skill Detail Cards**:
    - Implement a grid of 4 cards (2x2 on mobile, or 4 across if space allows) that look like the ones in the reference image.
    - Each card includes:
        - Skill name and icon.
        - "Latest Test" section with name, date, and score.
        - Stats table: "All Tests", "Mock Tests", "Average Score".
        - "Start Practicing" button with an arrow icon.
- **Recent Tests**: Restyle the horizontal list/rows at the bottom to match the clean white card design.

### Styling & Theme

#### [MODIFY] [theme.dart](file:///C:/Users/hillary.kipkorir/.gemini/antigravity/scratch/ielts_prep/lib/theme.dart)
- Update color constants if needed to match the specific shades of red, orange, green, and blue in the design.
- Refine `CardTheme` for shadows and border radius.

## Verification Plan

### Manual Verification
- **Visual Comparison**: Verify the new Home screen components against the reference image.
- **Data Display**: Ensure the "Latest Test" and "Stats" sections on the cards correctly pull data from the `UserAttempt` and `ScoreHistory` lists.
- **Interaction**: Verify the "Start Practicing" buttons and "View All" links navigate to the correct routes.
