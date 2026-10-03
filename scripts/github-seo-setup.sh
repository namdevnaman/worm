#!/usr/bin/env bash
#
# Configure Worm's GitHub repository metadata for discoverability.
#
# GitHub ranks in Google, and GitHub is one of the sources AI assistants cite
# most often. The repository "About" text and its topics are therefore part of
# the SEO surface, not just project hygiene — a repo with no topics and a vague
# description is close to invisible in both.
#
# This script applies every value from the plan in one idempotent command, so
# the metadata is a reviewable artefact rather than something typed into a web
# form and forgotten.
#
# Requires: gh authenticated with repo scope.
#
#   gh auth login
#   bash scripts/github-seo-setup.sh
#
# Safe to re-run. It only sets fields; it never deletes topics.

set -euo pipefail

REPO="${WORM_REPO:-namdevnaman/worm}"

if ! command -v gh >/dev/null 2>&1; then
  echo "error: gh not found. Install: brew install gh" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "error: not authenticated. Run: gh auth login" >&2
  exit 1
fi

# Under 350 characters — GitHub truncates past that.
DESCRIPTION="Worm Cleaner: free, open-source Mac & Windows storage cleaner, optimizer and app uninstaller. Clears Xcode DerivedData, npm/Homebrew/Gradle caches and app leftovers. No telemetry in the app. MIT."

# 20 topics is GitHub's maximum. Ordered most-specific first so the ones that
# survive any future trimming are the ones that matter.
TOPICS=(
  mac-cleaner
  macos-cleaner
  disk-cleaner
  storage-cleaner
  disk-space
  system-cleaner
  windows-cleaner
  cleanmymac-alternative
  ccleaner-alternative
  appcleaner-alternative
  xcode
  deriveddata
  developer-tools
  cache-cleaner
  app-uninstaller
  system-monitor
  swiftui
  dotnet
  wpf
  open-source
)

echo "Applying metadata to ${REPO}..."

gh repo edit "$REPO" \
  --description "$DESCRIPTION" \
  --homepage "https://worm.clepsydratechnologies.com" \
  --enable-issues \
  --enable-wiki=false \
  --delete-branch-on-merge

gh repo edit "$REPO" --add-topic "${TOPICS[@]}"

echo
echo "Done. Current state:"
gh repo view "$REPO" --json name,description,homepageUrl,repositoryTopics \
  --template '{{.name}}
description: {{.description}}
homepage:    {{.homepageUrl}}
topics:      {{range .repositoryTopics}}{{.name}} {{end}}'
echo
echo "Remaining by hand:"
echo "  1. Pin the repository on your profile"
echo "  2. Create the first GitHub Release with real notes for v1.0.4"
echo "  3. Confirm the security tab shows SECURITY.md"
echo "  4. Star it from your own account (and ask colleagues), without buying any"