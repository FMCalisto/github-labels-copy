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
# git-toolkit: status-summary.sh
# Print a compact, read-only summary of the current Git repository.

DRY_RUN=0

usage() {
  cat <<'USAGE'
Usage: status-summary.sh [options]

Print a compact repository status summary without changing the working tree.

Options:
  -n, --dry-run  Accepted for interface consistency; no changes are made.
  -h, --help      Show this help text.

Example:
  ./scripts/status-summary.sh

Limitations:
  - Requires a Git working tree.
  - Does not fetch remote state.
USAGE
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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
  die "run status-summary.sh from inside a Git working tree"

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf '[DRY-RUN] inspect repository status summary.\n'
  exit 0
fi

root="$(git rev-parse --show-toplevel)"
branch="$(git branch --show-current 2>/dev/null || true)"
upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"

printf 'Repository: %s\n' "$root"
printf 'Branch: %s\n' "${branch:-detached HEAD}"
printf 'Upstream: %s\n' "${upstream:-none}"

if [[ -n "$upstream" ]]; then
  read -r behind ahead < <(git rev-list --left-right --count "${upstream}...HEAD" 2>/dev/null || printf '0 0')
  printf 'Ahead/behind: %s ahead, %s behind\n' "$ahead" "$behind"
fi

printf '\nWorking tree counts:\n'
printf '  Modified tracked files: %s\n' "$(git ls-files --modified | wc -l | tr -d ' ')"
printf '  Deleted tracked files: %s\n' "$(git ls-files --deleted | wc -l | tr -d ' ')"
printf '  Untracked files: %s\n' "$(git ls-files --others --exclude-standard | wc -l | tr -d ' ')"
printf '  Staged entries: %s\n' "$(git diff --cached --name-only | wc -l | tr -d ' ')"

printf '\nShort status:\n'
git status --short
