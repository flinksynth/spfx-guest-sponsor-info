#!/usr/bin/env bash
# Copyright 2026 Workoho GmbH <https://workoho.com>
# Author: Julian Pawlowski <https://github.com/jpawlowski>
# Licensed under PolyForm Shield License 1.0.0 <https://polyformproject.org/licenses/shield/1.0.0>
#
# Terminal output helpers: ANSI colour variables and callout box functions.
#
# Source this file after setting the working directory:
#   # shellcheck source=scripts/colors.sh
#   source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
#
# Colours are disabled automatically when:
#   - stdout is not a TTY (piped or redirected)
#   - $CI is non-empty (GitHub Actions, Azure DevOps, etc.)
#   - $NO_COLOR is set (https://no-color.org)
#   - $TERM is "dumb"
#
# Available variables (all exported so sub-shells can inherit them):
#   C_RED  C_GRN  C_YLW  C_CYN  C_BLD  C_DIM  C_RST
#
# Available box functions (draw a coloured callout around text):
#   hint       "line1" "line2" …   # cyan   — developer tips, good-to-know
#   next_steps "line1" "line2" …   # green  — what to do after the script finishes
#   important  "line1" "line2" …   # yellow — critical action items

if [[ -t 1 && "${CI:-}" == "" && "${NO_COLOR:-}" == "" && "${TERM:-}" != "dumb" ]]; then
  C_RED=$'\033[0;31m'
  C_GRN=$'\033[0;32m'
  C_YLW=$'\033[1;33m'
  C_CYN=$'\033[0;36m'
  C_BLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_RST=$'\033[0m'
else
  C_RED=''
  C_GRN=''
  C_YLW=''
  C_CYN=''
  C_BLD=''
  C_DIM=''
  C_RST=''
fi

export C_RED C_GRN C_YLW C_CYN C_BLD C_DIM C_RST

# ── Callout box helpers ──────────────────────────────────────────────────────
# Draw a coloured box (open right side) around one or more lines of text.
# Pass each line as a separate argument; pass "" for a blank separator line.
#
# Usage:
#   hint "Edit .env and set SPFX_SERVE_TENANT_DOMAIN" \
#        "${C_DIM}(or export it on your host OS)${C_RST}"
#
#   next_steps "${C_BLD}./scripts/dev-webpart.sh${C_RST}  # SPFx dev server" \
#              "${C_BLD}./scripts/dev-function.sh${C_RST} # Azure Function"
#
#   important "Edit azure-function/local.settings.json" \
#             "" \
#             "Required:" \
#             "  TENANT_ID — your Entra tenant ID"

# Internal: renders the box.  $1 = colour, $2 = title, $3… = body lines.
_box() {
  local color="$1" title="$2"
  shift 2

  # 60 box-drawing dashes — sliced to fit the title header and footer.
  local rule="────────────────────────────────────────────────────────────"
  local tlen=${#title}
  local dashes=$((56 - tlen))
  if ((dashes < 4)); then dashes=4; fi

  echo ""
  echo "  ${color}╭─ ${C_BLD}${title}${C_RST}${color} ${rule:0:dashes}${C_RST}"
  echo "  ${color}│${C_RST}"
  for line in "$@"; do
    if [[ -z "$line" ]]; then
      echo "  ${color}│${C_RST}"
    else
      echo "  ${color}│${C_RST}  ${line}"
    fi
  done
  echo "  ${color}│${C_RST}"
  echo "  ${color}╰${rule:0:59}${C_RST}"
  echo ""
}

hint() { _box "${C_CYN}" "HINT" "$@"; }
next_steps() { _box "${C_GRN}" "NEXT STEPS" "$@"; }
important() { _box "${C_YLW}" "IMPORTANT" "$@"; }
