#!/usr/bin/env bash
set -euo pipefail

MIG_DIR="${MIG_DIR:-migrations}"
BASE="origin/main"

git fetch --no-tags origin main

ver() { sed -E 's#.*/([0-9]+)_.*#\1#'; }

# Highest version currently on main
latest=$(git ls-tree -r --name-only "$BASE" -- "$MIG_DIR" | ver | sort -n | tail -1)
latest=${latest:-0}

# Files this PR adds (--no-renames so a renamed file counts as added)
added=$(git diff --no-renames --name-only --diff-filter=A "$BASE"...HEAD -- "$MIG_DIR" | ver | sort -u)

# Existing migrations must not be modified, deleted or renamed
changed=$(git diff --no-renames --name-only --diff-filter=MD "$BASE"...HEAD -- "$MIG_DIR" || true)
if [ -n "$changed" ]; then
  echo "ERROR: existing migration files were modified or deleted:"
  echo "$changed"
  exit 1
fi

if [ -z "$added" ]; then
  echo "No new migrations. OK."
  exit 0
fi

fail=0
for v in $added; do
  if [ "$v" -le "$latest" ]; then
    echo "ERROR: migration version $v is not greater than main's latest ($latest)."
    fail=1
  fi
done

if [ "$fail" -eq 1 ]; then
  echo "Rename your migration files with a fresh timestamp (e.g. $(date -u +%Y%m%d%H%M%S)) and push again."
  exit 1
fi

echo "Migration versions OK (main latest: $latest)."