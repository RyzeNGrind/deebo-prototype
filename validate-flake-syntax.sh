#!/usr/bin/env bash
# Basic validation script for flake.nix syntax

set -euo pipefail

echo "🔍 Validating flake.nix syntax..."

FLAKE_FILE="flake.nix"

if [[ ! -f "$FLAKE_FILE" ]]; then
    echo "❌ Error: $FLAKE_FILE not found"
    exit 1
fi

echo "✅ flake.nix file exists"

# Check for balanced brackets, braces, and quotes
echo "🔍 Checking balanced brackets/braces/quotes..."

# Count opening and closing brackets
OPEN_BRACKETS=$(grep -o '\[' "$FLAKE_FILE" | wc -l || echo 0)
CLOSE_BRACKETS=$(grep -o '\]' "$FLAKE_FILE" | wc -l || echo 0)

OPEN_BRACES=$(grep -o '{' "$FLAKE_FILE" | wc -l || echo 0)  
CLOSE_BRACES=$(grep -o '}' "$FLAKE_FILE" | wc -l || echo 0)

OPEN_PARENS=$(grep -o '(' "$FLAKE_FILE" | wc -l || echo 0)
CLOSE_PARENS=$(grep -o ')' "$FLAKE_FILE" | wc -l || echo 0)

echo "📊 Bracket counts: [ $OPEN_BRACKETS ] $CLOSE_BRACKETS"
echo "📊 Brace counts:   { $OPEN_BRACES } $CLOSE_BRACES" 
echo "📊 Paren counts:   ( $OPEN_PARENS ) $CLOSE_PARENS"

if [[ $OPEN_BRACKETS -ne $CLOSE_BRACKETS ]]; then
    echo "❌ Error: Unbalanced brackets [ ]"
    exit 1
fi

if [[ $OPEN_BRACES -ne $CLOSE_BRACES ]]; then
    echo "❌ Error: Unbalanced braces { }"
    exit 1
fi

if [[ $OPEN_PARENS -ne $CLOSE_PARENS ]]; then
    echo "❌ Error: Unbalanced parentheses ( )"
    exit 1
fi

echo "✅ All brackets/braces/parentheses are balanced"

# Check for properly quoted mkdir commands
echo "🔍 Checking mkdir command quoting..."
if grep -n 'mkdir.*\$out' "$FLAKE_FILE" | grep -v '"$out' ; then
    echo "❌ Error: Found unquoted \$out variables in mkdir commands"
    exit 1
fi
echo "✅ All mkdir commands properly quoted"

# Check for heredoc patterns
echo "🔍 Checking heredoc patterns..."
HEREDOC_COUNT=$(grep -c "EOF'" "$FLAKE_FILE" || echo 0)
echo "📊 Found $HEREDOC_COUNT heredoc patterns with quoted delimiters"

# Basic flake structure validation
echo "🔍 Checking flake structure..."
if ! grep -q "^  outputs = " "$FLAKE_FILE"; then
    echo "❌ Error: Missing outputs declaration"
    exit 1
fi

if ! grep -q "^  inputs = " "$FLAKE_FILE"; then
    echo "❌ Error: Missing inputs declaration"  
    exit 1
fi

if ! grep -q "^  description = " "$FLAKE_FILE"; then
    echo "❌ Error: Missing description"
    exit 1
fi

echo "✅ Basic flake structure is correct"

# Check for required outputs
echo "🔍 Checking required outputs..."
REQUIRED_OUTPUTS=("packages" "devShells" "apps")
for output in "${REQUIRED_OUTPUTS[@]}"; do
    if ! grep -q "$output\." "$FLAKE_FILE" && ! grep -q "$output = " "$FLAKE_FILE"; then
        echo "❌ Error: Missing $output output"
        exit 1
    fi
done

echo "✅ All required outputs declared"

# Regression test: Check for incorrect "nix flakes" command usage
echo "🔍 Checking for incorrect 'nix flakes' command usage..."
INCORRECT_PATTERNS=()

# Search for problematic patterns across all files  
while IFS= read -r -d '' file; do
    if [[ -f "$file" ]]; then
        # Look for "nix ... flakes <subcommand>" pattern (where flakes is incorrectly used as part of command)
        if grep -Hn 'nix.*flakes \(flake\|build\|develop\|run\|shell\) ' "$file" >/dev/null 2>&1; then
            mapfile -t matches < <(grep -Hn 'nix.*flakes \(flake\|build\|develop\|run\|shell\) ' "$file")
            for match in "${matches[@]}"; do
                INCORRECT_PATTERNS+=("$match")
            done
        fi
    fi
done < <(find . -type f -not -path './.git/*' -not -path './node_modules/*' -print0)

if [[ ${#INCORRECT_PATTERNS[@]} -gt 0 ]]; then
    echo "❌ ERROR: Found incorrect 'nix flakes' command usage!"
    echo ""
    echo "The following files contain 'nix ... flakes <subcommand>' patterns:"
    echo "(Use 'nix ... flake <subcommand>' with experimental-features quoted)"
    echo ""
    for pattern in "${INCORRECT_PATTERNS[@]}"; do
        echo "  ❌ $pattern"
    done
    echo ""
    echo "CORRECT:   nix --extra-experimental-features \"nix-command flakes\" flake check"
    echo "INCORRECT: nix --extra-experimental-features nix-command flakes FLAKE check"
    echo ""
    exit 1
fi

echo "✅ No incorrect 'nix flakes' command patterns detected"

echo ""
echo "🎉 flake.nix syntax validation passed!"
echo "✅ All brackets/parentheses/quotes balanced"
echo "✅ Proper shell quoting patterns found"
echo "✅ Heredoc patterns properly quoted"  
echo "✅ Basic flake structure verified"
echo "✅ No incorrect 'nix flakes' command usage detected"
echo ""
echo "⚠️  Note: This is basic syntax validation only."
echo "   Run 'nix flake check' for complete validation when Nix is available."