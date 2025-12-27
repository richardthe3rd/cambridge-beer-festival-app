# Safe Caching Strategy for GitHub Actions

## Philosophy: Cache Downloads, Not Build Artifacts

**Golden Rule**: Only cache things downloaded from the internet, not things generated from your code.

---

## ✅ Recommended Safe Caches

### 1. npm Dependencies (SAFEST)

**Add to all Node.js steps:**

```yaml
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    node-version: '22'
    cache: 'npm'  # ✅ Official, battle-tested
    cache-dependency-path: |  # ✅ For multiple package.json files
      package-lock.json
      scripts/package-lock.json
      cloudflare-worker/package-lock.json
```

**Why safe:**
- Official GitHub feature
- Only caches `node_modules` from npm registry
- Auto-invalidates on package-lock.json changes
- Used by millions of repos

**Files to update:**
- `.github/workflows/build-deploy.yml` (test-e2e-web job)
- `.github/workflows/cloudflare-worker.yml` (all jobs with Node)

**Expected savings**: 10-30s per job with npm install

---

### 2. Flutter Pub Cache (CONSERVATIVE)

**Add to all Flutter workflows:**

```yaml
- name: Setup Flutter
  uses: subosito/flutter-action@v2
  with:
    flutter-version: '3.38.3'
    channel: 'stable'
    cache: true  # ✅ Caches Flutter SDK

- name: Cache pub packages
  uses: actions/cache@v4
  with:
    path: ~/.pub-cache
    key: ${{ runner.os }}-pub-${{ hashFiles('**/pubspec.lock') }}
    restore-keys: |
      ${{ runner.os }}-pub-
```

**What's cached:** Downloaded packages from pub.dev only

**What's NOT cached:** `.dart_tool`, generated code, build artifacts

**Why safe:**
- Only caches immutable packages
- pubspec.lock guarantees exact versions
- Flutter rebuilds package symlinks automatically

**Trade-off:**
- `flutter pub get` still runs (links packages: ~5-10s)
- But packages aren't re-downloaded (~20-30s saved)
- Net savings: ~20-30s per job

**Files to update:**
- `.github/workflows/build-deploy.yml` (test, build-web, build-android jobs)
- `.github/workflows/release-android.yml`
- `.github/workflows/release-web.yml`

---

### 3. Gradle Dependencies (ALREADY IMPLEMENTED ✅)

**Current implementation is good:**

```yaml
- name: Cache Gradle dependencies
  uses: actions/cache@v4
  with:
    path: |
      ~/.gradle/caches
      ~/.gradle/wrapper
    key: ${{ runner.os }}-gradle-${{ hashFiles('**/*.gradle*', '**/gradle-wrapper.properties') }}
    restore-keys: |
      ${{ runner.os }}-gradle-
```

**Optional enhancement** (low priority):

```yaml
path: |
  ~/.gradle/caches
  ~/.gradle/wrapper
  ~/.android/build-cache  # ⚠️ Only if you trust Gradle's incremental build
```

**Why hesitant:** Android build cache can be finicky across machines

**Recommendation:** Leave as-is unless you see consistent build issues

---

## ❌ Caches to AVOID

### 1. build_runner Outputs

```yaml
# ❌ DON'T DO THIS
- name: Cache generated code
  uses: actions/cache@v4
  with:
    path: |
      .dart_tool/build
      **/*.mocks.dart
```

**Problems:**
- Cache key can't track all generation inputs
- Stale mocks cause hard-to-debug test failures
- build_runner is fast enough (10-30s)

**Better:** Just run `dart run build_runner build` every time

---

### 2. .dart_tool Directory

```yaml
# ❌ DON'T DO THIS
path: ${{ github.workspace }}/.dart_tool
```

**Problems:**
- Contains build artifacts, not just package configs
- Can cache stale analyzer snapshots
- Flutter/Dart version changes break cache

**Better:** Let Flutter rebuild this every time (fast anyway)

---

### 3. Flutter Build Outputs

```yaml
# ❌ DON'T DO THIS
path: build/web
```

**Why:** The whole point of CI is to build fresh every time!

---

## 🧪 Testing Cache Changes Safely

### Step 1: Add Cache to One Job

```yaml
# Test in test job first
test:
  steps:
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.38.3'
        channel: 'stable'
        cache: true

    - name: Cache pub packages (TESTING)
      uses: actions/cache@v4
      with:
        path: ~/.pub-cache
        key: ${{ runner.os }}-pub-${{ hashFiles('**/pubspec.lock') }}
        restore-keys: |
          ${{ runner.os }}-pub-
```

### Step 2: Verify Cache Behavior

**First run (cache miss):**
```
Cache not found for input keys: ubuntu-latest-pub-abc123
Downloading packages... (30s)
Post job: Saving cache...
Cache saved successfully
```

**Second run (cache hit):**
```
Cache restored from key: ubuntu-latest-pub-abc123
Linking packages... (5s)
Post job: Cache hit occurred, not saving
```

### Step 3: Verify Correctness

- Tests still pass ✅
- No weird "package not found" errors ✅
- Build outputs are identical ✅

### Step 4: Roll Out to Other Jobs

Once verified in `test` job, add to `build-web`, `build-android`, etc.

---

## 🔍 Monitoring Cache Health

### Check Cache Hit Rate

```bash
# GitHub CLI
gh run list --workflow=ci.yml --limit=10 --json conclusion,name

# Look for "Cache restored" vs "Cache not found" in logs
```

**Good:** 70-90% hit rate
**Bad:** <50% hit rate (cache thrashing)

### Watch for These Red Flags

1. **Tests pass locally, fail in CI** → Stale cache issue
2. **"Package not found" errors** → Cache path wrong
3. **Cache size growing indefinitely** → Need better invalidation
4. **Builds slower with cache than without** → Cache overhead too high

### Emergency: Clear All Caches

If caching causes issues:

```yaml
# Temporary: Bust all caches by changing key
key: v2-${{ runner.os }}-pub-${{ hashFiles('**/pubspec.lock') }}
#    ^^ Add version prefix
```

Or use GitHub UI: Settings → Actions → Caches → Delete all

---

## 📊 Expected Performance Impact

### Before Caching (Current)

```
test job:
  Setup Flutter: 15s (cached by flutter-action)
  flutter pub get: 35s ← downloading from pub.dev
  build_runner: 25s
  flutter test: 45s
  Total: ~2m 30s
```

### After Conservative Caching

```
test job:
  Setup Flutter: 5s (cache hit)
  Restore pub cache: 3s
  flutter pub get: 8s ← only linking, not downloading
  build_runner: 25s (no change)
  flutter test: 45s
  Total: ~1m 30s

Savings: ~1 minute (40% faster)
```

### Per-Job Savings Estimate

| Job | Current | With Cache | Savings |
|-----|---------|------------|---------|
| test | 2m 30s | 1m 30s | 1m (40%) |
| build-web | 2m 00s | 1m 15s | 45s (38%) |
| build-android | 3m 00s | 2m 15s | 45s (25%) |
| test-e2e-web | 1m 30s | 1m 00s | 30s (33%) |

**Total workflow**: 9m 00s → 6m 00s = **33% faster**

**Monthly savings**: ~100-150 runner minutes → ~65-100 minutes = **30-35% cost reduction**

---

## 🎯 Implementation Priority

### Phase 1: Zero-Risk Wins

1. ✅ Add `cache: 'npm'` to all `setup-node` steps (10 minutes)
2. ✅ Verify in one workflow run
3. ✅ Done!

**Effort**: 10 minutes
**Risk**: None (official feature)
**Gain**: 10-30s per job with npm

---

### Phase 2: Low-Risk, High-Value

1. ✅ Add pub cache to `test` job only
2. ✅ Test with 2-3 workflow runs
3. ✅ Verify tests still pass
4. ✅ Roll out to other Flutter jobs
5. ✅ Monitor for 1 week

**Effort**: 30 minutes + monitoring
**Risk**: Low (widely used pattern)
**Gain**: 20-30s per job

---

### Phase 3: Skip for Now

1. ❌ Don't cache .dart_tool
2. ❌ Don't cache build_runner outputs
3. ❌ Don't cache build artifacts

**Reason**: High risk, low reward, hard to maintain

---

## 🛡️ Rollback Plan

If caching causes issues:

```yaml
# Quick rollback: Comment out cache step
# - name: Cache pub packages
#   uses: actions/cache@v4
#   with:
#     path: ~/.pub-cache
#     key: ...
```

Or bust cache:
```yaml
key: v2-${{ runner.os }}-pub-${{ hashFiles('**/pubspec.lock') }}
```

---

## ✅ Final Recommendation

**Do now:**
- Add npm cache (100% safe)
- Add pub cache for ~/.pub-cache only (95% safe)

**Don't do:**
- Cache .dart_tool
- Cache generated code
- Cache build outputs

**Monitor:**
- Cache hit rates
- Test reliability
- Build times

**Expected outcome:**
- 30-35% faster builds
- No correctness issues
- Easy to rollback if needed

---

## 📚 References

- [Flutter CI Best Practices](https://docs.flutter.dev/deployment/cd)
- [GitHub Actions Cache](https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows)
- [setup-node caching](https://github.com/actions/setup-node#caching-global-packages-data)
- [Dart pub cache location](https://dart.dev/tools/pub/environment-variables)
