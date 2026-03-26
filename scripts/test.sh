#!/usr/bin/env bash
# Copyright 2026 Workoho GmbH <https://workoho.com>
# Author: Julian Pawlowski <https://github.com/jpawlowski>
# Licensed under PolyForm Shield License 1.0.0 <https://polyformproject.org/licenses/shield/1.0.0>
#
# Run the Jest test suite.
#
# Usage:
#   scripts/test.sh
#
# Compiles TypeScript and runs all tests. Coverage report is written to
# jest-output/coverage/lcov-report/index.html

set -euo pipefail

# Always run from the repository root so npm scripts resolve correctly.
cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "Running tests..."
npm test

echo ""
echo "Coverage report: jest-output/coverage/lcov-report/index.html"
