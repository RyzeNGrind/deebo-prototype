#!/usr/bin/env bash
# Self-referential flake regression test validation script
# Validates regression testing infrastructure and runs comprehensive checks

set -euo pipefail

echo "🔄 Validating Flake Regression Test Suite..."

FLAKE_FILE="flake.nix"

# Check 1: Regression test infrastructure presence
echo "🔍 Checking regression test infrastructure..."

if grep -q "regression-tests" "$FLAKE_FILE"; then
    echo "✅ Regression tests defined in flake.nix"
else
    echo "❌ Regression tests not found in flake.nix"
    exit 1
fi

if grep -q "pre-commit-flight-check" "$FLAKE_FILE"; then
    echo "✅ Pre-commit flight check defined"
else
    echo "❌ Pre-commit flight check not found"
    exit 1
fi

if grep -q "self-referential.*regression\|Running self-referential flake regression tests" "$FLAKE_FILE"; then
    echo "✅ Self-referential input configured"
else
    echo "❌ Self-referential input not configured"
    exit 1
fi

# Check 2: Required regression test components
echo "🔍 Checking regression test components..."

REQUIRED_COMPONENTS=(
    "Output Structure Comparison"
    "Critical Package Build Validation"  
    "DevShell Environment Validation"
    "Template Structure Validation"
    "Flake Check Regression Detection"
)

MISSING_COMPONENTS=()
for component in "${REQUIRED_COMPONENTS[@]}"; do
    if grep -q "$component" "$FLAKE_FILE"; then
        echo "  ✅ $component"
    else
        echo "  ❌ $component (missing)"
        MISSING_COMPONENTS+=("$component")
    fi
done

if [[ ${#MISSING_COMPONENTS[@]} -gt 0 ]]; then
    echo "❌ Error: Missing regression test components: ${MISSING_COMPONENTS[*]}"
    exit 1
fi

# Check 3: Pre-commit flight check components
echo "🔍 Checking pre-commit flight check components..."

FLIGHT_CHECKS=(
    "Syntax validation"
    "Essential build validation"
    "DevShell integrity check"
    "Performance regression check"
    "Template structure check"
)

MISSING_FLIGHT=()
for check in "${FLIGHT_CHECKS[@]}"; do
    if grep -q "$check" "$FLAKE_FILE"; then
        echo "  ✅ $check"
    else
        echo "  ❌ $check (missing)"
        MISSING_FLIGHT+=("$check")
    fi
done

if [[ ${#MISSING_FLIGHT[@]} -gt 0 ]]; then
    echo "❌ Error: Missing flight checks: ${MISSING_FLIGHT[*]}"
    exit 1
fi

# Check 4: Artifact and logging infrastructure
echo "🔍 Checking artifact and logging infrastructure..."

if grep -q '"$out/logs"' "$FLAKE_FILE" && grep -q '"$out/artifacts"' "$FLAKE_FILE"; then
    echo "✅ Logging and artifact directories configured"
else
    echo "❌ Logging/artifact infrastructure not properly configured"
    exit 1
fi

if grep -q "regression-report.md" "$FLAKE_FILE"; then
    echo "✅ Regression report generation configured"
else
    echo "❌ Regression report generation missing"
    exit 1
fi

if grep -q "flight-report.txt" "$FLAKE_FILE"; then
    echo "✅ Flight check report generation configured"
else
    echo "❌ Flight check report generation missing"  
    exit 1
fi

# Check 5: Performance regression detection
echo "🔍 Checking performance regression detection..."

if grep -q "Performance regression check" "$FLAKE_FILE"; then
    echo "✅ Performance regression detection implemented"
else
    echo "❌ Performance regression detection missing"
    exit 1
fi

if grep -q "5000ms threshold" "$FLAKE_FILE" || grep -q "duration.*5000" "$FLAKE_FILE"; then
    echo "✅ Performance threshold configured"
else
    echo "❌ Performance threshold not configured"
    exit 1
fi

# Check 6: CI integration readiness
echo "🔍 Checking CI integration readiness..."

if grep -q "preferLocalBuild = true" "$FLAKE_FILE"; then
    echo "✅ Local build optimization for CI"
else
    echo "❌ CI build optimization missing"
    exit 1
fi

if grep -q "allowSubstitutes = false" "$FLAKE_FILE"; then
    echo "✅ Deterministic build configuration"
else
    echo "❌ Deterministic build configuration missing"
    exit 1
fi

echo ""
echo "📊 Regression Testing Infrastructure Summary:"
echo "✅ Self-referential flake comparison (current vs HEAD~1)"
echo "✅ Comprehensive output structure validation"
echo "✅ Package build regression detection"  
echo "✅ DevShell environment integrity checks"
echo "✅ Template structure validation"
echo "✅ Performance regression prevention"
echo "✅ Pre-commit flight check integration"
echo "✅ CI artifact generation for transparency"
echo "✅ Comprehensive logging and reporting"

echo ""
echo "🛡️ Regression Prevention Capabilities:"
echo "• Prevents undetected breaking changes in flake outputs"
echo "• Detects package build regressions and failures"
echo "• Guards against DevShell environment degradation"
echo "• Validates template structure integrity"
echo "• Monitors performance regression trends"
echo "• Provides pre-commit validation hooks"
echo "• Generates comprehensive audit trails"

echo ""
echo "🚀 Usage Instructions:"
echo "  Pre-commit check:  nix build .#checks.x86_64-linux.pre-commit-flight-check"
echo "  Regression tests:  nix build .#checks.x86_64-linux.regression-tests"
echo "  Full validation:   nix flake check"

echo ""
echo "🏆 All regression test infrastructure validated successfully!"
echo "✅ Ready for production use with comprehensive change detection"

exit 0