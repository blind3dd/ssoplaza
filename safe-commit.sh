#!/bin/bash

# Safe Commit Script for SSO Plaza
# This script ensures only safe files are committed

set -e

echo "🔒 Preparing safe commit for SSO Plaza..."

# Check for any remaining hardcoded values
echo "🔍 Checking for hardcoded values..."

# Check for the specific realm hash
if grep -r "LKDC:SHA1\.9D86C199F3746FDAEBA77551C50E124742C1B33B" . --exclude-dir=.git --exclude="*.sanitized" --exclude="safe-commit.sh" --exclude="auto-discovery.sh"; then
    echo "❌ Found hardcoded realm hash! Please sanitize first."
    exit 1
fi

# Check for hardcoded username
if grep -r "usualsuspectx@LKDC" . --exclude-dir=.git --exclude="*.sanitized" --exclude="safe-commit.sh" --exclude="auto-discovery.sh"; then
    echo "❌ Found hardcoded username! Please sanitize first."
    exit 1
fi

# Check for hardcoded hostname
if grep -r "pawelbekmacbookm1max" . --exclude-dir=.git --exclude="*.sanitized" --exclude="safe-commit.sh" --exclude="auto-discovery.sh"; then
    echo "❌ Found hardcoded hostname! Please sanitize first."
    exit 1
fi

echo "✅ No hardcoded values found. Safe to commit!"

# Show what will be committed
echo ""
echo "📋 Files to be committed:"
git status --porcelain | grep -v "^D" | awk '{print "   " $2}'

echo ""
echo "🚀 Ready to commit! Run:"
echo "   git add ."
echo "   git commit -m 'Add SSO Plaza with auto-discovery'"
