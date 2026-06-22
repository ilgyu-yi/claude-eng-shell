# shellcheck shell=bash
# helpers/blast_radius.sh — classify a decision as high-asymmetry (a wrong
# *approve* is irreversible or corrupts shared history) for the §4.11 reviewer
# tier. This is the mechanical SSOT for the CLOSED enumerated decision set; the
# N=3/majority=2 independent fan-out + tally is the invoking skill's judgment,
# not this helper's. Pure shell, no external calls — safe under set -uo pipefail.
# SPEC §4.11.
#
# Public:
#   is_high_asymmetry <decision-kind> — rc 0 iff <kind> is in the closed set
#     {merge-security-surface, force-push, directive-completion, irreversible-adr};
#     rc 1 for any other (off-list) kind. The closed set is the AC1 contract —
#     smoke §114 pins both the in-set rc 0 and an off-list rc 1 (falsifiability).

is_high_asymmetry() {
  case "${1:-}" in
    merge-security-surface|force-push|directive-completion|irreversible-adr) return 0 ;;
    *) return 1 ;;
  esac
}
