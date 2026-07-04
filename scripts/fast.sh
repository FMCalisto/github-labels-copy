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
# git-toolkit: fast.sh
# Commit pending files one at a time, then rebase and push once.

readonly SCRIPT_NAME="$(basename "$0")"
DRY_RUN=0
PUSH=1
REBASE=1
MIN_WAIT=1
MAX_WAIT=5
CAF_PID=""

usage() {
  cat <<'USAGE'
Usage: fast.sh [options]

Commit each pending file separately. Pending files include tracked changes,
tracked deletions, and untracked non-ignored files. Between commits, wait for a
random delay. By default, this script commits each file, then fetches, rebases,
and pushes once after the working tree is clean.

Options:
  -n, --dry-run       Print actions without changing the repository.
  -y, --yes           Execute actions (default; kept for compatibility).
      --push          Push after committing pending files (default).
      --no-push       Commit locally without pushing.
      --rebase        Fetch and rebase onto the upstream branch before pushing.
                      Enabled by default.
      --no-rebase     Push without fetching/rebasing first.
      --min-wait N    Minimum wait in seconds between files (default: 1).
      --max-wait N    Maximum wait in seconds between files (default: 5).
  -h, --help          Show this help text.

Examples:
  ./scripts/fast.sh
  ./scripts/fast.sh --yes --push
  ./scripts/fast.sh --yes --push --rebase --min-wait 10 --max-wait 50
  ./scripts/fast.sh --dry-run

Limitations:
  - Commits full files, not partial hunks.
  - Does not remove files or force-push.
  - Requires an upstream branch when executing the default push workflow.
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

current_branch() {
  git symbolic-ref --quiet --short HEAD 2>/dev/null ||
    die "not on a branch; refusing to push from detached HEAD"
}

upstream_branch() {
  git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null ||
    die "current branch has no upstream; set one before using --push"
}

require_upstream_for_push() {
  [[ "$PUSH" -eq 0 ]] && return 0
  [[ "$DRY_RUN" -eq 1 ]] && return 0
  upstream_branch >/dev/null
}

validate_waits() {
  [[ "$MIN_WAIT" =~ ^[0-9]+$ ]] || die "--min-wait must be a non-negative integer"
  [[ "$MAX_WAIT" =~ ^[0-9]+$ ]] || die "--max-wait must be a non-negative integer"
  (( MAX_WAIT >= MIN_WAIT )) || die "--max-wait must be greater than or equal to --min-wait"
}

random_wait() {
  local span wait_time
  span=$((MAX_WAIT - MIN_WAIT + 1))
  wait_time=$((MIN_WAIT + RANDOM % span))
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[DRY-RUN] sleep %s\n' "$wait_time"
    return 0
  fi
  printf 'Waiting %s second(s)...\n' "$wait_time"
  sleep "$wait_time"
}

start_caffeinate_if_available() {
  if [[ "$DRY_RUN" -eq 0 && "$(uname -s)" == "Darwin" ]] && command -v caffeinate >/dev/null 2>&1; then
    caffeinate -d -i -m -s -u &
    CAF_PID=$!
  fi
}

stop_caffeinate() {
  if [[ -n "$CAF_PID" ]]; then
    kill "$CAF_PID" 2>/dev/null || true
  fi
}

commit_file() {
  local file=$1
  local label="UPDATE"
  local staged_count

  if git diff --name-only --diff-filter=D HEAD -- "$file" | grep -q .; then
    label="DELETE"
  elif ! git ls-files --error-unmatch -- "$file" >/dev/null 2>&1; then
    label="ADD"
  elif [[ ! -e "$file" ]]; then
    label="DELETE"
  fi

  printf '%s\n' "$file"
  if [[ "$label" == "DELETE" ]]; then
    if git ls-files --error-unmatch -- "$file" >/dev/null 2>&1; then
      run git add -A -- "$file"
      run git commit -m "[${label}] $(basename "$file")" -- "$file"
    elif [[ "$DRY_RUN" -eq 1 ]]; then
      printf '[DRY-RUN] deletion already staged for %q\n' "$file"
      printf '[DRY-RUN]'
      printf ' %q' git commit -m "[${label}] $(basename "$file")"
      printf '\n'
    else
      staged_count="$(git diff --cached --name-only | wc -l | tr -d ' ')"
      if [[ "$staged_count" != "1" ]]; then
        die "deletion for ${file} is already staged with other staged changes; commit or unstage those changes first"
      fi
      git commit -m "[${label}] $(basename "$file")"
    fi
  else
    run git add -A -- "$file"
    run git commit -m "[${label}] $(basename "$file")" -- "$file"
  fi
}

sync_branch() {
  local rebase_target
  if [[ "$PUSH" -eq 1 ]]; then
    if [[ "$REBASE" -eq 1 ]]; then
      if [[ "$DRY_RUN" -eq 0 && -n "$(git status --porcelain --untracked-files=normal)" ]]; then
        die "working tree still has pending changes; refusing to rebase"
      fi
      if [[ "$DRY_RUN" -eq 1 ]]; then
        rebase_target="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || printf '@{u}')"
      else
        rebase_target="$(upstream_branch)"
      fi
      run git fetch origin "$(current_branch)"
      run git rebase "$rebase_target"
    fi
    run git push
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
    --push)
      PUSH=1
      ;;
    --no-push)
      PUSH=0
      REBASE=0
      ;;
    --rebase)
      REBASE=1
      ;;
    --no-rebase)
      REBASE=0
      ;;
    --min-wait)
      shift
      [[ $# -gt 0 ]] || die "--min-wait requires a value"
      MIN_WAIT=$1
      ;;
    --max-wait)
      shift
      [[ $# -gt 0 ]] || die "--max-wait requires a value"
      MAX_WAIT=$1
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

[[ "$REBASE" -eq 0 || "$PUSH" -eq 1 ]] || die "--rebase requires --push"

validate_waits
require_git_repo
require_upstream_for_push

printf 'Working tree: %s\n' "$(git rev-parse --show-toplevel)"

found=0
pending_files=()
pending_count=0
trap stop_caffeinate EXIT
start_caffeinate_if_available

append_pending_file() {
  local candidate=$1
  local existing
  if (( pending_count > 0 )); then
    for existing in "${pending_files[@]}"; do
      [[ "$existing" == "$candidate" ]] && return 0
    done
  fi
  pending_files[$pending_count]=$candidate
  pending_count=$((pending_count + 1))
}

while IFS= read -r -d '' file_to_commit; do
  append_pending_file "$file_to_commit"
done < <(git diff --name-only -z HEAD --)

while IFS= read -r -d '' file_to_commit; do
  append_pending_file "$file_to_commit"
done < <(git ls-files --others --exclude-standard -z)

if (( pending_count > 0 )); then
  for file_to_commit in "${pending_files[@]}"; do
    found=1
    commit_file "$file_to_commit"
    random_wait
  done
fi

if [[ "$found" -eq 0 ]]; then
  printf 'No pending files found.\n'
fi

sync_branch
