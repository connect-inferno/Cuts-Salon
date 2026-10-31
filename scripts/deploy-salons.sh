#!/usr/bin/env bash
# Deploys Firestore rules/indexes or Cloud Functions to every salon, in a
# safe order, with one command - instead of typing the per-salon commands
# from CLAUDE.md by hand and hoping none was missed.
#
#   scripts/deploy-salons.sh list
#   scripts/deploy-salons.sh rules     [salonId...] [--dry-run] [--skip-tests]
#   scripts/deploy-salons.sh functions [salonId...] [--dry-run] [--skip-tests]
#
# - Salons come from mobile/lib/firebase/salon_directory.dart (salonId: '...'),
#   so a new salon is picked up the moment it's added there.
# - WhatsApp salons are the ones with a mobile/functions/.env.<salonId> file;
#   functions never go anywhere else (a salon without the WHATSAPP_TOKEN
#   secret can't take them).
# - The test salon (any id containing "test") always goes first. Before the
#   first real salon the script stops and asks you to type "yes".
# - Stops at the first failed deploy, so salons never end up half-updated
#   without you knowing which.
# - Runs the matching tests first (rules emulator / functions unit tests)
#   unless --skip-tests.
# - Always `firebase deploy --only ...`, never a bare deploy (see CLAUDE.md).
#
# Needs: the Firebase CLI, logged in (`firebase login`) with access to every
# salon project; Java 21 for the rules tests.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE="$ROOT/mobile"
DIRECTORY="$MOBILE/lib/firebase/salon_directory.dart"

DRY_RUN=0
SKIP_TESTS=0
CMD="${1:-}"
[ $# -gt 0 ] && shift
ARGS=()
for a in "$@"; do
  case "$a" in
    --dry-run) DRY_RUN=1 ;;
    --skip-tests) SKIP_TESTS=1 ;;
    -h|--help) CMD=help ;;
    *) ARGS+=("$a") ;;
  esac
done

say() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# Every salonId in the directory, test salons first.
all_salons() {
  [ -f "$DIRECTORY" ] || die "can't find $DIRECTORY"
  local ids
  ids=$(grep -oE "salonId: *'[^']+'" "$DIRECTORY" | sed -E "s/salonId: *'([^']+)'/\1/")
  [ -n "$ids" ] || die "no salonId entries found in $DIRECTORY"
  { printf '%s\n' "$ids" | grep -i test || true; printf '%s\n' "$ids" | grep -vi test || true; }
}

# Salons with WhatsApp set up (have a functions/.env.<id>), test first.
whatsapp_salons() {
  local id
  all_salons | while read -r id; do
    # if/fi, not &&: a false test on the last salon would otherwise be the
    # function's exit status and stop the script under set -e.
    if [ -f "$MOBILE/functions/.env.$id" ]; then printf '%s\n' "$id"; fi
  done
}

is_test() { case "$1" in *test*) return 0 ;; *) return 1 ;; esac; }

run() {
  say "  \$ $*"
  if [ "$DRY_RUN" -eq 1 ]; then return 0; fi
  "$@"
}

# Ask once, right before the first real (non-test) salon.
CONFIRMED=0
confirm_real() {
  [ "$CONFIRMED" -eq 1 ] && return 0
  [ "$DRY_RUN" -eq 1 ] && { CONFIRMED=1; return 0; }
  say ""
  say "Next: REAL salons. Check the test salon first if you haven't."
  read -r -p "Type yes to continue: " answer
  [ "$answer" = "yes" ] || die "stopped before any real salon was touched"
  CONFIRMED=1
}

deploy_each() { # <what> <firebase --only targets> <salon ids...>
  local what="$1" only="$2"; shift 2
  local id done_list=()
  for id in "$@"; do
    is_test "$id" || confirm_real
    say ""
    say "== $what -> $id"
    (cd "$MOBILE" && run firebase deploy --only "$only" --project "$id" --non-interactive) \
      || die "$what failed on $id. Already done: ${done_list[*]:-none}. Not done: the rest."
    done_list+=("$id")
  done
  say ""
  if [ "$DRY_RUN" -eq 1 ]; then
    say "Dry run - nothing deployed. Would deploy $what to ${done_list[*]}"
  else
    say "Done: $what deployed to ${done_list[*]}"
  fi
}

case "$CMD" in
  list)
    say "Salons (deploy order):"
    all_salons | sed 's/^/  /'
    say "WhatsApp salons (get functions):"
    whatsapp_salons | sed 's/^/  /'
    ;;

  rules)
    mapfile -t known < <(all_salons)
    if [ ${#ARGS[@]} -gt 0 ]; then
      # Just these salons - e.g. the test salon alone while trying a change.
      for id in "${ARGS[@]}"; do
        printf '%s\n' "${known[@]}" | grep -qx "$id" || die "$id is not in salon_directory.dart"
      done
      salons=("${ARGS[@]}")
    else
      salons=("${known[@]}")
    fi
    say "Firestore rules + indexes -> ${salons[*]}"
    if [ "$SKIP_TESTS" -eq 0 ]; then
      say ""
      say "== rules tests (emulator, demo project)"
      (cd "$MOBILE/rules-test" && run npm test) || die "rules tests failed - nothing deployed"
    fi
    deploy_each "rules + indexes" "firestore:rules,firestore:indexes" "${salons[@]}"
    ;;

  functions)
    mapfile -t wa < <(whatsapp_salons)
    if [ ${#ARGS[@]} -gt 0 ]; then
      for id in "${ARGS[@]}"; do
        printf '%s\n' "${wa[@]}" | grep -qx "$id" \
          || die "$id has no functions/.env.$id - not a WhatsApp salon, refusing"
      done
      salons=("${ARGS[@]}")
    else
      salons=("${wa[@]}")
    fi
    [ ${#salons[@]} -gt 0 ] || die "no WhatsApp salons found"
    say "Cloud Functions -> ${salons[*]}"
    if [ "$SKIP_TESTS" -eq 0 ]; then
      say ""
      say "== functions tests"
      (cd "$MOBILE/functions" && run npm test) || die "functions tests failed - nothing deployed"
    fi
    deploy_each "functions" "functions" "${salons[@]}"
    ;;

  help|"")
    sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
    ;;

  *)
    die "unknown command '$CMD' (try: list, rules, functions)"
    ;;
esac
