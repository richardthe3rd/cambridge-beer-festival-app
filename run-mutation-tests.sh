#!/bin/bash
# Mutation Testing Runner Script
# Runs mutation tests on critical business logic with nice reporting

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
CONFIG="mutation_test_critical.xml"
FORMAT="all"
OUTPUT_DIR="mutation-test-report"
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --config)
      CONFIG="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --abv)
      CONFIG="mutation_test_abv.xml"
      shift
      ;;
    --dates)
      CONFIG="mutation_test_festival_dates.xml"
      shift
      ;;
    --availability)
      CONFIG="mutation_test_availability.xml"
      shift
      ;;
    --allergens)
      CONFIG="mutation_test_allergens.xml"
      shift
      ;;
    --all)
      CONFIG="mutation_test_critical.xml"
      shift
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --config FILE       Specify mutation test configuration file"
      echo "  --dry-run           Count mutations without running tests"
      echo "  --abv               Test ABV parsing logic only"
      echo "  --dates             Test Festival date formatting only"
      echo "  --availability      Test Product availability status only"
      echo "  --allergens         Test Product allergen text only"
      echo "  --all               Test all critical business logic (default)"
      echo "  --help              Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0 --dry-run        # Count mutations without testing"
      echo "  $0 --abv            # Test only ABV parsing"
      echo "  $0 --all            # Test all critical code"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

echo -e "${BLUE}🧬 Mutation Testing for Cambridge Beer Festival App${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "Configuration: ${YELLOW}$CONFIG${NC}"
echo ""

# Check if config file exists
if [ ! -f "$CONFIG" ]; then
  echo -e "${RED}❌ Configuration file not found: $CONFIG${NC}"
  exit 1
fi

# Dry run - just count mutations
if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}Running dry-run (counting mutations only)...${NC}"
  echo ""
  ./bin/mise exec flutter -- dart run mutation_test "$CONFIG" -d
  exit 0
fi

# Full mutation test
echo -e "${GREEN}Running mutation testing...${NC}"
echo -e "${YELLOW}This may take 5-15 minutes depending on the number of mutations.${NC}"
echo ""

# Clean previous reports
if [ -d "$OUTPUT_DIR" ]; then
  echo -e "Cleaning previous reports..."
  rm -rf "$OUTPUT_DIR"
fi

# Run mutation test
START_TIME=$(date +%s)

if ./bin/mise exec flutter -- dart run mutation_test "$CONFIG" -f "$FORMAT" -o "$OUTPUT_DIR"; then
  EXIT_CODE=0
  RESULT_MSG="${GREEN}✅ All mutations were killed!${NC}"
else
  EXIT_CODE=$?
  RESULT_MSG="${YELLOW}⚠️  Some mutations survived (exit code: $EXIT_CODE)${NC}"
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED / 60))
SECONDS=$((ELAPSED % 60))

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "$RESULT_MSG"
echo -e "${BLUE}================================================${NC}"
echo -e "Time elapsed: ${YELLOW}${MINUTES}m ${SECONDS}s${NC}"
echo ""

# Display summary
if [ -f "$OUTPUT_DIR/mutation-test-report.md" ]; then
  echo -e "${GREEN}📊 Summary:${NC}"
  echo ""
  grep -A 20 "| Key" "$OUTPUT_DIR/mutation-test-report.md" | head -20
  echo ""
  echo -e "${GREEN}📁 Reports generated:${NC}"
  echo "  - HTML: $OUTPUT_DIR/mutation-test-report.html"
  echo "  - Markdown: $OUTPUT_DIR/mutation-test-report.md"
  echo "  - JUnit: $OUTPUT_DIR/mutation-test-report.junit.xml"
  echo ""
  echo -e "${BLUE}Open HTML report:${NC}"
  echo "  open $OUTPUT_DIR/mutation-test-report.html"
else
  echo -e "${RED}❌ Report file not found${NC}"
fi

exit $EXIT_CODE
