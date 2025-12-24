# Festival Log Design Document

**Status**: 💡 Proposal (not yet implemented)

**Context**: 🚀 Pre-release - No existing user data, no backward compatibility needed

## Overview

The Festival Log (user-facing name: "My Festival") transforms the simple favorites feature into a comprehensive tasting tracker that helps users plan and record which drinks they try at the festival.

**Important**: This feature is being designed during pre-release (before v1.0). There are no existing users with saved data, and no URLs have been shared publicly. This allows us to design the optimal data structure and architecture without migration or backward compatibility concerns.

## Design Decisions

### Feature Scope

**Two primary states:**
- **Want to Try** - Drinks users plan to sample (grey circle icon)
- **Tasted** - Drinks users have tried (green checkmark icon)

**Key capabilities:**
- Track multiple tastings of the same drink with timestamps
- Festival-scoped data (CBF 2025 separate from CBF 2024)
- Visual status indicators on all drink cards
- Simple, unified list view (no complex sections or filters)

### Data Model

**FavoriteItem structure:**
```dart
class FavoriteItem {
  final String id;                  // Drink ID
  final String status;              // 'want_to_try' | 'tasted'
  final List<DateTime> tries;       // Timestamps of tastings
  final String? notes;              // Optional user notes
  final DateTime createdAt;         // When added to list
  final DateTime updatedAt;         // Last modified
}
```

**Storage:**
- Local-first: SharedPreferences (migrate from existing Set<String> favorites)
- Festival-scoped: `/festivals/{festivalId}/favorites`
- Cloud sync: Deferred to future phase

### User Experience

**Discovery:**
- Status badges visible on all drink cards while browsing
- Badge shows current state at a glance

**Actions:**
- Add to "Want to Try" - Single tap on heart/bookmark icon
- Mark as "Tasted" - Dedicated button on drink detail screen
- Multiple tastings - Tap "Mark as Tasted" again to add timestamp

**Festival Log Screen:**
- Unified list (replaces current Favorites screen)
- Smart sort order: "Want to Try" drinks first, then "Tasted" drinks
- Visual divider between sections
- Empty states for each section

### Visual Design

**Status Indicators:**
- **Want to Try**: Grey circle outline icon (○)
- **Tasted (once)**: Green checkmark icon (✓)
- **Tasted (multiple)**: Green checkmark + count badge (✓ 3x)

**Design principles:**
- Subtle, clean design that doesn't clutter drink cards
- Accessible with good color contrast (WCAG AA)
- Clear Semantics labels for screen readers
- 24x24px minimum icon size for touch targets

### Interaction Design

**Adding to "Want to Try":**
1. User taps bookmark/heart icon on drink card or detail screen
2. Drink appears in Festival Log with "Want to Try" status
3. Grey circle badge appears on drink card

**Marking as "Tasted":**
1. User opens drink detail screen
2. Taps "Mark as Tasted" button
3. Timestamp recorded
4. Status changes to "Tasted" with green checkmark
5. Drink moves to "Tasted" section of Festival Log

**Multiple Tastings:**
1. User taps "Mark as Tasted" again on subsequent days
2. New timestamp added to tries list
3. Badge shows count (e.g., "3x")
4. Detail screen shows list of tasting timestamps

**Editing Timestamps (v1):**
- Delete only (no editing)
- Confirmation dialog before deletion
- Can delete and re-add if needed

**Future (v2):**
- Edit timestamps
- Add notes per tasting
- Export tasting history

### Backwards Compatibility

**Pre-release status: No migration needed!**

Since this is being implemented before v1.0 release:
- ❌ No existing user data to migrate
- ❌ No old favorites format in production
- ✅ Can use optimal data structure from day 1
- ✅ Storage format: `Map<String, FavoriteItem>` (no legacy Set<String> format)

**Storage key format:**
```dart
'${festivalId}_favorites' // Clean, simple key (no version suffix needed)
```

**What this means for implementation:**
- Skip all migration code
- Skip migration tests
- Skip idempotency concerns
- Just implement the v2 format directly

### Analytics Events

Track key user actions:
- `festival_log_add_to_try` - Added drink to "Want to Try"
- `festival_log_mark_tasted` - Marked drink as tasted
- `festival_log_multiple_tasting` - Marked same drink tasted again (count)
- `festival_log_delete_timestamp` - Deleted a tasting timestamp
- `festival_log_viewed` - Opened Festival Log screen

## Design Alternatives Considered

### Visual Design

**Alternative A: Color-coded backgrounds**
- Pros: Very clear visual distinction
- Cons: Accessibility issues, cluttered appearance
- **Decision: Rejected** - Icon badges are cleaner and more accessible

**Alternative B: Opacity + icon**
- Pros: Clear hierarchy, faded items less prominent
- Cons: Faded text harder to read, looks disabled
- **Decision: Rejected** - Confusing visual state

**Alternative C: Sections with headers**
- Pros: Very clear organization, can collapse sections
- Cons: Not unified list (contradicts PR/FAQ), more scrolling
- **Decision: Rejected** - Unified list is simpler

### Timestamp Editing

**Alternative A: Append-only (no editing/deleting)**
- Pros: Simple, no data loss
- Cons: Can't fix mistakes
- **Decision: Rejected for v1** - Too rigid, frustrating for users

**Alternative B: Edit and delete freely**
- Pros: Full flexibility
- Cons: More complex UI, accidental data loss
- **Decision: Deferred to v2** - Add based on user feedback

**Alternative C: Edit with audit trail**
- Pros: Full history preserved
- Cons: Overkill for casual use, very complex
- **Decision: Rejected** - Too complex for a festival app

## Implementation Notes

### Phase 3: Data Model
1. Create FavoriteItem model with serialization
2. Update StorageService to use new format
3. Implement migration from old favorites
4. Update BeerProvider with new methods (markAsTried, addToWantToTry, etc.)
5. Comprehensive tests for migration and data integrity

### Phase 4: UI
1. Add status badges to drink cards
2. Update drink detail screen with try tracking UI
3. Redesign Favorites screen as Festival Log
4. Add empty states and helpful messaging
5. Accessibility: Semantics labels, contrast, touch targets

### Testing Requirements

**Critical paths to test:**
- Migration from old favorites (data integrity)
- Adding/removing from "Want to Try"
- Marking as tasted (single and multiple)
- Timestamp deletion with confirmation
- Festival-scoped data separation
- Empty states and edge cases

## Related Documents

- **[implementation-plan.md](implementation-plan.md)** - Step-by-step implementation guide
- **[detailed-decisions.md](detailed-decisions.md)** - Detailed decision rationale with pros/cons
- **[../../processes/festival-data-prs.md](../../processes/festival-data-prs.md)** - User-facing FAQ (PR/FAQ format)
- **[../deep-linking/design.md](../deep-linking/design.md)** - Related: Festival-scoped URLs

---

**Last Updated**: December 2025
**Status**: 💡 Proposal - Awaiting implementation
