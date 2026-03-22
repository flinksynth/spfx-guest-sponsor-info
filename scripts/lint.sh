#!/usr/bin/env bash
# Run all linters (TypeScript/ESLint, SCSS, Markdown, Bicep, Shell) for both
# the SPFx web part and the Azure Function.
#
# Usage:
#   scripts/lint.sh

set -euo pipefail

# Always run from the repository root so npm scripts resolve correctly.
cd "$(dirname "${BASH_SOURCE[0]}")/.."

EXIT=0

echo "[ 1/5 ] ESLint (TypeScript — web part)..."
if npm run lint:ts; then
    echo "  ✓ ESLint passed"
else
    echo "  ✗ ESLint found issues"
    EXIT=1
fi

echo ""
echo "[ 2/5 ] ESLint (TypeScript — Azure Function)..."
if npm run lint:ts:func; then
    echo "  ✓ ESLint passed"
else
    echo "  ✗ ESLint found issues"
    EXIT=1
fi

echo ""
echo "[ 3/5 ] Stylelint (SCSS)..."
if npm run lint:scss; then
    echo "  ✓ Stylelint passed"
else
    echo "  ✗ Stylelint found issues"
    EXIT=1
fi

echo ""
echo "[ 4/5 ] Markdownlint (Docs)..."
if npm run lint:md; then
    echo "  ✓ Markdownlint passed"
else
    echo "  ✗ Markdownlint found issues"
    EXIT=1
fi

echo ""
echo "[ 5/6 ] Bicep lint (Azure Function infra)..."
if npm run lint:bicep; then
    echo "  ✓ Bicep lint passed"
else
    echo "  ✗ Bicep lint found issues"
    EXIT=1
fi

echo ""
echo "[ 6/6 ] shellcheck (Shell scripts)..."
if npm run lint:sh; then
    echo "  ✓ shellcheck passed"
else
    echo "  ✗ shellcheck found issues"
    EXIT=1
fi

echo ""
if [[ $EXIT -eq 0 ]]; then
    echo "✓ All linters passed."
else
    echo "✗ One or more linters reported issues — see above."
fi

exit $EXIT
