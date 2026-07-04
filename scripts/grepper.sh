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
# git-toolkit: grepper.sh
# Commit tracked files with changes one at a time and push after each commit.

readonly SCRIPT_NAME="$(basename "$0")"
DRY_RUN=0
PUSH=1

usage() {
  cat <<'USAGE'
Usage: grepper.sh [options]

Commit each tracked file that differs from HEAD separately. By default, this
script adds, commits, and pushes each file.

Options:
  -n, --dry-run       Print actions without changing the repository.
  -y, --yes           Execute actions (default; kept for compatibility).
      --push          Push after each commit (default).
      --no-push       Commit locally without pushing.
  -h, --help          Show this help text.

Examples:
  ./scripts/grepper.sh
  ./scripts/grepper.sh --yes --push
  ./scripts/grepper.sh --dry-run

Limitations:
  - Handles tracked files with changes relative to HEAD.
  - Does not include untracked files; use lister.sh for that.
  - Does not remove files, rebase, or force-push.
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
  git rev-parse --verify HEAD >/dev/null 2>&1 ||
    die "HEAD does not exist yet; create an initial commit before using ${SCRIPT_NAME}"
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
  run git commit -m "[UPDATE] Update $(basename "$file")" -- "$file"
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
while IFS= read -r -d '' file_to_commit; do
  found=1
  commit_file "$file_to_commit"
done < <(git diff --name-only -z --diff-filter=ACMRTUXB HEAD --)

if [[ "$found" -eq 0 ]]; then
  printf 'No tracked file changes found.\n'
fi
