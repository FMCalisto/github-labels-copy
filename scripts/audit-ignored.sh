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
# git-toolkit: audit-ignored.sh
# Show ignored files and explain which ignore rule matched them.

LIMIT=100
DRY_RUN=0

usage() {
  cat <<'USAGE'
Usage: audit-ignored.sh [options]

List ignored files and show the ignore rule responsible for each match. This is
read-only and helps catch accidental ignore patterns.

Options:
      --limit N      Maximum ignored paths to inspect, default: 100.
  -n, --dry-run      Accepted for interface consistency; no changes are made.
  -h, --help         Show this help text.

Example:
  ./scripts/audit-ignored.sh
  ./scripts/audit-ignored.sh --limit 25

Limitations:
  - Very large repositories may need a lower --limit.
  - Output depends on Git's ignore and exclude configuration.
USAGE
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit)
      shift
      [[ $# -gt 0 ]] || die "--limit requires a value"
      [[ "$1" =~ ^[0-9]+$ ]] || die "--limit must be a non-negative integer"
      LIMIT=$1
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
  die "run audit-ignored.sh from inside a Git working tree"

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf '[DRY-RUN] inspect up to %s ignored path(s).\n' "$LIMIT"
  exit 0
fi

count=0
while IFS= read -r -d '' entry; do
  [[ "${entry:0:3}" == "!! " ]] || continue
  path="${entry:3}"
  (( count += 1 ))
  git check-ignore -v -- "$path" || true
  [[ "$count" -lt "$LIMIT" ]] || break
done < <(git status --ignored --porcelain=v1 -z)

if [[ "$count" -eq 0 ]]; then
  printf 'No ignored files reported by git status.\n'
elif [[ "$count" -eq "$LIMIT" ]]; then
  printf 'Stopped after %s ignored path(s). Increase --limit to inspect more.\n' "$LIMIT"
fi
