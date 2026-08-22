# Upgrading Flutter

How to raise the pinned Flutter SDK version, what breaks, and how to tell a
real regression from engine noise.

Written after the 3.44.0 → 3.47.1 upgrade (PR #591). Every number and
behaviour below was observed during that upgrade, not taken from release
notes.

---

## 1. What triggers an upgrade

**Nothing automated does.** No dependabot ecosystem manages the Flutter
version, and there is no Renovate config. The `pub` ecosystem updates
entries under `dependencies:`/`dev_dependencies:` only; `github-actions`
updates `subosito/flutter-action` itself but never the `flutter-version`
input it receives.

So the SDK moves only when a person decides it should. In practice there is
one reliable tripwire:

> **A dependabot PR fails at `pub get` with a message naming a package the
> Flutter SDK pins.**

That looks like a package problem and is actually an SDK ceiling. The 3.47.1
upgrade was triggered exactly this way — #572 bumped `mockito` and
`build_runner` and failed with:

```
Note: meta is pinned to version 1.18.0 by flutter_test from the flutter SDK.
...
mockito ^5.8.1 is incompatible with flutter_test from sdk.
```

`flutter_test` pinned `meta` to an exact version; anything pulling
`analyzer >= 13.3.0` needed `meta ^1.18.3`. Dependabot resolves *without* the
`flutter_test from sdk` constraint, so its lockfile looks valid and cannot
install. It regenerates the same red PR every week until someone intervenes.

**Dart is never upgraded separately.** It ships inside Flutter. The
`environment: sdk:` line in `pubspec.yaml` is a compatibility *range*, not a
pin — 3.44.0 bundles Dart 3.12.0, 3.47.1 bundles Dart 3.13.1. Dart-side
behaviour changes (formatter, analyzer) therefore arrive as side effects of a
Flutter bump, with nothing in the diff mentioning Dart.

## 2. Before bumping: check the floors, and check them all

Flutter ships its own hard requirements in
`packages/flutter_tools/gradle/src/main/kotlin/DependencyVersionChecker.kt`.
Read it from the *candidate* SDK rather than guessing:

```bash
F=$(find .mise -name DependencyVersionChecker.kt | head -1)
grep -nE "internal val (warn|error)[A-Za-z]*" "$F"
```

**Do not name the dependencies in that pattern.** Enumerate every constant.
The Kotlin floors are called `errorKGPVersion`/`warnKGPVersion`, so a grep
matching `Kotlin` silently returns nothing for them — that mistake cost a
third red CI run during the 3.47.1 upgrade, after the first two rounds had
already "checked the floors".

Each dependency has an `error` floor (build fails below it) and a `warn`
floor (recommended). **Check every floor before pushing** — a build reports
only the first one it hits, so fixing that one alone earns another red run.
The 3.47.1 upgrade failed three times for exactly this reason: Gradle, then
AGP, then Kotlin.

| | error floor | warn floor | project had | |
|---|---|---|---|---|
| Gradle | 8.14.0 | 9.1.0 | 8.11.1 | ❌ |
| AGP | 8.11.1 | 9.0.1 | 8.9.1 | ❌ |
| KGP (Kotlin) | 2.2.20 | 2.3.20 | 2.1.0 | ❌ |
| Java | 17 | 17 | 17 | ✅ |
| minSdk | 23 | 24 | 24, via `flutter.minSdkVersion` | ✅ |

`minSdk` is worth noting as the one that needs no action: it reads from
`flutter.minSdkVersion`, so it follows the SDK automatically.

Also check whether the target release actually fixes the dependency ceiling
that prompted the upgrade, before doing any work:

```bash
curl -s "https://raw.githubusercontent.com/flutter/flutter/<version>/packages/flutter_test/pubspec.yaml" \
  | grep -E "^[[:space:]]+(meta|collection|stream_channel):"
```

Patch releases within a line generally do **not** move these. 3.44.9 still
pinned `meta: 1.18.0`; 3.47 switched the whole block to caret ranges. If the
next minor doesn't lift the constraint, the upgrade won't help and pinning
back (per the #544 pattern — a dependabot `ignore` plus a tracking issue) is
the better answer.

## 3. Every place the version is pinned

Five, and the one that bites is not in the workflow files:

| Location | What it sets |
|---|---|
| `mise.toml` (`flutter = "..."`) | local + agent toolchain |
| `.github/actions/setup-flutter-app/action.yml` (`default:`) | **8 CI jobs**, incl. both release workflows |
| `.github/workflows/ci.yml` (`flutter-version:`) | the `fmt` job only |
| `.devcontainer/devcontainer.json` | IDE SDK paths (×2) |
| `.claude/hooks/session-start.sh` | comment only |

> **Trap:** grepping `.github/workflows/*.yml` for `flutter-version` finds
> only the `fmt` job — the single job that does *not* use the composite
> action. Every other job inherits the action's `default:`, which the grep
> never shows. This produced a full red CI run during the 3.47.1 upgrade:
> `fmt` was correctly configured and `analyze`/`test` still ran the old SDK.
>
> **Grep for the version string across the whole repo, not for the key name.**

```bash
grep -rn "3\.44\.0" --include="*.yml" --include="*.yaml" --include="*.toml" \
  --include="*.json" --include="*.sh" --include="*.md" . | grep -v '\.mise/'
```

Docs and skills that state the pinned version as current fact should move
with it. Leave historical records alone — example commit messages, ADRs
recording a past default, and dated "verified live" observations in skills
are not claims about the present.

## 4. Procedure

Work in a scratch worktree so `main` is never dirty. Each step answers one
question, so a failure tells you which.

```bash
git worktree add --detach .claude/worktrees/flutter-bump origin/main
cd .claude/worktrees/flutter-bump && ./bin/mise trust
```

1. **Bump every pin** from §3, plus any dependency versions the upgrade is
   meant to unblock.
2. **`./bin/mise install`** then **`./bin/mise deps`** — proves resolution.
   `mise.toml`'s `[deps.flutter] auto = true` means mise already runs pub
   resolution before every `mise run`/`mise exec`, so this failure would
   surface eventually anyway; running `deps` explicitly here makes it a
   named gate rather than a surprise inside a later task. Never a bare
   `dart pub get` — that resolves against whatever `dart` is on PATH, not
   the SDK you just pinned, and mise's auto-deps step would have run first
   regardless. If this fails, the upgrade doesn't help; stop here.
3. **`./bin/mise run test`** — separates behavioural failures from golden
   failures. Behavioural failures mean the upgrade is not safe; golden
   failures are expected and measured in §6.
4. **`./bin/mise run goldens:update`** — only after step 3 shows the failures
   are golden-only.
5. **Measure the golden churn** (§6) before accepting it.
6. **`./bin/mise run check`** — full gate.
7. Push, then let CI cover what you cannot (§7).

## 5. Expected knock-on changes

All three of these appear in the diff without you editing anything, and all
three are legitimate:

- **`.mocks.dart` (6 files)** — mockito regenerates them. In 5.8.x it stopped
  emitting its version in the header and added an `experimental_member_use`
  ignore. These files are deliberately committed (see `.gitignore`'s
  un-ignore of `test/**/*.mocks.dart`).
- **Formatter churn** — a Dart minor bump can restyle existing code. Dart
  3.13 restyled `expect()` calls taking a collection literal. Confirm it is
  purely formatter output by re-running `dart:format` and getting no further
  diff. CI's `fmt` job fails without it.
- **`analysis_options.yaml`** — Flutter 3.47's `analyze` writes an `exclude:`
  block for the platform directories *itself*, on every run. Isolate it by
  reverting the file, running `pub get` (stays clean), then `analyze` (it
  returns). Commit it, or every future analyze leaves a dirty tree. Note this
  file is on AGENTS.md's Do-Not-Modify list, so call it out explicitly in the
  PR.

## 6. Judging golden churn without eyeballing every PNG

A Flutter upgrade shifts goldens. The risk is that a real regression hides in
the churn, and reviewing 20+ PNGs by eye does not reliably catch one.

Measure instead. For each changed golden, compare the committed version
against the regenerated one and record three numbers:

- **% of pixels differing**
- **max channel delta** (0–255)
- **whether the image dimensions changed**

Engine anti-aliasing drift is bounded, uniform and dimension-preserving. A
real regression moves layout, changes an image's size, or produces a large
delta in a content region. The 3.47.1 upgrade regenerated 23 of 33 goldens
with:

| | worst | mildest |
|---|---|---|
| pixels differing | 0.33% | 0.03% |
| max channel delta | 35 / 255 | 22 / 255 |
| dimension changes | **0 of 23** | — |

Visually, the entire change was anti-aliasing on the rounded ends of chip
pills; on the worst-affected golden the changed region was a single
142×28 px band. Text, layout, spacing and colour were pixel-identical.

Treat those figures as a reference bar. Churn of that shape is safe to accept
wholesale. Anything materially larger — or any dimension change — should be
inspected individually before regenerating.

## 7. What CI has to verify for you

Whether you can check the Android floors locally depends on where you are
working. A machine with the Android SDK installed can run
`flutter build apk` and see them directly; the managed agent sandbox
(Claude Code Web) has no Android SDK, so there `build-android` is verified
only in CI — which is how the 3.47.1 upgrade was done. Budget for several
round-trips on the Android job — the 3.47.1 upgrade needed three, one per
floor — and read the *whole* failure rather than the first box:

> Flutter appends a "Flutter Fix" suggestion box after a Gradle failure. In
> the 3.47.1 upgrade it advised opting out of `android.newDsl` for "AGP 9+"
> — on a project pinned to AGP 8.9.1. The real error was further up
> (Gradle below 8.14.0). Acting on the box would have been wrong.

Also outside any automated check: manual browser and device testing on the
new engine. Flag it as outstanding rather than implying the green tick covers
it.

## 8. Staying on AGP 8

The checker prefers AGP 9, but AGP 9 reads only the new DSL and would require
migrating `android/app/build.gradle`. That is a separate change with its own
risk, not a prerequisite of a Flutter bump — clear the *error* floors and
leave the *warn* floors for a deliberate Android-side piece of work.

## Related

- [ci-cd.md](ci-cd.md) — the pipeline these jobs run in
- [release.md](release.md) — cutting a release once the bump has landed
- Skill `build-and-env` — mise bootstrap, environment layering, install traps
- Skill `validation-and-qa` — golden-update protocol and evidence hierarchy
