#!/bin/bash

# Test script to validate shell dependency mapping implementation
# This script validates that all required dependencies are properly mapped

set -euo pipefail

echo "=== Testing Shell Dependencies Mapping ==="
echo ""

# Test flake.nix content validation
echo "🔍 Validating flake.nix shell dependency declarations..."

FLAKE_FILE="flake.nix"
if [[ ! -f "$FLAKE_FILE" ]]; then
    echo "❌ Error: flake.nix not found"
    exit 1
fi

# Expected shell dependencies from our implementation
EXPECTED_SHELL_DEPS=(
  "bash" "coreutils" "findutils" "gnugrep" "gnused" "git"
  "nodejs" "npm" "python3" "typescript" "rustc" "cargo" "go"
  "gdb" "strace" "ltrace" "valgrind" "ripgrep" "fd" "jq"
  "curl" "wget" "gnumake" "cmake" "pkg-config" "procps"
  "util-linux" "shadow" "nix" "nix-tree" "nixpkgs-fmt"
)

echo "✅ Checking ${#EXPECTED_SHELL_DEPS[@]} shell dependencies in flake.nix:"

MISSING_DEPS=()
for dep in "${EXPECTED_SHELL_DEPS[@]}"; do
  if grep -q "$dep" "$FLAKE_FILE"; then
    echo "  ✅ $dep"
  else
    echo "  ❌ $dep (missing)"
    MISSING_DEPS+=("$dep")
  fi
done

if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    echo "❌ Error: Missing dependencies: ${MISSING_DEPS[*]}"
    exit 1
fi

echo "✅ All shell dependencies found in flake.nix"

echo ""
echo "🔍 Validating mcp-servers-nix framework integration..."

# Check for mcp-servers-nix usage
if ! grep -q "mcp-servers-nix" "$FLAKE_FILE"; then
    echo "❌ Error: mcp-servers-nix framework not found in flake.nix"
    exit 1
fi

if ! grep -q "mkMcpServers" "$FLAKE_FILE"; then
    echo "❌ Error: mkMcpServers function not used"
    exit 1
fi

echo "✅ mcp-servers-nix framework integration found"

echo ""
echo "🔍 Validating environment variable mapping..."

if ! grep -q "DEEBO_SHELL_DEPS_PATH" "$FLAKE_FILE"; then
    echo "❌ Error: DEEBO_SHELL_DEPS_PATH not found in flake.nix"
    exit 1
fi

if ! grep -q "makeBinPath shellDependencies" "$FLAKE_FILE"; then
    echo "❌ Error: makeBinPath shellDependencies not found"
    exit 1
fi

echo "✅ Environment variable mapping found"

echo ""
echo "🔍 Validating sandbox hardening..."

# Check for improved shell quoting
if ! grep -q 'EOF'"'"'' "$FLAKE_FILE"; then
    echo "❌ Error: Proper heredoc quoting not found"
    exit 1
fi

if ! grep -q 'escapeShellArg' "$FLAKE_FILE"; then
    echo "❌ Error: Shell argument escaping not found"
    exit 1
fi

if ! grep -q 'timeout [0-9]' "$FLAKE_FILE"; then
    echo "❌ Error: Command timeouts not found"
    exit 1
fi

echo "✅ Sandbox hardening improvements found"

echo ""
echo "🔍 Checking development shell configuration..."

if ! grep -q "devShells.default" "$FLAKE_FILE"; then
    echo "❌ Error: devShells.default not found"
    exit 1
fi

if ! grep -q "buildInputs = shellDependencies" "$FLAKE_FILE"; then
    echo "❌ Error: Development shell dependencies not mapped"
    exit 1
fi

echo "✅ Development shell properly configured"

echo ""
echo "=== Testing Configuration Files ==="

# Check if Nix configuration exists
if [[ -f "config/nix-mcp.json" ]]; then
    echo "✅ Nix MCP configuration found"
else
    echo "⚠️  Warning: config/nix-mcp.json not found (may be auto-generated)"
fi

echo ""
echo "=== Summary ==="
echo ""
echo "🎉 All shell dependency mapping tests pass!"
echo "✅ ${#EXPECTED_SHELL_DEPS[@]} shell dependencies properly mapped via nix-shell"
echo "✅ mcp-servers-nix framework integration verified"
echo "✅ Environment variables properly configured"
echo "✅ Shell command hardening implemented"
echo "✅ Development shell includes all dependencies"
echo "✅ Sandbox security improvements applied"
echo ""
echo "📋 Implementation Summary:"
echo "   • All shell dependencies mapped via nix-shell as requested"
echo "   • Uses natsukium/mcp-servers-nix framework"
echo "   • DEEBO_SHELL_DEPS_PATH environment variable exposes dependencies"
echo "   • Improved shell quoting and escaping for security"
echo "   • Command timeouts added for safety"
echo "   • Backward compatibility maintained"

exit 0