# Design Language

How the app's screens are composed and why. These are the working principles
that shape a new screen or a restyle — the "grammar" the UI is written in, so
that a drink card, a detail screen, and a future My Festival surface read as
one product rather than a pile of independently-styled pages.

This is a *reference*, not a rulebook: it records the choices the app has
settled into and the reasoning behind them, so the next screen doesn't
re-derive them (or contradict them) by accident. The drink **detail** screen
is used throughout as the worked example, because it's where these principles
were made explicit (PR #472).

For the enforcement layer — the `Semantics` catalogue, the golden-update
protocol, and the anti-sweeping-redesign discipline — see skill
`ui-and-accessibility` and [`accessibility.md`](accessibility.md). For
from-scratch visual-identity direction (palette, type pairing), see skill
`frontend-design`. This doc sits above both: it's the *why* those rules point
at.

---

## 1. One job per surface

Each visual surface (a card, a bar, a button) should do exactly one job, and
its job should be nameable in a few words. When a surface accumulates a second
job, split it.

The detail screen resolves into three surfaces, each with one job:

| Surface | Its one job |
|---|---|
| `DrinkHeroPanel` | **This is the drink** — identity and the festival's facts about it |
| `YourTakeCard` | **This is your relationship to it** — want-to-try, rating, note |
| The floating "Drunk it!" FAB | **The one thing you repeat** — log a pour |

Before this, the top of the screen was a header *plus* a HeroInfoCard *plus* a
standalone style chip *plus* a Brewery section *plus* a bottom action bar
carrying four unrelated actions. Every one of those was a surface doing part of
several jobs. Collapsing them until each surface had a single job is what made
the screen legible.

**Tell:** if you can't say what a card is *for* without the word "and," it's
carrying two jobs.

## 2. Reuse the identity mark; don't invent a new container

The app already had a way to say "this is a drink of category X": the
**category-colour left edge** on the list card and the Similar Drinks carousel
card (`CategoryColorHelper.getAccentColor`). The detail hero wears the *same*
mark rather than inventing a new one.

The rejected alternative was the old HeroInfoCard's filled colour block (the
"blue box"). A filled container is a louder, more decorative device that exists
only on that one screen — it says "look at me," not "this is a beer." Reusing
the left-edge mark means the identity signal is *consistent across screens* and
spends no extra visual weight. One mark, learned once, works everywhere.

**Principle:** when you need to signal something the app already signals
elsewhere, reuse that signal. A new screen-local container is a new thing the
user has to learn, and it fragments the visual identity.

## 3. Group by ownership

Content on a screen has an owner: either it's *the drink's* (the festival's
facts about it) or it's *yours* (what you did with it). Group by that owner and
let the groups read as distinct blocks, in that order.

On the detail screen the read order is two clean blocks:

```
┌─ the drink ──────────────┐   hero: name, ABV, facts, dietary rows,
│  (category-edged card)   │   and the catalogue "About This Drink" notes
└──────────────────────────┘   — all inside the one edged unit
┌─ you ────────────────────┐   "Your take": want-to-try, rating, note
│  (outlined card)         │   then the tasting log below
└──────────────────────────┘
```

The catalogue "About This Drink" notes are the drink's *own* content, so they
live **inside** the hero card, under a divider — not floating between the hero
and Your Take, where they interleaved the two owners and made Your Take feel
orphaned. Your Take gets its own heading and a subtle outline so it reads as
the distinct "you" panel, especially in dark mode.

**Principle:** ownership is structure. Don't interleave "about the thing" and
"about you" — the reader is doing two different jobs (learning vs recording)
and the layout should let them do one, then the other.

## 4. An action belongs with its subject, at its subject's scope

An action's home is determined by *what it acts on*, and the scope of the
chrome it sits in must match the scope of the thing it affects.

Share moved **off the app bar and into the hero.** The app bar is
festival-scoped chrome; Share acts on *this drink*. Sitting in festival chrome,
it read as "share the festival." Sitting in the hero, next to the drink's name,
it reads correctly. Same for want-to-try and rating: they're *your*
relationship to the drink, so they belong in Your Take, not on a generic bottom
bar.

The same rule governs *ephemeral* surfaces. The "Drunk it!" confirmation
SnackBar is scoped to the detail screen's own `ScaffoldMessenger` (via a
`GlobalKey`), not the app-level messenger — because it's about *this drink*. On
the app messenger it outlived the screen: tap a Similar Drink and a "Logged — N
tastings · Undo" toast about the drink you just *left* floated over the new one,
with Undo acting on the wrong drink. Screen-scoped, it's covered on push and
disposed on pop; it can't leak across a navigation boundary.

**Principle:** put an action where its subject is, and give a transient surface
the lifetime of the thing it's about. Chrome scope is not cosmetic — it's a
claim about what the control affects.

## 5. Surface decision-information at its true tier — inline, not boxed

Dietary facts (vegan, "Contains: …" allergens) are *decision* information: they
change whether someone will drink the thing. That makes them top-tier — the
same tier as the drink's name and ABV — so they live in the hero, visible
without scrolling.

They're rendered **inline** (an icon row; allergens in the error colour), not
in a heavy full-width warning box below the fold. The box treatment
over-weighted them *and* buried them at the same time: loud styling, low
position. Inline-at-the-top gets the priority right without shouting.

**Principle:** priority is expressed by *position*, not by decoration. If
something matters, put it high; don't compensate for burying it with a louder
box.

## 6. Don't invent UI vocabulary

Vegan status is shown on the list card as plain information, not as a "chip." An
early mockup rendered it as a pill/chip — inventing a control-like affordance
for a fact that isn't interactive and isn't a filter value. That was cut: a
chip implies "tappable / filterable," and mislabels a static fact as a control.

**Principle:** every recurring visual form (chip, pill, card, link) is a word in
the interface's vocabulary with an established meaning. Don't spend a word on
something that isn't what the word means. A fact is not a chip; a link must look
tappable *and be tappable* (see §7).

## 7. State lives in one place — don't bake it into a label

The count of pours is **state**. It's shown in one place — the "Your Tastings"
log. The "Drunk it!" FAB label stays constant no matter how many pours are
logged; it does not become "Drunk it! (3x)".

Baking the count into the button duplicates state into a control's label, where
it competes with the button's *job* (invite the next tap) and has to be kept in
sync. The SnackBar restores the count *contextually* at the moment it's
relevant ("Logged — N tastings"), then gets out of the way.

The link-affordance version of the same rule: the hero's Style cell keys its
entire link appearance — underline, chevron, tap semantics — off whether an
`onStyleTap` callback exists (`styleIsLink = onStyleTap != null`), not off
whether the drink *has* a style. A cell must never look tappable unless it
actually is. Appearance is derived from the one source of truth (the callback),
so the two can't drift.

**Principle:** each piece of state has one home. A control reflects state; it
doesn't store a second copy in its label.

## 8. Consequential actions need felt feedback — reliable and reversible

Logging a pour is a real, persisted mutation, but its only original signal was
the tasting log updating — usually scrolled off-screen. It felt like nothing
happened. The fix is layered, deliberate confirmation:

- a medium **haptic** on tap (`HapticFeedback.mediumImpact`),
- a quick **scale-bounce** on the FAB itself (the thing you touched responds),
- a floating **SnackBar** with the contextual count and an **Undo**, announced
  to screen readers.

Feedback also has to be *trustworthy*. Undo removes the **exact** pour just
logged: `addTasting` owns and returns the pour's timestamp, so Undo targets that
precise event rather than re-reading the drink and guessing "the newest one" (a
heuristic that picks the wrong pour if the device clock moves backward). And per
§4 it's scoped so it can't act on the wrong drink after navigation.

**Principle:** the weight of the feedback should match the weight of the action,
a control should visibly respond to its own tap, and any "undo" must reverse
*exactly* what happened — feedback that's approximate is worse than none,
because it teaches the user not to trust it.

## 9. Spend boldness once; keep the rest quiet

The screen has one bold move — the category-edged identity hero — and
everything around it is disciplined: plain surfaces, one accent mark, a single
floating action, restrained type. The old screen spread its boldness across a
filled colour block, a chip, section headers, and a four-button bar, and the
result read as busy without being expressive.

**Principle:** pick the one thing the screen is remembered by and let it be
bold; make everything else calm enough to let it be seen. (This is the
`frontend-design` "spend your boldness in one place" rule, applied in-repo.)

---

## Working discipline (how these land safely)

These are design *principles*; the process rules that keep applying them from
regressing the app live in skill `ui-and-accessibility`. The two that matter
most here:

- **Restructure and restyle are separate changes.** Moving a control to a new
  surface (structure) and changing how a surface looks (style) are reviewed and
  shipped separately, in small increments — PR #472 landed as a sequence of
  focused commits (hero → Your Take → single FAB → dietary rows → feedback),
  each with its own goldens, not one sweeping rewrite. Sweeping redesigns are
  this project's costliest historical failure mode.
- **Every visual change is captured in light *and* dark goldens**, and every
  new interactive element gets a `Semantics` label and a semantic test. A
  golden proves the layout; it does not prove the words — assert what the user
  reads and hears, not just that a box moved.

## Related

- [`accessibility.md`](accessibility.md) — the `Semantics` contract these
  surfaces must meet
- [`ui-components.md`](ui-components.md) — shared components and when to reuse
  vs. build
- [`widget-standards.md`](widget-standards.md) — widget-level patterns
- Skill `ui-and-accessibility` — the shared-widget reuse table and the
  screen patterns that must never regress
- Skill `frontend-design` — from-scratch visual-identity direction
