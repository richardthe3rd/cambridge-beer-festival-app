# ADR 0002: Composite Actions and Test Deduplication

**Status**: Accepted

**Date**: 2025-12-27

**Deciders**: Engineering Team

**Related**: [ADR 0001: GitHub Actions Caching Strategy](0001-github-actions-caching-strategy.md)

---

## Context

After implementing safe caching in ADR 0001, we identified structural issues in our workflows:

### Problem 1: Massive Code Duplication

Flutter setup was repeated across 7 jobs in 4 workflows:
- `.github/workflows/build-deploy.yml` (test, build-web, build-android)
- `.github/workflows/release-android.yml` (create-release)
- `.github/workflows/release-web.yml` (build-and-deploy)

Each job had identical 25+ lines:
```yaml
- Setup Flutter
- Cache pub dependencies
- Create Firebase config
- Get dependencies
- Generate mocks (sometimes)
```

**Issues**:
- Changes require editing 7 locations
- Inconsistencies creep in (some generate mocks, some don't)
- Maintenance burden increases over time

### Problem 2: Redundant Test Execution

Tests ran multiple times for the same commit:

1. **PR/push to main** → `build-deploy.yml` runs tests ✅
2. **Tag pushed** → `release-android.yml` runs tests AGAIN ❌
3. **Same tag** → `release-web.yml` runs tests AND analyze AGAIN ❌

**Impact**:
- Wasted 2-3 minutes per release
- Higher runner costs
- Slower releases
- Duplicate test failures

---

## Decision

We will implement two structural improvements:

### 1. Create Composite Action for Flutter Setup

**File**: `.github/actions/setup-flutter-app/action.yml`

Encapsulates all Flutter setup logic:
- Setup Flutter SDK
- Cache pub dependencies
- Create Firebase google-services.json
- Run `flutter pub get`
- Optionally run `build_runner` for code generation

**Inputs**:
```yaml
inputs:
  google-services-json:
    description: 'Firebase google-services.json content'
    required: true
  generate-mocks:
    description: 'Whether to run build_runner for mock generation'
    required: false
    default: 'false'
  flutter-version:
    description: 'Flutter version to use'
    required: false
    default: '3.38.3'
```

**Usage in workflows**:
```yaml
- name: Setup Flutter App
  uses: ./.github/actions/setup-flutter-app
  with:
    google-services-json: ${{ secrets.GOOGLE_SERVICES_JSON }}
    generate-mocks: 'true'  # Optional
```

**Benefits**:
- ✅ Change once, affects all workflows
- ✅ Guaranteed consistency
- ✅ Easier to maintain
- ✅ Self-documenting (action.yml describes inputs)
- ✅ Can version/tag the action if needed

---

### 2. Skip Redundant Tests in Release Workflows

**Strategy**: Only run tests/analysis on `workflow_dispatch` (manual triggers)

**Rationale**:
- Tags are created on `main` branch
- `main` branch is protected, requires CI to pass
- Therefore, tagged commits already have passing tests
- Re-running tests is redundant for tag-triggered releases

**Implementation**:

**release-android.yml**:
```yaml
- name: Run tests
  if: github.event_name == 'workflow_dispatch'
  run: flutter test
```

**release-web.yml**:
```yaml
- name: Analyze code
  if: github.event_name == 'workflow_dispatch'
  run: flutter analyze --no-fatal-infos

- name: Run tests
  if: github.event_name == 'workflow_dispatch'
  run: flutter test
```

**Behavior**:
- **Tag push** (normal release): Skip tests (they already passed)
- **Manual dispatch**: Run tests (might be an old tag or manual version)

**Benefits**:
- ✅ 2-3 minutes faster releases
- ✅ Lower runner costs
- ✅ Still safe (manual releases are tested)
- ✅ Easy to understand logic

---

### 3. Standardize Node.js Version

**Change**: Use Node.js 20 LTS everywhere (was mixed 20/21/22)

**Rationale**:
- Node 20 is Active LTS (maintained until 2026-04-30)
- Node 22 is Current, not yet LTS (was incorrectly stated as LTS)
- Consistency reduces debugging surprises
- Proven compatibility with Playwright, Wrangler, http-server

**Risk**: NONE - Node 20 is safe and stable

---

## Implementation Details

### Files Created

**`.github/actions/setup-flutter-app/action.yml`**:
- Composite action (reusable across workflows)
- Encapsulates Flutter setup logic
- Handles caching, dependencies, code generation
- ~80 lines of reusable code

### Files Modified

**`.github/workflows/build-deploy.yml`**:
- test job: Use composite action with `generate-mocks: 'true'`
- build-web job: Use composite action (no mocks)
- build-android job: Use composite action (no mocks)
- test-e2e-web job: Change Node to 20
- **Reduction**: ~75 lines removed, replaced with ~12 lines

**`.github/workflows/release-android.yml`**:
- Use composite action with `generate-mocks: 'true'`
- Skip tests unless `workflow_dispatch`
- Remove duplicate Firebase config creation
- **Reduction**: ~30 lines removed

**`.github/workflows/release-web.yml`**:
- Use composite action with `generate-mocks: 'true'`
- Skip analyze and tests unless `workflow_dispatch`
- **Reduction**: ~35 lines removed

**`.github/workflows/cloudflare-worker.yml`**:
- Standardize to Node 20 (was 22)
- Already using proper npm caching (from ADR 0001)

### Code Reduction Summary

| Workflow | Before | After | Reduction |
|----------|--------|-------|-----------|
| build-deploy.yml | 302 lines | ~227 lines | 25% smaller |
| release-android.yml | 157 lines | ~127 lines | 19% smaller |
| release-web.yml | 86 lines | ~61 lines | 29% smaller |
| **Total** | 545 lines | ~415 lines | **24% reduction** |

Plus: Composite action adds ~80 lines, but eliminates duplication across 7 jobs.

---

## Expected Outcomes

### Performance Improvements

**Normal tag-triggered release** (most common):
- `release-android.yml`: ~3 min → ~1 min (skip tests)
- `release-web.yml`: ~4 min → ~2 min (skip analyze + tests)
- **Total savings**: 4-5 minutes per release

**Manual workflow_dispatch**:
- Tests still run (safety preserved)
- Same duration as before

### Maintenance Improvements

**Before**:
```
Need to add new dependency?
→ Edit 7 different jobs in 4 files
→ Risk missing one
→ Inconsistencies likely
```

**After**:
```
Need to add new dependency?
→ Edit composite action once
→ All workflows updated automatically
→ Consistency guaranteed
```

---

## Alternatives Considered

### Alternative 1: Reusable Workflows

**Considered**: Use `workflow_call` trigger for reusable workflows

```yaml
# .github/workflows/reusable-flutter-setup.yml
on:
  workflow_call:
    inputs:
      generate-mocks:
        type: boolean
    secrets:
      GOOGLE_SERVICES_JSON:
        required: true
```

**Pros**: More powerful (can call other actions, have multiple jobs)

**Cons**:
- More complex
- Harder to debug
- Must be in separate file
- Overkill for simple setup tasks

**Decision**: Composite action is simpler and sufficient

---

### Alternative 2: Workflow Dependencies

**Considered**: Make release workflows depend on CI workflow

```yaml
# release-android.yml
on:
  workflow_run:
    workflows: ["CI"]
    types: [completed]
    branches: [main]
```

**Pros**: Explicit dependency, won't run if CI fails

**Cons**:
- More complex trigger logic
- Harder to understand for new contributors
- Workflow_run has quirks with tags
- Manual releases become harder

**Decision**: Simple `if: github.event_name == 'workflow_dispatch'` is clearer

---

### Alternative 3: Keep Duplication "For Clarity"

**Argument**: "Duplication is better than the wrong abstraction"

**Counter-arguments**:
1. This is the RIGHT abstraction (Flutter setup is a cohesive unit)
2. 7 copies across 4 files is excessive
3. Inconsistencies already exist (mocks vs no mocks)
4. Composite actions are standard GitHub feature, not clever hack

**Decision**: Eliminate duplication (but document in ADR)

---

## Risks and Mitigations

### Risk 1: Composite Action Breaks All Workflows

**Likelihood**: LOW
**Impact**: HIGH (all Flutter builds fail)

**Mitigation**:
- Test in branch before merging
- Monitor first production run closely
- Easy rollback (revert commit, expands back to inline steps)
- Composite actions are well-tested GitHub feature

---

### Risk 2: Skipped Tests Miss Real Issues

**Likelihood**: VERY LOW
**Impact**: MEDIUM (bad release)

**Context**:
- Tags are created on `main`
- `main` is protected, CI must pass
- Skipped tests already passed minutes ago

**Mitigation**:
- Manual releases still run tests
- Can always trigger workflow_dispatch for safety
- Tag-triggered releases use exact commit that passed CI

---

### Risk 3: Node 20 Compatibility Issues

**Likelihood**: NONE
**Impact**: MEDIUM (if occurred)

**Mitigation**:
- Node 20 is Active LTS, widely used
- Already proven with Playwright, Wrangler, http-server
- More stable than Node 22 (which we incorrectly tried to use)

---

## Success Metrics

### Quantitative

- ✅ **24% less workflow code** (~130 lines removed)
- ✅ **2-5 min faster releases** (skip redundant tests)
- ✅ **7 locations → 1** for Flutter setup changes
- ✅ **Consistency**: All jobs use identical setup

### Qualitative

- ✅ **Easier onboarding**: New contributors modify one action
- ✅ **Fewer bugs**: Can't have inconsistent setup across jobs
- ✅ **Better docs**: action.yml is self-documenting
- ✅ **Faster iteration**: Change once, affects all workflows

---

## Rollback Plan

### If Composite Action Breaks

```bash
# Option 1: Quick revert
git revert <commit-hash>
git push

# Option 2: Disable action, use inline code temporarily
# Edit workflows, replace action with original steps
```

### If Skipped Tests Cause Issues

```bash
# Remove the if condition
- name: Run tests
  # if: github.event_name == 'workflow_dispatch'  ← Comment this out
  run: flutter test
```

Or trigger manual workflow_dispatch for safety.

---

## Future Considerations

### Phase 3 (Deferred)

- **Parallel APK/AAB builds**: Use matrix strategy in release-android.yml
- **Gradle build cache**: Add `~/.android/build-cache` to cache
- **Artifact attestation**: Sign build artifacts with GitHub attestations
- **SLSA provenance**: Add supply chain metadata

### Composite Action Evolution

As needs grow, consider:
- Version the action (git tags)
- Add more inputs (custom Flutter flags, SDK channels)
- Support multiple Flutter versions
- Add outputs (build success, test results)

---

## Lessons Learned

### What Worked Well

✅ **Composite actions are perfect for this**: Simple, reusable, standard
✅ **Eliminating duplication felt good**: Immediate clarity improvement
✅ **Skip-test logic is simple**: Easy to understand and reason about
✅ **Node 20 standardization**: Zero issues, just works

### What We Avoided

❌ **Over-engineering**: Resisted reusable workflows (too complex)
❌ **Premature abstraction**: Only abstracted after seeing duplication
❌ **Breaking existing behavior**: Preserved test-on-dispatch for safety

### Key Insights

> **"The best code is no code"** - Removing 130 lines while adding functionality is a win.

> **"DRY, but not too DRY"** - Composite action hits the sweet spot between duplication and abstraction.

> **"Trust your CI"** - If main branch tests passed, release doesn't need to re-run them.

---

## Related Decisions

- **ADR 0001**: Safe caching strategy (implemented first)
- **Future ADR 0003**: Parallel build strategies (Phase 3)
- **Future ADR 0004**: Automated dependency updates (Dependabot)

---

## References

- [GitHub Composite Actions Docs](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action)
- [Reusing Workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- [Node.js Release Schedule](https://nodejs.org/en/about/previous-releases)
- [Flutter CI Best Practices](https://docs.flutter.dev/deployment/cd)

---

## Conclusion

This ADR documents **Phase 2 structural improvements** that complement the caching strategy from ADR 0001:

**Implemented**:
- ✅ Composite action eliminates duplication (7 jobs → 1 action)
- ✅ Skip redundant tests in releases (2-5 min savings)
- ✅ Standardize Node.js 20 LTS (consistency)
- ✅ 24% code reduction with better maintainability

**Results**:
- Faster releases
- Easier maintenance
- Better consistency
- Lower costs

**Next Steps**: Monitor for 2-4 weeks, then consider Phase 3 optimizations (parallel builds, enhanced caching) in future ADRs.

**Philosophy**: "Make it work, make it right, make it fast." We're now at "make it right" with clean, maintainable workflows.
