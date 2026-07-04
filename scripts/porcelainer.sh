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
# git-toolkit: porcelainer.sh
# Commit untracked files discovered through porcelain status output one at a
# time and push after each commit.

readonly SCRIPT_NAME="$(basename "$0")"
DRY_RUN=0
PUSH=1

usage() {
  cat <<'USAGE'
Usage: porcelainer.sh [options]

Commit each untracked, non-ignored regular file separately using
git status --porcelain as the source of file names. By default, this script
adds, commits, and pushes each file.

Options:
  -n, --dry-run       Print actions without changing the repository.
  -y, --yes           Execute actions (default; kept for compatibility).
      --push          Push after each commit (default).
      --no-push       Commit locally without pushing.
  -h, --help          Show this help text.

Examples:
  ./scripts/porcelainer.sh
  ./scripts/porcelainer.sh --yes --push
  ./scripts/porcelainer.sh --dry-run

Limitations:
  - Handles untracked regular files only.
  - Does not remove files, rebase, or force-push.
  - lister.sh is usually simpler unless porcelain output is specifically wanted.
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

require_git_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    die "run ${SCRIPT_NAME} from inside a Git working tree"
}

require_upstream_for_push() {
  [[ "$PUSH" -eq 0 ]] && return 0
  [[ "$DRY_RUN" -eq 1 ]] && return 0
  git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1 ||
    die "current branch has no upstream; set one before using --push"
}

commit_file() {
  local file=$1
  [[ -f "$file" ]] || return 0

  printf '%s\n' "$file"
  run git add -- "$file"
  run git commit -m "[ADD] New $(basename "$file") File" -- "$file"
  [[ "$PUSH" -eq 0 ]] || run git push
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)
      DRY_RUN=1
      ;;
    -y|--yes)
      DRY_RUN=0
      ;;
    --push)
      PUSH=1
      ;;
    --no-push)
      PUSH=0
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

require_git_repo
require_upstream_for_push

printf 'Working tree: %s\n' "$(git rev-parse --show-toplevel)"

found=0
while IFS= read -r -d '' status_entry; do
  if [[ "${status_entry:0:2}" == "??" ]]; then
    found=1
    commit_file "${status_entry:3}"
  fi
done < <(git status --porcelain=v1 -z --untracked-files=normal)

if [[ "$found" -eq 0 ]]; then
  printf 'No untracked, non-ignored files found.\n'
fi
