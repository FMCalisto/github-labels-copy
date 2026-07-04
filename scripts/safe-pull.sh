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
# git-toolkit: safe-pull.sh
# Inspect branch state and run a fast-forward-only pull.

DRY_RUN=0
FETCH=0

usage() {
  cat <<'USAGE'
Usage: safe-pull.sh [options]

Show local/upstream branch state and run a fast-forward-only pull. By default,
this script runs `git pull --ff-only`.

Options:
  -n, --dry-run       Print actions without changing the repository.
  -y, --yes           Execute actions (default; kept for compatibility).
      --fetch         Fetch before inspecting/pulling.
  -h, --help          Show this help text.

Examples:
  ./scripts/safe-pull.sh
  ./scripts/safe-pull.sh --yes
  ./scripts/safe-pull.sh --yes --fetch
  ./scripts/safe-pull.sh --dry-run

Limitations:
  - Requires the current branch to have an upstream.
  - Uses git pull --ff-only and refuses merge commits.
  - Does not stash or modify local changes before pulling.
USAGE
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[DRY-RUN]'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)
      DRY_RUN=1
      ;;
    -y|--yes)
      DRY_RUN=0
      ;;
    --fetch)
      FETCH=1
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
  die "run safe-pull.sh from inside a Git working tree"

branch="$(git branch --show-current)"
if [[ -z "$branch" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'Branch: detached HEAD\n'
    printf '[DRY-RUN] no pull; detached HEAD has no current branch.\n'
    exit 0
  fi
  die "detached HEAD; refusing to pull"
fi

upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
if [[ -z "$upstream" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'Branch: %s\n' "$branch"
    printf 'Upstream: none\n'
    printf '[DRY-RUN] no pull; current branch has no upstream.\n'
    exit 0
  fi
  die "current branch has no upstream"
fi

if [[ "$DRY_RUN" -eq 0 && -n "$(git status --porcelain)" ]]; then
  die "working tree is not clean; review or commit changes before pulling"
fi

if [[ "$FETCH" -eq 1 ]]; then
  run git fetch
fi

read -r behind ahead < <(git rev-list --left-right --count "${upstream}...HEAD")

printf 'Branch: %s\n' "$branch"
printf 'Upstream: %s\n' "$upstream"
printf 'Ahead/behind: %s ahead, %s behind\n' "$ahead" "$behind"

run git pull --ff-only
