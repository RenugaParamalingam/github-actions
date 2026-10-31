#!/usr/bin/env bash
set -euo pipefail

MIG_DIR="${MIG_DIR:-db/migrations}"
BASE="origin/main"

# 12 = YYYYMMDDHHMM
VERSION_DIGITS="${VERSION_DIGITS:-12}"

# New files must start with <digits>_ ; anything after that is allowed
NAME_REGEX="^([0-9]{${VERSION_DIGITS}})_.+"
# Used only to read existing versions on main
LOOSE_REGEX='^([0-9]+)_.+'

git fetch --no-tags origin main

# Highest version currently on main
latest=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  name=$(basename "$f")
  if [[ $name =~ $LOOSE_REGEX ]]; then
    v=$((10#${BASH_REMATCH[1]}))
    if (( v > latest )); then latest=$v; fi
  fi
done < <(git ls-tree -r --name-only "$BASE" -- "$MIG_DIR")

fail=0

# # Existing migrations must not be modified or deleted
# changed=$(git diff --no-renames --name-only --diff-filter=MD "$BASE"...HEAD -- "$MIG_DIR" || true)
# if [ -n "$changed" ]; then
#   echo "ERROR: existing migration files were modified or deleted:"
#   echo "$changed"
#   fail=1
# fi

# New migrations: validate file name format, then version
# (--no-renames so a renamed file counts as added)
added=$(git diff --no-renames --name-only --diff-filter=A "$BASE"...HEAD -- "$MIG_DIR" || true)

while IFS= read -r f; do
  [ -z "$f" ] && continue
  name=$(basename "$f")

  if [[ $name =~ $NAME_REGEX ]]; then
    v=$((10#${BASH_REMATCH[1]}))
    if (( v <= latest )); then
      echo "ERROR: $name has version $v, not greater than main's latest ($latest)."
      fail=1
    fi
  else
    echo "ERROR: invalid migration file name: $name"
    echo "       expected: <${VERSION_DIGITS} digits>_<anything>"
    fail=1
  fi
done <<< "$added"

if [ "$fail" -eq 1 ]; then
  echo "Fix the file names or rename with a fresh timestamp (e.g. $(date -u +%Y%m%d%H%M%S)) and push again."
  exit 1
fi

echo "Migration files OK (main latest: $latest)."