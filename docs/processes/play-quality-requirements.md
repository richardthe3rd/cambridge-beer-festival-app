# Google Play Technical Quality Requirements

What Google Play requires of this app technically, which requirements
actually apply, and how to re-measure when a deadline approaches.

Source: [Play Console technical quality requirements](https://support.google.com/googleplay/android-developer/answer/17492799)
(upcoming requirements announced 2026-08-26).

> `support.google.com` is blocked by the agent network proxy. An agent cannot
> read the source article directly — ask the maintainer to paste it, or work
> from the tables reproduced below.

## 1. Why this doc exists

Play publishes quality thresholds with enforcement dates 6–18 months out.
Most of them do not apply to this app, but that is a *measured* conclusion
with a shelf life, not a standing exemption. This doc records the
measurements and the exact commands to redo them, so a future session can
re-check in minutes instead of re-deriving the whole analysis.

**Nothing here is currently actionable.** The earliest deadline is February
2027 and the app is well inside every threshold.

## 2. Current requirements — met

| Requirement | Threshold | This app |
|---|---|---|
| Target API level (new apps + updates) | API 36 by 2026-08-31 | ✅ 36, via `flutter.targetSdkVersion` |
| Target API level (existing apps) | API 35 to stay available to new users | ✅ 36 |
| 16 KB page size | NDK r27+ | ✅ NDK 28.2.13676358 |
| User-perceived crash rate | < 1.09% | Play Console only — not checkable from the repo |
| User-perceived ANR rate | < 0.47% | Play Console only — not checkable from the repo |
| Per-device bad behaviour | < 8% crash / ANR | Play Console only |

`minSdk` (24), `targetSdk` (36) and `compileSdk` (36) all track the pinned
Flutter SDK — see [flutter-upgrade.md](flutter-upgrade.md) §2, including the
trap about the release-notes string that does *not* follow automatically.

Crash/ANR rates are only observable in Play Console's Android vitals.
Crashlytics is wired for fatal, non-fatal and async errors
(`lib/main.dart:51-66`), which is the in-repo half of that story.

## 3. Upcoming requirements — none apply

Announced 2026-08-26. All three assessed against the shipped **v2026.7.1**
artifact on 2026-08-26.

| Requirement | Enforced | Verdict |
|---|---|---|
| Reduced memory usage | Feb 2027 | Not applicable |
| DEX code optimization | Feb 2027 | Not applicable — under the size gate |
| Zero-Tap Sign-In Restoration | Apr 2027 | Not applicable — app has no sign-in |

### 3.1 Reduced memory usage

Thresholds are **90th-percentile anonymous RSS + swap**, by app state and
device RAM tier:

| Physical RAM (total memory) | Foreground | User-perceived services | Background | Cached |
|---|---|---|---|---|
| 0–4 GB (0–3200 MB) | – | – | – | – |
| 4 GB (3200–4800 MB) | 2 GB | 1 GB | 1 GB | – |
| 6 GB (4800–6800 MB) | 2.25 GB | 1.25 GB | 1.25 GB | – |
| 8 GB (6800–9216 MB) | 2.25 GB | 1.5 GB | 1.5 GB | – |
| 12 GB (9216–14336 MB) | 3.25 GB | 1.75 GB | 1.75 GB | – |
| 16 GB (14336–18432 MB) | 4.25 GB | 2 GB | 2 GB | – |
| 16 GB+ (above 18432 MB) | – | – | – | – |

Each tier range includes its lowest value. Total memory can be lower than a
device's advertised physical RAM.

Most of this grid never engages here:

- **No services.** The manifest is a single activity — no foreground or
  background services — so the services column is inapplicable and a
  backgrounded process drops to **Cached**, which has no threshold at any tier.
- **The lowest tier is exempt** (all `–`). That is exactly where an older
  phone at a festival sits.

That leaves **2 GB foreground on a 4 GB device** as the binding number.

What the app actually holds:

| | |
|---|---|
| Catalogue feed size | ~200 KB JSON across 7 categories (measured: `cbf2025/beer.json` 96 KB / 112 items, `cider.json` 23.5 KB / 35 items) |
| Resident catalogue | **One festival at a time** — `_allDrinks` is a flat `List<Drink>`, not a keyed multi-festival map |
| Derived cache | `_myFestivalEntriesCache` (`beer_provider.dart:52-57`) is pinned to a single `festivalId` with revision invalidation — no accumulation across festival switches |
| Bitmaps | One 192×192 `assets/app_icon.png`. **No network images anywhere.** |

Anonymous RSS is therefore the Flutter engine baseline plus roughly a
megabyte — on the order of 100–200 MB foreground for an app of this shape,
against a 2 GB threshold.

> This is a **reasoned bound, not a device measurement.** No profiling has
> been run. The margin is ~10–20×, so the conclusion survives a large
> estimation error, but do not quote a specific MB figure as measured.

### 3.2 DEX code optimization

Applies only to **apps with > 10 MB DEX code** (games: > 50 MB). Within that
gate, minimum 25% each for obfuscation, optimization and shrinking. Any
shrinker satisfies it — R8 is not mandated.

Measured on the shipped v2026.7.1 APK:

| | Measured | Gate |
|---|---|---|
| DEX (single `classes.dex`, uncompressed) | **2.96 MB** | applies above 10 MB |

**3.4× under the gate that would make the requirement apply.** The 25%
sub-thresholds are moot.

R8 is on regardless (`android/app/build.gradle:51-53` — `minifyEnabled`,
`shrinkResources`, `proguard-android-optimize.txt`), with full mode on by
default under AGP 8.11.1. A DEX string-table parse put obfuscated class type
descriptors at ~47%; treat that as a rough proxy, since it counts external
framework references alongside app-defined classes.

> `-keep class io.flutter.** { *; }` (`android/app/proguard-rules.pro:2`)
> retains 613 classes unobfuscated — the largest single retained package,
> ~14.5% of class types. It is broader than Flutter's own consumer rules
> require. **Leave it alone:** it costs nothing at this size, and loosening
> keep rules on the embedding is a classic source of release-only crashes.

For scale, the APK is 56.7 MB of which `lib/` is 51.5 MB — the fat APK
carrying every ABI. The AAB splits per device; DEX is identical either way.

### 3.3 Zero-Tap Sign-In Restoration

From April 2027, apps must support Restore Credentials so users are signed
back in without a tap after a device transfer.

**The app has no authentication of any kind** — no `firebase_auth`, no
sign-in, no credential handling. All user data lives in `UserDataStore` on
SharedPreferences. There is nothing for the requirement to attach to.

> **This is the one that can change.** If "My Festival" cloud sync (#315)
> introduces accounts, April 2027 becomes a live deadline. Design it in
> rather than retrofitting — tracked as a constraint on that campaign.

## 4. Re-verification

Re-run before each enforcement date, or after any change in §5.

```bash
# Target/min/compile SDK actually in effect (from the pinned Flutter SDK)
grep -n 'SdkVersion\|ndkVersion' \
  "$(grep flutter.sdk android/local.properties | cut -d= -f2)"/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt

# Sign-in surface — expect no matches
grep -rn 'firebase_auth\|GoogleSignIn\|CredentialManager\|RestoreCredential' lib/ pubspec.yaml

# Services in the manifest — expect none
grep -n '<service' android/app/src/main/AndroidManifest.xml

# Multi-festival retention — expect a flat List<Drink>, not a Map keyed by festival
grep -n '_allDrinks\s*=\|Map<String, List<Drink>>' lib/providers/beer_provider.dart
```

**DEX size** needs a built artifact, and this environment has no Android SDK.
Measure the published release APK instead:

```bash
V=2026.7.1   # latest release tag, minus the leading v
curl -sSL -o /tmp/cbf.apk \
  "https://github.com/richardthe3rd/cambridge-beer-festival-app/releases/download/v$V/cambridge-beer-festival-$V.apk"
python3 -c "
import zipfile
z=zipfile.ZipFile('/tmp/cbf.apk')
t=sum(i.file_size for i in z.infolist() if i.filename.endswith('.dex'))
print(f'DEX: {t/1024/1024:.2f} MB  (gate: 10 MB)')"
```

## 5. What would change these verdicts

Only three things, all currently hypothetical:

1. **Sign-in arrives** (most likely via #315 cloud sync) → §3.3 becomes a
   real April 2027 deadline.
2. **Drink or brewery photos arrive** → bitmap memory stops being a rounding
   error and becomes the dominant term in §3.1. This is also the point at
   which a caching image library earns its place; `cached_network_image` was
   removed as unused and would need re-adding deliberately.
3. **Multi-festival catalogues held resident at once** → §3.1's "one festival
   at a time" premise breaks. Still small in absolute terms, but it is the
   design direction that changes the shape.

DEX (§3.2) would need to roughly triple to reach the gate. No plausible
Dart-side change does that — DEX here is Flutter embedding plus plugins, and
Dart compiles to `libapp.so`, not DEX. Only adding several large
Java/Kotlin SDKs would move it.

## Provenance

Assessed 2026-08-26 against the shipped **v2026.7.1** APK
(`sha256:07de667d…`) and the working tree at commit `832e63c`. Memory figures
in §3.1 are reasoned bounds from catalogue and retention measurements, not
device profiling. DEX figures in §3.2 are direct measurements of the shipped
artifact. Crash/ANR rates in §2 were not checked — they require Play Console
access an agent does not have.
