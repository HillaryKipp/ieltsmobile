# Walkthrough: Fixed Unit Sorting

I have fixed the issue where practice units were being listed out of sequence on the Skill Screen.

## Changes Made

### UI Logic
#### [SkillScreen.dart](file:///C:/Users/hillary.kipkorir/.gemini/antigravity/scratch/ielts_prep/lib/screens/skill_screen.dart)
Modified the Supabase query to sort units strictly by their `order_index`. Previously, the list prioritized "Free" units at the top, which caused logical sections (e.g., Section 1, 2, 3) to be jumbled if they had different pricing statuses.

```diff
- supabase.from('units').select('*').eq('skill', widget.skill).order('is_free', ascending: false).order('order_index'),
+ supabase.from('units').select('*').eq('skill', widget.skill).order('order_index'),
```

## Verification Results

### Code Audit
- The `order_index` is now the primary (and only) sort key in the database query.
- The UI rendering logic in `_buildSliverTestList` correctly identifies `isAccessible` and `hasScore` based on the fetched data, ensuring that the "Free" badge and locking mechanism still work as intended.
- Verified that `order_index` in `models.dart` is correctly mapped from the database.

> [!TIP]
> This change ensures that students follow the practice curriculum in the intended pedagogical order.
