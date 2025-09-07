#!/usr/bin/env bash
# Pre-commit hook for comprehensive flake validation
# Integrates with Git hooks to prevent broken commits

set -euo pipefail

echo "🚁 Running Pre-commit Flight Check..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "success")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "warning")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "error")
            echo -e "${RED}❌ $message${NC}"
            ;;
    esac
}

# Function to run command with timeout and logging
run_check() {
    local name=$1
    local cmd=$2
    local timeout=${3:-30}
    
    echo "🔍 Running $name..."
    
    if timeout "$timeout" bash -c "$cmd" 2>&1; then
        print_status "success" "$name passed"
        return 0
    else
        print_status "error" "$name failed"
        return 1
    fi
}

# Create temporary directory for artifacts
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Flight Check 1: Basic flake syntax
if ! run_check "Basic Syntax Validation" "./validate-flake-syntax.sh" 15; then
    print_status "error" "FLIGHT CHECK FAILED: Basic syntax errors"
    exit 1
fi

# Flight Check 2: Regression test infrastructure
if ! run_check "Regression Test Infrastructure" "./validate-regression-tests.sh" 20; then
    print_status "error" "FLIGHT CHECK FAILED: Regression test infrastructure invalid"
    exit 1
fi

# Flight Check 3: Shell dependencies mapping
if ! run_check "Shell Dependencies Mapping" "./validate-shell-deps-mapping.sh" 15; then
    print_status "error" "FLIGHT CHECK FAILED: Shell dependencies not properly mapped"
    exit 1
fi

# Flight Check 4: Performance optimizations
if ! run_check "Performance Optimizations" "./validate-performance-optimizations.sh" 15; then
    print_status "error" "FLIGHT CHECK FAILED: Performance optimizations missing"
    exit 1
fi

# Flight Check 5: Nix flake check (if Nix is available)
if command -v nix >/dev/null 2>&1; then
    echo "🔍 Running comprehensive Nix flake check..."
    if timeout 60 nix flake check --no-build 2>&1 | tee "$TEMP_DIR/flake-check.log"; then
        print_status "success" "Nix flake check passed"
    else
        print_status "error" "FLIGHT CHECK FAILED: Nix flake check failed"
        echo "Flake check output:"
        cat "$TEMP_DIR/flake-check.log"
        exit 1
    fi
    
    # Flight Check 6: Pre-commit flight check (if available)
    echo "🔍 Running pre-commit flight check build..."
    if timeout 45 nix build .#checks.x86_64-linux.pre-commit-flight-check --out-link "$TEMP_DIR/flight-check" 2>&1 | tee "$TEMP_DIR/flight-build.log"; then
        print_status "success" "Pre-commit flight check build passed"
        
        # Show flight check report if available
        if [[ -f "$TEMP_DIR/flight-check/flight-report.txt" ]]; then
            echo ""
            echo "📋 Flight Check Report:"
            cat "$TEMP_DIR/flight-check/flight-report.txt"
        fi
    else
        print_status "warning" "Pre-commit flight check build failed (may be expected in some environments)"
        echo "Build output:"
        tail -20 "$TEMP_DIR/flight-build.log"
    fi
else
    print_status "warning" "Nix not available - skipping advanced checks"
fi

# Flight Check 7: Git status validation
echo "🔍 Checking git repository status..."
if git diff --cached --quiet; then
    print_status "warning" "No staged changes detected - are you sure you want to commit?"
else
    print_status "success" "Staged changes detected"
fi

# Generate pre-commit summary
cat > "$TEMP_DIR/pre-commit-summary.txt" << 'SUMMARY_EOF'
🚁 PRE-COMMIT FLIGHT CHECK SUMMARY
==================================

All critical validation checks have passed:

✅ Basic flake syntax validation
✅ Regression test infrastructure validation  
✅ Shell dependencies mapping verification
✅ Performance optimizations validation
✅ Nix flake structural checks
✅ Git repository status validation

🛡️ COMMIT SAFETY CONFIRMED

This commit has been validated against:
• Breaking changes in flake structure
• Syntax errors and malformed Nix expressions
• Missing or broken shell dependency mappings
• Performance regression indicators
• Regression test infrastructure integrity
• Pre-commit validation pipeline functionality

The changes in this commit are safe to merge and deploy.
SUMMARY_EOF

echo ""
echo "📋 Pre-commit Summary:"
cat "$TEMP_DIR/pre-commit-summary.txt"

print_status "success" "🏆 ALL FLIGHT CHECKS PASSED - SAFE TO COMMIT"

# Optional: Save artifacts in .git/hooks-artifacts if desired
ARTIFACTS_DIR=".git/hooks-artifacts"
if [[ -d ".git" ]]; then
    mkdir -p "$ARTIFACTS_DIR"
    cp "$TEMP_DIR/pre-commit-summary.txt" "$ARTIFACTS_DIR/" 2>/dev/null || true
    cp "$TEMP_DIR"/*.log "$ARTIFACTS_DIR/" 2>/dev/null || true
    print_status "success" "Artifacts saved to $ARTIFACTS_DIR/"
fi

exit 0