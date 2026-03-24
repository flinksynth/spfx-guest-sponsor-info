#!/usr/bin/env bash
# Stamp a SemVer tag into package.json and config/package-solution.json.
#
# Usage:
#   scripts/set-version.sh              # interactive mode
#   scripts/set-version.sh --help       # show this help
#   scripts/set-version.sh v1.2.3           # stamp only (for CI)
#   scripts/set-version.sh v1.2.3 --commit  # stamp + git commit + git tag
#   scripts/set-version.sh v1.2.3 --commit --push  # stamp + commit + tag + push
#   scripts/set-version.sh v1.2.3 --retag --commit --push  # delete & recreate tag
#   scripts/set-version.sh v1.2.3 --commit --push --dry-run  # preview without changes
#   scripts/set-version.sh v1.2.3 --commit --skip-build  # skip the build step
#
# When --commit is set the script runs scripts/build.sh first to verify the
# project builds cleanly before the tag is created. Use --skip-build to omit
# this step — e.g. when called from CI which already runs its own build.
#
# Both forms are accepted; a leading "v" is stripped automatically.
# SPFx requires a four-part version (major.minor.patch.build), so ".0" is
# appended for package-solution.json.
#
# Recommended release workflow:
#   ./scripts/set-version.sh v1.2.3 --commit --push
# The pushed tag triggers the release GitHub Actions workflow automatically.
#
# To move a tag to a different commit (e.g. after amending the release commit):
#   ./scripts/set-version.sh v1.2.3 --retag --commit --push
# This deletes the local tag, remote tag, and GitHub release (if gh is
# available), then re-stamps, re-commits and re-pushes.

set -euo pipefail

# Always run from the repository root so paths resolve correctly.
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #

show_help() {
  cat <<'EOF'
Usage: scripts/set-version.sh [OPTIONS] [<version>]

Stamp a SemVer version into package.json, azure-function/package.json,
and config/package-solution.json.

Arguments:
  <version>   Target version, e.g. v1.2.3 or 1.2.3. A leading "v" is stripped
              automatically. When omitted, interactive mode starts.
  --commit    After stamping, create a git commit and annotated tag.
              In interactive mode you will be asked.
  --push      After committing and tagging, push branch and tags to origin.
              Implies --commit. In interactive mode you will be asked.
  --retag     Before stamping, delete the existing local tag, remote tag, and
              GitHub release (if gh CLI is available) for <version>.
              Requires <version> to be specified explicitly.
              A safety confirmation is always required. Combine with --commit
              --push to fully recreate the release in one command.
  --dry-run   Preview all actions without modifying any files or running git
              or npm commands. No changes will be written to disk or pushed.
  --skip-build
              Skip the build step that normally runs before creating the git
              commit. Use this when the caller (e.g. a CI workflow) already
              builds the project independently to avoid a redundant build.

Options:
  -h, --help  Show this help and exit.

Interactive mode (no arguments):
  Detects the current version from the last git tag (falling back to
  package.json) and suggests next patch, minor, and major versions.

Examples:
  scripts/set-version.sh                                    # interactive
  scripts/set-version.sh v1.2.3                             # stamp only (CI)
  scripts/set-version.sh v1.2.3 --commit                    # stamp + commit + tag
  scripts/set-version.sh v1.2.3 --commit --push             # stamp + commit + tag + push
  scripts/set-version.sh v1.2.3 --retag --commit --push       # move tag to new commit
  scripts/set-version.sh v1.2.3 --commit --push --dry-run     # preview without changes
  scripts/set-version.sh v1.2.3 --commit --push --skip-build  # skip build step
EOF
}

# Prints "X.Y.Z (from git tag vX.Y.Z)" or "X.Y.Z (from package.json)"
get_current_label() {
  local tag
  tag=$(git describe --tags --match "v*" --abbrev=0 2>/dev/null || true)
  if [[ -n "$tag" ]]; then
    printf '%s (from git tag %s)' "${tag#v}" "$tag"
    return
  fi
  local ver
  ver=$(node -p "require('./package.json').version" 2>/dev/null || true)
  if [[ -n "$ver" ]]; then
    printf '%s (from package.json)' "$ver"
    return
  fi
  echo "unknown"
}

# Returns just the bare semver string (no label)
get_current_semver() {
  local tag
  tag=$(git describe --tags --match "v*" --abbrev=0 2>/dev/null || true)
  if [[ -n "$tag" ]]; then
    echo "${tag#v}"
    return
  fi
  node -p "require('./package.json').version" 2>/dev/null || echo "0.0.0"
}

# bump_version <x.y.z> <patch|minor|major>
bump_version() {
  local version="$1" bump="$2"
  local major minor patch
  IFS='.' read -r major minor patch <<<"$version"
  patch="${patch%%[-+]*}" # strip any pre-release/build suffix
  case "$bump" in
    major) echo "$((major + 1)).0.0" ;;
    minor) echo "${major}.$((minor + 1)).0" ;;
    patch) echo "${major}.${minor}.$((patch + 1))" ;;
  esac
}

# Execute a command, or in dry-run mode just print it instead.
# Note: not suitable for commands using shell redirections — handle those inline.
maybe() {
  if [[ "${DO_DRYRUN}" == "true" ]]; then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}

# suggest_bump [<base_tag>]
# Analyses Conventional Commits since <base_tag> (or the last git tag) and
# returns "major", "minor", or "patch".
suggest_bump() {
  local base_tag="${1:-}"
  if [[ -z "$base_tag" ]]; then
    base_tag=$(git describe --tags --match "v*" --abbrev=0 2>/dev/null || true)
  fi

  local range="HEAD"
  if [[ -n "$base_tag" ]]; then
    range="${base_tag}..HEAD"
  fi

  # Collect all one-line subjects (safe in a variable — no NUL bytes needed)
  local subjects
  subjects=$(git log "$range" --format="%s" 2>/dev/null || true)

  if [[ -z "$subjects" ]]; then
    echo "patch"
    return
  fi

  # Breaking change in subject line: type!: or type(scope)!:
  # Each grep runs inside an if-condition, so set -e does not apply.
  if echo "$subjects" | grep -qE '^[a-zA-Z]+(\([^)]*\))?!:'; then
    echo "major"
    return
  fi

  # Breaking change token in any commit body / footer
  if git log "$range" --format="%b" 2>/dev/null |
    grep -qiE '^(BREAKING CHANGE|BREAKING-CHANGE):'; then
    echo "major"
    return
  fi

  # Feature commit → minor
  if echo "$subjects" | grep -qE '^feat(\([^)]*\))?:'; then
    echo "minor"
    return
  fi

  echo "patch"
}

# --------------------------------------------------------------------------- #
# Argument parsing
# --------------------------------------------------------------------------- #

TAG=""
DO_COMMIT=false
DO_PUSH=false
DO_RETAG=false
DO_DRYRUN=false
DO_BUILD=true # default on when --commit is set; disable with --skip-build

for arg in "$@"; do
  case "$arg" in
    -h | --help)
      show_help
      exit 0
      ;;
    --commit)
      DO_COMMIT=true
      ;;
    --push)
      DO_COMMIT=true
      DO_PUSH=true
      ;;
    --retag)
      DO_RETAG=true
      ;;
    --dry-run)
      DO_DRYRUN=true
      ;;
    --skip-build)
      DO_BUILD=false
      ;;
    -*)
      echo "Unknown option: $arg" >&2
      echo "Run '$0 --help' for usage." >&2
      exit 1
      ;;
    *)
      if [[ -z "$TAG" ]]; then
        TAG="$arg"
      else
        echo "Unexpected argument: $arg" >&2
        echo "Run '$0 --help' for usage." >&2
        exit 1
      fi
      ;;
  esac
done

# --retag always requires an explicit version (not compatible with interactive
# version selection — you must know which tag you are replacing).
if [[ "${DO_RETAG}" == "true" && -z "${TAG}" ]]; then
  echo "Error: --retag requires an explicit version argument (e.g. v1.2.3)." >&2
  echo "Run '$0 --help' for usage." >&2
  exit 1
fi

# --------------------------------------------------------------------------- #
# Early branch check
# --------------------------------------------------------------------------- #
#
# Run before the interactive menu so the user finds out immediately, not after
# spending time in the version selector.
# Triggers when:
#   - --commit or --push is given (non-interactive intent known up front), or
#   - interactive mode with a TTY (we don't know yet if they'll commit, but
#     warn now so they can abort before the menu).

CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || true)
if [[ "${CURRENT_BRANCH}" != "main" ]]; then
  if [[ "${DO_COMMIT}" == "true" || -t 0 ]]; then
    echo ""
    echo "Warning: you are on branch '${CURRENT_BRANCH}', not 'main'."
    echo "Release commits and tags should normally come from 'main'."
    if [[ -t 0 ]]; then
      read -rp "Continue anyway? [y/N]: " BRANCH_EARLY_ANSWER
      if [[ "${BRANCH_EARLY_ANSWER,,}" != "y" && "${BRANCH_EARLY_ANSWER,,}" != "yes" ]]; then
        echo "Aborted." >&2
        exit 1
      fi
      echo ""
    else
      echo "Error: releases should be pushed from 'main'. Run from the correct branch." >&2
      exit 1
    fi
  fi
fi

# --------------------------------------------------------------------------- #
# Interactive mode (no version argument)
# --------------------------------------------------------------------------- #

if [[ -z "$TAG" ]]; then
  if [[ ! -t 0 ]]; then
    echo "Error: interactive mode requires a TTY. Pass a version explicitly." >&2
    echo "Run '$0 --help' for usage." >&2
    exit 1
  fi

  CURRENT_LABEL=$(get_current_label)
  CURRENT_SEMVER=$(get_current_semver)
  NEXT_PATCH=$(bump_version "$CURRENT_SEMVER" patch)
  NEXT_MINOR=$(bump_version "$CURRENT_SEMVER" minor)
  NEXT_MAJOR=$(bump_version "$CURRENT_SEMVER" major)

  # Determine recommended bump from Conventional Commits since last tag
  LAST_TAG=$(git describe --tags --match "v*" --abbrev=0 2>/dev/null || true)
  RECOMMENDED=$(suggest_bump "$LAST_TAG")

  # Map recommendation to menu choice number and default version
  case "$RECOMMENDED" in
    major)
      DEFAULT_CHOICE=3
      DEFAULT_VER="$NEXT_MAJOR"
      ;;
    minor)
      DEFAULT_CHOICE=2
      DEFAULT_VER="$NEXT_MINOR"
      ;;
    *)
      DEFAULT_CHOICE=1
      DEFAULT_VER="$NEXT_PATCH"
      ;;
  esac

  # Build menu labels — mark recommended entry with ★
  LABEL_PATCH="patch  →  ${NEXT_PATCH}"
  LABEL_MINOR="minor  →  ${NEXT_MINOR}"
  LABEL_MAJOR="major  →  ${NEXT_MAJOR}"
  case "$RECOMMENDED" in
    major) LABEL_MAJOR="${LABEL_MAJOR}  ★ recommended" ;;
    minor) LABEL_MINOR="${LABEL_MINOR}  ★ recommended" ;;
    *) LABEL_PATCH="${LABEL_PATCH}  ★ recommended" ;;
  esac

  echo ""
  echo "Current version: ${CURRENT_LABEL}"
  if [[ -n "$LAST_TAG" ]]; then
    COMMIT_COUNT=$(git rev-list "${LAST_TAG}..HEAD" --count 2>/dev/null || echo "?")
    echo "Commits since ${LAST_TAG}: ${COMMIT_COUNT}"
  fi
  echo ""
  echo "──────────────────────────────────────────────────────────────────────"
  echo "Changes that will be included in the next release:"
  echo "──────────────────────────────────────────────────────────────────────"
  if ./scripts/release-notes.sh 2>/dev/null; then
    :
  else
    echo "(release-notes.sh failed or git-cliff not available — skipping preview)"
  fi
  echo "──────────────────────────────────────────────────────────────────────"
  echo ""
  echo "Suggested next versions:"
  echo "  1) ${LABEL_PATCH}"
  echo "  2) ${LABEL_MINOR}"
  echo "  3) ${LABEL_MAJOR}"
  echo "  4) Enter a custom version"
  echo ""

  while true; do
    read -rp "Select [1-4] or press Enter for recommended (${DEFAULT_VER}): " CHOICE
    CHOICE="${CHOICE:-${DEFAULT_CHOICE}}"
    case "$CHOICE" in
      1)
        TAG="$NEXT_PATCH"
        break
        ;;
      2)
        TAG="$NEXT_MINOR"
        break
        ;;
      3)
        TAG="$NEXT_MAJOR"
        break
        ;;
      4)
        read -rp "Enter version (e.g. 1.2.3 or v1.2.3): " CUSTOM
        if [[ -z "$CUSTOM" ]]; then
          echo "No version entered, please try again." >&2
          continue
        fi
        TAG="$CUSTOM"
        break
        ;;
      *)
        echo "Invalid choice — enter 1, 2, 3, or 4." >&2
        ;;
    esac
  done

  # Show release notes preview with the chosen version tag applied
  echo ""
  echo "──────────────────────────────────────────────────────────────────────"
  echo "Final release notes for ${TAG}:"
  echo "──────────────────────────────────────────────────────────────────────"
  if ./scripts/release-notes.sh --tag "${TAG}" 2>/dev/null; then
    :
  else
    echo "(release-notes.sh failed or git-cliff not available — skipping preview)"
  fi
  echo "──────────────────────────────────────────────────────────────────────"
  echo ""

  read -rp "Create git commit and tag? [y/N]: " COMMIT_ANSWER
  if [[ "${COMMIT_ANSWER,,}" == "y" || "${COMMIT_ANSWER,,}" == "yes" ]]; then
    DO_COMMIT=true
    read -rp "Run build before committing? [Y/n]: " BUILD_ANSWER
    if [[ "${BUILD_ANSWER,,}" == "n" || "${BUILD_ANSWER,,}" == "no" ]]; then
      DO_BUILD=false
    fi
    read -rp "Also push to origin? [y/N]: " PUSH_ANSWER
    if [[ "${PUSH_ANSWER,,}" == "y" || "${PUSH_ANSWER,,}" == "yes" ]]; then
      DO_PUSH=true
    fi
  fi
  echo ""
fi

# --------------------------------------------------------------------------- #
# Preflight checks
# --------------------------------------------------------------------------- #

# Dirty working tree: warn when --commit is set and uncommitted changes exist.
if [[ "${DO_COMMIT}" == "true" ]]; then
  DIRTY=$(git status --porcelain 2>/dev/null || true)
  if [[ -n "${DIRTY}" ]]; then
    echo ""
    echo "Warning: working tree has uncommitted changes:"
    echo "${DIRTY}" | while IFS= read -r line; do echo "  ${line}"; done
    echo ""
    echo "These may end up in the release commit. Continue only if intentional."
    if [[ -t 0 ]]; then
      read -rp "Continue anyway? [y/N]: " DIRTY_ANSWER
      if [[ "${DIRTY_ANSWER,,}" != "y" && "${DIRTY_ANSWER,,}" != "yes" ]]; then
        echo "Aborted." >&2
        exit 1
      fi
      echo ""
    else
      echo "Error: working tree is dirty. Commit or stash changes first." >&2
      exit 1
    fi
  fi
fi

# Branch check: warn when --push is set and not on the default branch.
# (Early check above already caught interactive and --commit cases;
# this handles the edge case where --push is added non-interactively
# without --commit, which implies --commit anyway.)
if [[ "${DO_PUSH}" == "true" && "${CURRENT_BRANCH}" != "main" ]]; then
  # Already warned above; if we reach here in non-TTY mode, abort.
  if [[ ! -t 0 ]]; then
    echo "Error: releases should be pushed from 'main'. Run from the correct branch." >&2
    exit 1
  fi
fi

# --------------------------------------------------------------------------- #
# Validate and normalise
# --------------------------------------------------------------------------- #

SEMVER="${TAG#v}"      # strip leading "v" if present
VTAG="v${SEMVER}"      # ensure "v" prefix for the git tag
SPFX_VER="${SEMVER}.0" # SPFx requires four-part version (major.minor.patch.build)

if ! [[ "$SEMVER" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][a-zA-Z0-9.]+)?$ ]]; then
  echo "Error: '$SEMVER' is not a valid SemVer string (expected e.g. 1.2.3)." >&2
  exit 1
fi

# --------------------------------------------------------------------------- #
# Detect "re-release" situation: tag already exists but HEAD has moved on
# --------------------------------------------------------------------------- #

if [[ "${DO_RETAG}" == "false" ]] && git tag -l "${VTAG}" | grep -q .; then
  TAGGED_COMMIT=$(git rev-parse "${VTAG}^{}" 2>/dev/null || true)
  HEAD_COMMIT=$(git rev-parse HEAD)
  COMMITS_SINCE=$(git rev-list "${VTAG}..HEAD" --count 2>/dev/null || echo "0")

  if [[ "${TAGGED_COMMIT}" != "${HEAD_COMMIT}" && "${COMMITS_SINCE}" -gt 0 ]]; then
    echo ""
    echo "Note: tag ${VTAG} already exists but HEAD is ${COMMITS_SINCE} commit(s) ahead of it."
    if [[ -t 0 ]]; then
      read -rp "Move tag ${VTAG} to the current commit (retag)? [y/N]: " RETAG_AUTO
      if [[ "${RETAG_AUTO,,}" == "y" || "${RETAG_AUTO,,}" == "yes" ]]; then
        DO_RETAG=true
      fi
      echo ""
    elif [[ "${DO_COMMIT}" == "true" ]]; then
      echo "Error: tag ${VTAG} already exists. Use --retag to move it." >&2
      exit 1
    fi
  elif [[ "${TAGGED_COMMIT}" == "${HEAD_COMMIT}" && "${DO_COMMIT}" == "true" ]]; then
    echo ""
    echo "Note: tag ${VTAG} already points to HEAD — no new commit to create."
    echo "Skipping git commit, tag and push (already up to date)."
    DO_COMMIT=false
    DO_PUSH=false
    echo ""
  fi
fi

# --------------------------------------------------------------------------- #
# Retag: delete existing tag locally, remotely, and on GitHub
# --------------------------------------------------------------------------- #

if [[ "${DO_RETAG}" == "true" ]]; then
  if [[ ! -t 0 && "${DO_DRYRUN}" == "false" ]]; then
    echo "Error: --retag requires a TTY (safety confirmation cannot be skipped)." >&2
    exit 1
  fi

  LOCAL_TAG_EXISTS=false
  REMOTE_TAG_EXISTS=false
  GH_RELEASE_EXISTS=false

  if git tag -l "${VTAG}" | grep -q .; then
    LOCAL_TAG_EXISTS=true
  fi
  if git ls-remote --tags origin "refs/tags/${VTAG}" 2>/dev/null | grep -q .; then
    REMOTE_TAG_EXISTS=true
  fi
  if command -v gh &>/dev/null; then
    if gh release view "${VTAG}" &>/dev/null 2>&1; then
      GH_RELEASE_EXISTS=true
    fi
  fi

  echo ""
  echo "Retag mode — the following will be deleted and recreated:"
  echo ""
  if [[ "${LOCAL_TAG_EXISTS}" == "true" ]]; then
    echo "  • Local tag      ${VTAG}  → will be deleted"
  else
    echo "  • Local tag      ${VTAG}  (not found — nothing to delete)"
  fi
  if [[ "${REMOTE_TAG_EXISTS}" == "true" ]]; then
    echo "  • Remote tag     ${VTAG}  → will be deleted"
  else
    echo "  • Remote tag     ${VTAG}  (not found — nothing to delete)"
  fi
  if [[ "${GH_RELEASE_EXISTS}" == "true" ]]; then
    echo "  • GitHub release ${VTAG}  → will be deleted"
  elif command -v gh &>/dev/null; then
    echo "  • GitHub release ${VTAG}  (not found — nothing to delete)"
  else
    echo "  • GitHub release           (gh CLI not available — skipped)"
  fi
  echo ""

  if [[ "${DO_DRYRUN}" == "true" ]]; then
    echo "[dry-run] would delete as shown above — skipping confirmation and deletions."
    echo ""
  else
    # Safety: require typing the exact tag name
    read -rp "Type '${VTAG}' to confirm deletion: " RETAG_CONFIRM
    if [[ "${RETAG_CONFIRM}" != "${VTAG}" ]]; then
      echo "Aborted — confirmation did not match." >&2
      exit 1
    fi
    echo ""

    if [[ "${LOCAL_TAG_EXISTS}" == "true" ]]; then
      git tag -d "${VTAG}"
      echo "Deleted local tag ${VTAG}."
    fi
    if [[ "${REMOTE_TAG_EXISTS}" == "true" ]]; then
      git push origin --delete "${VTAG}"
      echo "Deleted remote tag ${VTAG}."
    fi
    if [[ "${GH_RELEASE_EXISTS}" == "true" ]]; then
      gh release delete "${VTAG}" --yes
      echo "Deleted GitHub release ${VTAG}."
    fi
    echo ""
  fi
fi

if [[ "${DO_DRYRUN}" == "true" ]]; then
  echo "[dry-run] would stamp version: semver=${SEMVER}  spfx=${SPFX_VER}"
else
  echo "Stamping version: semver=${SEMVER}  spfx=${SPFX_VER}"
fi

# --------------------------------------------------------------------------- #
# Stamp files
# --------------------------------------------------------------------------- #

maybe npm version "$SEMVER" --no-git-tag-version --allow-same-version

# Stamp azure-function/package.json if it exists
if [[ -f "azure-function/package.json" ]]; then
  maybe npm version "$SEMVER" --no-git-tag-version --allow-same-version --prefix azure-function
  if [[ "${DO_DRYRUN}" == "false" ]]; then
    echo "azure-function/package.json → ${SEMVER}"
  fi
fi

if [[ "${DO_DRYRUN}" == "true" ]]; then
  echo "[dry-run] would update config/package-solution.json → ${SPFX_VER}"
else
  SPFX_VER="$SPFX_VER" node -e "
const fs  = require('fs');
const ver = process.env.SPFX_VER;
const p   = 'config/package-solution.json';
const obj = JSON.parse(fs.readFileSync(p, 'utf8'));
obj.solution.version = ver;
obj.solution.features.forEach(f => { f.version = ver; });
fs.writeFileSync(p, JSON.stringify(obj, null, 2) + '\n');
console.log('config/package-solution.json → ' + ver);
"
fi

# Compile azuredeploy.json from main.bicep so it is part of the release commit.
# The tag must point to a commit that already contains the correct ARM template —
# otherwise the Deploy-to-Azure button would serve a stale version until CI commits back.
BICEP_COMPILED=false
if command -v az &>/dev/null && [[ -f "azure-function/infra/main.bicep" ]]; then
  if [[ "${DO_DRYRUN}" == "true" ]]; then
    echo "[dry-run] would compile azure-function/infra/main.bicep → azuredeploy.json"
    BICEP_COMPILED=true
  else
    echo "Compiling azure-function/infra/main.bicep → azuredeploy.json via az bicep"
    az bicep build --file azure-function/infra/main.bicep --outfile azure-function/infra/azuredeploy.json
    BICEP_COMPILED=true
  fi
else
  echo "⚠ az CLI not found (or main.bicep missing) — azuredeploy.json will be regenerated by CI if needed"
fi

# --------------------------------------------------------------------------- #
# Build
# --------------------------------------------------------------------------- #

if [[ "${DO_COMMIT}" == "true" && "${DO_BUILD}" == "true" ]]; then
  echo ""
  echo "Building project to verify it compiles cleanly before tagging..."
  if [[ "${DO_DRYRUN}" == "true" ]]; then
    echo "[dry-run] would run: ./scripts/build.sh"
  else
    ./scripts/build.sh
    echo ""
    echo "Build succeeded."
  fi
elif [[ "${DO_COMMIT}" == "true" && "${DO_BUILD}" == "false" ]]; then
  echo ""
  echo "Skipping build (--skip-build)."
fi

# --------------------------------------------------------------------------- #
# Commit and tag
# --------------------------------------------------------------------------- #

if [[ "${DO_COMMIT}" == "true" ]]; then
  maybe git add package.json package-lock.json config/package-solution.json
  if [[ -f "azure-function/package.json" ]]; then
    if [[ "${DO_DRYRUN}" == "true" ]]; then
      echo "[dry-run] git add azure-function/package.json azure-function/package-lock.json"
    else
      git add azure-function/package.json azure-function/package-lock.json 2>/dev/null || true
    fi
  fi
  if [[ "$BICEP_COMPILED" == "true" ]]; then
    maybe git add azure-function/infra/azuredeploy.json
  fi
  maybe git commit -m "chore: release ${VTAG}"
  maybe git tag -a "${VTAG}" -m "Release ${VTAG}"
  echo ""
  if [[ "${DO_DRYRUN}" == "true" ]]; then
    echo "[dry-run] would create commit and tag ${VTAG}."
  else
    echo "Created commit and tag ${VTAG}."
  fi
  if [[ "${DO_PUSH}" == "true" ]]; then
    if [[ "${DO_DRYRUN}" == "true" ]]; then
      echo "[dry-run] would push branch and tags to origin."
    else
      echo "Pushing to origin..."
      git push
      git push --tags
      echo "Pushed. The release workflow will start automatically."
    fi
  else
    if [[ "${DO_DRYRUN}" == "false" ]]; then
      echo "Push with:  git push && git push --tags"
    fi
  fi
fi
