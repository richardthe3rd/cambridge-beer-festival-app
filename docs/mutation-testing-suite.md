# Mutation Testing Suite

**Status**: ✅ Implemented and Integrated with CI/CD
**Coverage**: 4 critical business logic sections (99+ mutations)
**Quality**: All mutations detected (100% score on tested sections)

## Overview

This project uses **mutation testing** to verify the quality of tests for critical business logic. Unlike code coverage (which measures if code runs), mutation testing measures if tests catch bugs.

### What Gets Tested

Four critical code sections are continuously validated:

| Section | File | Lines | Mutations | Purpose |
|---------|------|-------|-----------|---------|
| **ABV Parsing** | `lib/models/drink.dart` | 80-90 | 8 | Handles type variations (num, String, null) |
| **Availability Status** | `lib/models/drink.dart` | 151-183 | 44 | String matching for stock levels |
| **Allergen Formatting** | `lib/models/drink.dart` | 186-195 | 20 | Displays allergen list |
| **Date Formatting** | `lib/models/festival.dart` | 103-130 | 27 | Formats festival date ranges |
| **Total** | - | - | **99** | - |

## Running Mutation Tests

### Local Development

#### Using mise tasks (recommended)

```bash
# Test all critical business logic (~10 minutes)
./bin/mise run mutation:critical

# Test individual sections (faster, 1-2 minutes each)
./bin/mise run mutation:abv           # ABV parsing only
./bin/mise run mutation:dates         # Festival date formatting only
./bin/mise run mutation:availability  # Availability status only
./bin/mise run mutation:allergens     # Allergen text only

# Quick preview (count mutations, no tests run)
./bin/mise run mutation:dry-run
```

#### Using the script directly

```bash
# All options
./run-mutation-tests.sh --all              # Test all critical code
./run-mutation-tests.sh --abv              # Test ABV parsing only
./run-mutation-tests.sh --dates            # Test date formatting only
./run-mutation-tests.sh --availability     # Test availability status only
./run-mutation-tests.sh --allergens        # Test allergen text only
./run-mutation-tests.sh --dry-run          # Count mutations without testing

# Custom configuration
./run-mutation-tests.sh --config mutation_test_custom.xml
```

#### Using dart directly

```bash
# Full control
./bin/mise exec flutter -- dart run mutation_test mutation_test_critical.xml -f all -o reports
```

### CI/CD Integration

Mutation testing runs automatically on pull requests that modify:
- `lib/models/**` - Model code
- `test/models_test.dart` - Model tests
- `mutation_test*.xml` - Mutation configurations

**Workflow**: `.github/workflows/mutation-testing.yml`

**Features**:
- ✅ Runs mutation tests on critical code
- ✅ Generates HTML, Markdown, and JUnit reports
- ✅ Comments results on pull requests
- ✅ Uploads reports as workflow artifacts
- ✅ Enforces 80% mutation score threshold
- ✅ Shows progress in job summary

**Manual Trigger**:
- Go to Actions → Mutation Testing → Run workflow
- Choose which configuration to test
- View results in workflow summary and artifacts

## Reports

After running mutation tests, reports are generated in `mutation-test-report/`:

### HTML Report (Interactive)
```bash
open mutation-test-report/mutation-test-report.html
```

**Features**:
- Per-file mutation breakdown
- Color-coded results (killed vs survived)
- Click to see exact mutation location
- Filterable by file or mutation type

### Markdown Report (Summary)
```bash
cat mutation-test-report/mutation-test-report.md
```

**Contains**:
- Key metrics table
- Mutation score percentage
- Quality rating (A-F)
- List of undetected mutations (if any)

### JUnit XML (CI Integration)
```
mutation-test-report/mutation-test-report.junit.xml
```

**Purpose**: CI/CD test result integration

## Configuration Files

### Individual Configurations

| File | Target | Purpose |
|------|--------|---------|
| `mutation_test_abv.xml` | ABV parsing | Fast validation of critical parsing logic |
| `mutation_test_festival_dates.xml` | Date formatting | Validates month array indexing and boundary conditions |
| `mutation_test_availability.xml` | Status matching | Tests string matching and contains() logic |
| `mutation_test_allergens.xml` | Allergen display | Validates capitalization and formatting |

### Combined Configuration

| File | Target | Purpose |
|------|--------|---------|
| `mutation_test_critical.xml` | All 4 sections | Comprehensive testing of all critical code |
| `mutation_test.xml` | Full file | Original full-file configuration (not recommended for CI) |

## Mutation Types Tested

### Type Checking Mutations
```dart
// Original
if (abvValue is num)

// Mutated
if (!(abvValue is num))  // Negated
```

### Null Safety Mutations
```dart
// Original
parsedAbv = double.tryParse(abvValue) ?? 0.0;

// Mutated
parsedAbv = double.tryParse(abvValue) /*??null*/ 0.0;  // Removed coalesce
```

### Boundary Condition Mutations
```dart
// Original
months[start.month - 1]

// Mutated
months[start.month]      // Off-by-one error
months[start.month - 2]  // Wrong offset
```

### String Matching Mutations
```dart
// Original
if (lower.contains('out'))

// Mutated
if (lower.startsWith('out'))  // Different method
if (lower.contains('low'))    // Different string
```

### Logical Operator Mutations
```dart
// Original
if (start.month == end.month && start.year == end.year)

// Mutated
if (start.month == end.month || start.year == end.year)  // AND → OR
```

### Numeric Literal Mutations
```dart
// Original
parsedAbv = 0.0;

// Mutated
parsedAbv = 1.0;  // Wrong default
```

## Understanding Results

### Mutation Score

**Formula**: `(Mutations Killed / Total Mutations) × 100%`

**Quality Ratings**:
- **A** (90-100%): Excellent - Tests thoroughly verify behavior
- **B** (80-89%): Good - Tests catch most bugs
- **C** (70-79%): Fair - Some test gaps exist
- **D** (60-69%): Poor - Significant test weaknesses
- **F** (<60%): Failing - Tests are inadequate

### What "Killed" Means

A mutation is **killed** when:
1. Code is mutated (e.g., `>` changed to `>=`)
2. Tests are run
3. At least one test fails

This proves tests verify the exact behavior, not just execution.

### What "Survived" Means

A mutation **survives** when:
1. Code is mutated
2. Tests are run
3. All tests pass

This indicates a **test gap** - tests don't verify this behavior.

### Example Analysis

**Good Test** (mutation killed):
```dart
test('handles null ABV as 0.0', () {
  final product = Product.fromJson({'abv': null});
  expect(product.abv, 0.0);  // Exact value checked
});

// Mutation: Change 0.0 to 1.0
// Result: Test fails ✅ Mutation killed
```

**Weak Test** (mutation survives):
```dart
test('handles null ABV', () {
  final product = Product.fromJson({'abv': null});
  expect(product.abv, isA<double>());  // Only type checked
});

// Mutation: Change 0.0 to 1.0
// Result: Test passes ❌ Mutation survives
```

## CI/CD Workflow Details

### When It Runs

**Automatically**:
- Pull requests modifying `lib/models/` or `test/models_test.dart`
- Changes to mutation test configurations

**Manually**:
- Actions → Mutation Testing → Run workflow
- Choose specific configuration to test

### What It Does

1. **Setup Environment**
   - Install Flutter 3.38.3
   - Get dependencies
   - Generate mocks

2. **Pre-flight Check**
   - Run normal tests first
   - Fail fast if tests are already broken

3. **Run Mutation Tests**
   - Execute chosen configuration
   - Generate all report formats
   - Capture results

4. **Report Results**
   - Add summary to job summary
   - Comment on PR with results
   - Upload HTML/JUnit artifacts

5. **Quality Gate**
   - Check mutation score threshold (80%)
   - Warn if below threshold
   - Don't block merge (warning only)

### Viewing Results

**In PR Comments**:
- Summary table with key metrics
- Link to full HTML report
- Mutation score percentage

**In Workflow Summary**:
- Full Markdown report
- Per-file breakdown
- Quality rating

**In Artifacts**:
- Download HTML report for detailed analysis
- Download JUnit XML for CI integration

## Best Practices

### When to Add Mutation Tests

✅ **Do add** mutation tests for:
- Critical business logic (parsing, formatting)
- Boundary conditions (array indexing, comparisons)
- String matching logic
- Type checking and null handling
- Mathematical calculations

❌ **Don't add** mutation tests for:
- Simple getters/setters
- UI widget code (use widget tests)
- Generated code (auto-excluded)
- Trivial one-liners

### Writing Tests That Kill Mutations

✅ **Use exact value assertions**:
```dart
expect(product.abv, 5.5);  // Good
```

❌ **Avoid weak type-only assertions**:
```dart
expect(product.abv, isA<double>());  // Weak
```

✅ **Test all branches**:
```dart
test('handles num', () => ...);
test('handles String', () => ...);
test('handles null', () => ...);
```

✅ **Verify edge cases**:
```dart
test('empty list returns null', () => ...);
test('single item formats correctly', () => ...);
test('multiple items join with comma', () => ...);
```

### Maintaining Mutation Tests

**When code changes**:
1. Update line numbers in XML if needed
2. Add mutations for new logic
3. Re-run mutation tests
4. Fix any new surviving mutations

**When tests change**:
1. Ensure mutations are still valid
2. Check mutation score hasn't decreased
3. Add tests for any surviving mutations

**Periodic Review**:
- Run full mutation suite quarterly
- Review survived mutations
- Update configurations as code evolves

## Troubleshooting

### Mutation Test Takes Too Long

**Problem**: Full test takes 15+ minutes

**Solutions**:
- Run individual configs (`--abv`, `--dates`, etc.)
- Use `--dry-run` to preview mutation count
- Focus on changed files only
- Use coverage data to skip untested code:
  ```bash
  dart run mutation_test config.xml --coverage coverage/lcov.info
  ```

### Mutations Survive But Tests Look Good

**Problem**: Mutation score is low but tests seem comprehensive

**Analysis Steps**:
1. Check HTML report to see which mutations survived
2. Look for weak assertions (`isNotNull`, `isA<Type>()`)
3. Verify all branches/edge cases are tested
4. Check if mutation is actually testable

**Common Causes**:
- Tests check types, not values
- Missing edge case tests
- Tests use mocks that hide real behavior
- Equivalent mutations (impossible to test)

### False Positives (Equivalent Mutations)

**Problem**: Mutation can't be tested (e.g., log message changes)

**Solutions**:
- Add mutation ID to exclusion list in XML
- Use whitelist to skip specific lines
- Focus on business logic, not cosmetic code

### CI Workflow Fails

**Problem**: Workflow fails but local tests pass

**Checklist**:
1. Check Flutter version matches (3.38.3)
2. Verify dependencies are up to date
3. Ensure mocks are generated
4. Check timeout settings (may need increase)
5. Review workflow logs for specific errors

## Performance Metrics

### Execution Times (Approximate)

| Configuration | Mutations | Time | Use Case |
|---------------|-----------|------|----------|
| `mutation:abv` | 8 | 1 min | Quick validation |
| `mutation:allergens` | 20 | 2 min | Quick validation |
| `mutation:dates` | 27 | 3 min | Medium validation |
| `mutation:availability` | 44 | 5 min | Medium validation |
| `mutation:critical` | 99 | 10 min | Full validation |

**Per-mutation cost**: ~6-8 seconds (test execution + overhead)

### Optimization Tips

1. **Run incrementally**: Test only changed sections
2. **Use coverage data**: Skip untested code
3. **Parallelize**: Run multiple configs in parallel (if resources allow)
4. **Cache dependencies**: Flutter cache speeds up CI
5. **Targeted configs**: Create focused configs for specific features

## Future Enhancements

### Planned
- [ ] Mutation testing for `BeerProvider` state logic
- [ ] Coverage-based mutation testing (skip untested code)
- [ ] Mutation score trending (track over time)
- [ ] Integration with code review tools

### Possible
- [ ] Try `dart_mutant` (faster Rust-based tool)
- [ ] Mutation testing for service layer
- [ ] Pre-commit hook for critical code
- [ ] Mutation score badges in README

## Resources

### Documentation
- [Mutation Testing Exploration](mutation-testing-exploration.md) - Detailed analysis and tool comparison
- [Mutation Testing Implementation](mutation-testing-implementation.md) - ABV parsing case study
- [mutation_test Package](https://pub.dev/packages/mutation_test) - Official package docs

### Tools
- `run-mutation-tests.sh` - Local runner script with nice output
- `mutation_test*.xml` - Configuration files for different targets
- `.github/workflows/mutation-testing.yml` - CI/CD workflow

### Examples
- See `docs/mutation-testing-implementation.md` for detailed ABV parsing example
- Check HTML reports for visual mutation analysis
- Review PR comments for real-world results

---

**Questions or Issues?**
- Check troubleshooting section above
- Review mutation-testing-exploration.md for concepts
- Check CI workflow logs for details
- Run with `--dry-run` to preview mutations
