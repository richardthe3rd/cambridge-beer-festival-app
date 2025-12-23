# Festival Log: PR/FAQ

## Press Release

**Cambridge Beer Festival App Introduces "My Festival" Personal Tracker**

Festival-goers can now track their tasting journey with a new Festival Log feature that remembers what you want to try and what you've already tasted—even if you sample the same drink multiple times across different days.

**What's New:**

- **Personal Festival Tracker** - Build your own to-do list of drinks to try and mark them as tasted with a single tap
- **Multiple Tastings** - Enjoyed a favorite twice? The app tracks every time you taste a drink, with timestamps
- **At-a-Glance Status** - Visual indicators show which drinks are on your list while browsing, so you never forget what you planned to try
- **Festival History** - Keep records from past festivals and see your complete tasting journey over time
- **Simple, Clean UI** - No complicated sections or filters—just a unified list with intuitive icons (circle = to try, checkmark = tasted)

The feature is festival-scoped, so your CBF 2025 log stays separate from CBF 2024, letting you track your experience year after year.

---

## FAQ

### Q: What is the Festival Log?

**A:** The Festival Log (user-facing name: "My Festival") is a personal tracker that helps you plan and record which drinks you try at the festival. It has two states:
- **To Try** - Drinks you want to sample (grey circle icon)
- **Tasted** - Drinks you've already tried (green checkmark icon)

### Q: How is this different from the old favorites feature?

**A:** The old favorites were simple bookmarks. The new Festival Log is a complete tasting tracker:
- Supports **multiple tastings** with timestamps (try a favorite again on day 2!)
- Shows **try counts** (e.g., "3x") for drinks you've sampled multiple times
- Provides **festival summaries** at the end of your visit
- Is **festival-scoped** - your log for CBF 2025 stays separate from past festivals

### Q: Where do I see my log status while browsing drinks?

**A:** Every drink card shows a small badge in the top-right corner:
- Grey circle outline = on your "to try" list
- Green checkmark = you've tasted it
- Number (e.g., "3x") = you've tasted it multiple times

### Q: Can I mark a drink as tasted more than once?

**A:** Yes! Festival-goers often revisit favorites across multiple days. Each time you tap "Mark as Tasted," a new timestamp is recorded. You can see all your tasting times and edit them if needed.

### Q: Is my log synced across devices?

**A:** Not yet. Your log is currently stored locally on your device. Cloud sync is planned for a future update, which will sync your log, ratings, and tasting notes across all your devices.

### Q: What happens to my logs from previous festivals?

**A:** They're preserved! Each festival (CBF 2024, CBF 2025, etc.) maintains its own separate log. You can look back at what you tried at past festivals anytime.

### Q: How do I access "My Festival"?

**A:** Tap the "My Festival" button in the bottom navigation bar. The screen title shows your current festival (e.g., "My CBF 2025").

### Q: Can I filter or search my log?

**A:** No filtering or search within the log screen itself—we kept it simple. Your "to try" drinks appear first, followed by "tasted" drinks (slightly faded with green checkmarks). If you need to find a specific drink, use the main Drinks screen search.

### Q: What if I accidentally mark something as tasted?

**A:** You can remove it from your log entirely using the drink detail screen, or manually edit the tasting timestamp.

### Q: Will there be tasting notes?

**A:** Tasting notes are planned for a future update, along with cloud sync. The data model is already designed to support them.

---

## Technical Decisions

### Why "My Festival" instead of "Favorites"?

"Favorites" implied static bookmarks. "Festival Log" better captures the dynamic, time-based tracking of your festival experience.

### Why a unified list instead of sections?

User feedback preferred simpler UI without section headers. Visual indicators (icons, opacity, ordering) provide natural hierarchy without added complexity.

### Why support multiple tastings?

Real-world festival behavior—people often revisit favorites across multiple days or sessions. Single boolean "tried/not tried" doesn't capture this.

### Why festival-scoped data?

Users attend festivals year after year. Keeping logs separate prevents confusion and preserves festival history.

### Why timestamps instead of just counts?

Timestamps enable:
- Historical tracking ("when did I try this?")
- End-of-festival recaps and statistics
- Future features like daily summaries
- User corrections (edit if marked wrong day)

### Why local-first storage?

Works offline at festivals with poor connectivity. Cloud sync planned as future enhancement, not blocker for initial launch.
