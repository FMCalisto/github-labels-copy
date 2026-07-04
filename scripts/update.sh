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
# git-toolkit: update.sh
# Update selected Git utility scripts in this or another repository.

readonly DEFAULT_SOURCE_URL="https://raw.githubusercontent.com/FMCalisto/git-toolkit/main"
readonly DEFAULT_TARGET_DIR="scripts"
readonly BACKUP_SUFFIX=".bak"

DRY_RUN=0
SOURCE="${GIT_TOOLKIT_SOURCE:-}"
TARGET_DIR="$DEFAULT_TARGET_DIR"
BACKUP=1
LIST_ONLY=0
ALL=0

MANAGED_SCRIPTS=(
  "audit-ignored.sh"
  "discreter.sh"
  "fast.sh"
  "find-large-files.sh"
  "grepper.sh"
  "lister.sh"
  "porcelainer.sh"
  "safe-pull.sh"
  "status-summary.sh"
  "update.sh"
)

SELECTED_SCRIPTS=()

usage() {
  cat <<'USAGE'
Usage: update.sh [options] [script ...]

Safely update selected Git utility scripts in a consuming repository from
git-toolkit. By default, this writes selected scripts.

Options:
  -n, --dry-run          Print actions without writing files.
  -y, --yes              Write selected scripts (default; kept for compatibility).
      --source VALUE     Source directory or base URL.
                         Default: local git-toolkit checkout when found,
                         otherwise https://raw.githubusercontent.com/FMCalisto/git-toolkit/main
      --target-dir DIR   Destination directory (default: scripts).
      --no-backup        Do not create .bak backups before overwriting files.
      --all              Update every managed git-toolkit script.
      --list             List selected scripts and exit.
  -h, --help             Show this help text.

Examples:
  ./scripts/update.sh
  ./scripts/update.sh --dry-run
  ./scripts/update.sh --all
  ./scripts/update.sh --list
  ./scripts/update.sh --source /path/to/git-toolkit
  ./scripts/update.sh --yes fast.sh lister.sh
  GIT_TOOLKIT_SOURCE=/path/to/git-toolkit ./scripts/update.sh --yes update.sh

Notes:
  - Script arguments override SELECTED_SCRIPTS.
  - Without script arguments, a new target installs every managed script.
  - After at least one non-updater managed script is installed, the default
    selection updates only installed managed scripts plus update.sh.
  - Existing files are backed up as <name>.bak unless --no-backup is used.
  - Only files under git-toolkit/scripts/ are copied.
USAGE
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

is_url() {
  [[ "$1" == http://* || "$1" == https://* ]]
}

detect_default_source() {
  local cwd
  local parent
  local candidate
  local candidates=()

  cwd="$(pwd -P 2>/dev/null || pwd)"
  parent="$(dirname "$cwd")"

  candidates+=("${parent}/git-toolkit")

  if [[ -n "${HOME:-}" ]]; then
    candidates+=("${HOME}/Git/git-toolkit" "${HOME}/git-toolkit")
  fi

  for candidate in "${candidates[@]}"; do
    if [[ -f "${candidate%/}/scripts/update.sh" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  printf '%s\n' "$DEFAULT_SOURCE_URL"
}

print_source_hint() {
  local script=$1

  if is_url "$SOURCE"; then
    printf 'Hint: %s may not exist at the configured URL yet.\n' "$script" >&2
    printf 'Hint: If it exists in a local git-toolkit checkout, run:\n' >&2
    printf '      GIT_TOOLKIT_SOURCE=/path/to/git-toolkit ./scripts/update.sh\n' >&2
    printf '      ./scripts/update.sh --source /path/to/git-toolkit\n' >&2
  else
    printf 'Hint: Check that the source checkout contains scripts/%s.\n' "$script" >&2
  fi
}

validate_script_name() {
  local name=$1
  [[ "$name" == *.sh ]] || die "script must end in .sh: $name"
  [[ "$name" != */* ]] || die "script names must not contain slashes: $name"
  [[ "$name" != .* ]] || die "script names must not begin with dot: $name"
}

download_script() {
  local script=$1
  local destination=$2
  local source_file

  if is_url "$SOURCE"; then
    command -v curl >/dev/null 2>&1 || die "curl is required for URL sources"
    source_file="${SOURCE%/}/scripts/${script}"
    curl --fail --location --silent --show-error "$source_file" --output "$destination"
  else
    source_file="${SOURCE%/}/scripts/${script}"
    if [[ ! -f "$source_file" ]]; then
      printf 'Error: source script not found: %s\n' "$source_file" >&2
      return 1
    fi
    cp "$source_file" "$destination"
  fi
}

update_script() {
  local script=$1
  local destination="${TARGET_DIR%/}/${script}"
  local temp_file

  validate_script_name "$script"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[DRY-RUN] update %s from %s\n' "$destination" "$SOURCE"
    return 0
  fi

  mkdir -p "$TARGET_DIR"
  temp_file="$(mktemp)"

  if ! download_script "$script" "$temp_file"; then
    rm -f "$temp_file"
    print_source_hint "$script"
    die "failed to update ${script} from ${SOURCE}"
  fi

  if [[ -f "$destination" && "$BACKUP" -eq 1 ]]; then
    cp "$destination" "${destination}${BACKUP_SUFFIX}"
  fi

  install -m 0755 "$temp_file" "$destination"
  rm -f "$temp_file"
}

requested_scripts=()

if [[ -z "$SOURCE" ]]; then
  SOURCE="$(detect_default_source)"
fi

select_installed_scripts() {
  local script
  local installed_non_updater=0
  SELECTED_SCRIPTS=()

  for script in "${MANAGED_SCRIPTS[@]}"; do
    if [[ "$script" == "update.sh" ]]; then
      continue
    fi

    if [[ -f "${TARGET_DIR%/}/${script}" ]]; then
      SELECTED_SCRIPTS+=("$script")
      installed_non_updater=1
    fi
  done

  if [[ "$installed_non_updater" -eq 0 ]]; then
    SELECTED_SCRIPTS=("${MANAGED_SCRIPTS[@]}")
  else
    SELECTED_SCRIPTS+=("update.sh")
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
    --source)
      shift
      [[ $# -gt 0 ]] || die "--source requires a value"
      SOURCE=$1
      ;;
    --target-dir)
      shift
      [[ $# -gt 0 ]] || die "--target-dir requires a value"
      TARGET_DIR=$1
      ;;
    --no-backup)
      BACKUP=0
      ;;
    --all)
      ALL=1
      ;;
    --list)
      LIST_ONLY=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        requested_scripts+=("$1")
        shift
      done
      break
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      requested_scripts+=("$1")
      ;;
  esac
  shift
done

if [[ "${#requested_scripts[@]}" -gt 0 ]]; then
  SELECTED_SCRIPTS=("${requested_scripts[@]}")
elif [[ "$ALL" -eq 1 ]]; then
  SELECTED_SCRIPTS=("${MANAGED_SCRIPTS[@]}")
else
  select_installed_scripts
fi

[[ "${#SELECTED_SCRIPTS[@]}" -gt 0 ]] || die "no scripts selected"

if [[ "$LIST_ONLY" -eq 1 ]]; then
  printf '%s\n' "${SELECTED_SCRIPTS[@]}"
  exit 0
fi

for script in "${SELECTED_SCRIPTS[@]}"; do
  update_script "$script"
done

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf 'Dry run complete. Re-run without --dry-run to update files.\n'
else
  printf 'Updated %s script(s) in %s.\n' "${#SELECTED_SCRIPTS[@]}" "$TARGET_DIR"
fi
