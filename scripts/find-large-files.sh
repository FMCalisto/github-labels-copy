#!/usr/bin/env bash
set -euo pipefail

# Project: git-toolkit
# Author: Francisco Maria Calisto
# Email: francisco.calisto@tecnico.ulisboa.pt
# License: MIT
# Repository: https://github.com/FMCalisto/git-toolkit
# Changes: See CHANGELOG.md
# Last reviewed: 2026-06-26
#
# git-toolkit: find-large-files.sh
# Find large regular files in the current working tree.

MIN_SIZE="+10M"
INCLUDE_UNTRACKED=1
DRY_RUN=0

usage() {
  cat <<'USAGE'
Usage: find-large-files.sh [options]

List large regular files in the current Git working tree. This is read-only.

Options:
      --min-size SIZE       Minimum size passed to find(1), default: +10M.
      --tracked-only        Only inspect files tracked by Git.
  -n, --dry-run             Accepted for interface consistency; no changes are made.
  -h, --help                Show this help text.

Examples:
  ./scripts/find-large-files.sh
  ./scripts/find-large-files.sh --min-size +50M
  ./scripts/find-large-files.sh --tracked-only

Limitations:
  - Uses find(1) size syntax, which is portable across common Unix systems.
  - Skips the .git directory.
USAGE
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --min-size)
      shift
      [[ $# -gt 0 ]] || die "--min-size requires a value"
      MIN_SIZE=$1
      ;;
    --tracked-only)
      INCLUDE_UNTRACKED=0
      ;;
    -n|--dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
  shift
done

git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
  die "run find-large-files.sh from inside a Git working tree"

root="$(git rev-parse --show-toplevel)"
cd "$root"

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf '[DRY-RUN] inspect files with minimum size %s\n' "$MIN_SIZE"
  exit 0
fi

if [[ "$INCLUDE_UNTRACKED" -eq 0 ]]; then
  while IFS= read -r -d '' file; do
    [[ -f "$file" ]] || continue
    if find "$file" -prune -type f -size "$MIN_SIZE" -print | grep -q .; then
      size="$(wc -c < "$file" | tr -d ' ')"
      printf '%12s  %s\n' "$size" "$file"
    fi
  done < <(git ls-files -z)
else
  while IFS= read -r -d '' file; do
    size="$(wc -c < "$file" | tr -d ' ')"
    printf '%12s  %s\n' "$size" "$file"
  done < <(find . -path ./.git -prune -o -type f -size "$MIN_SIZE" -print0)
fi
