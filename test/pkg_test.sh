#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
source ./assert.sh

tmp="$(mktemp -d)"
DOTFILES_DIR="$tmp"
source ../lib/pkg.sh

# _pi_layer_file maps both long and short layer names
assert_eq "$(_pi_layer_file b)"    "$tmp/pkglist.txt"          "b -> base list"
assert_eq "$(_pi_layer_file base)" "$tmp/pkglist.txt"          "base -> base list"
assert_eq "$(_pi_layer_file w)"    "$tmp/pkglist-work.txt"     "w -> work list"
assert_eq "$(_pi_layer_file p)"    "$tmp/pkglist-personal.txt" "p -> personal list"
assert_eq "$(_pi_layer_file d)"    "$tmp/pkglist-desktop.txt"  "d -> desktop list"
if _pi_layer_file zzz >/dev/null 2>&1; then assert_eq "ok" "fail" "unknown layer should error"; else assert_eq "ok" "ok" "unknown layer errors"; fi

# _pi_record: sorted, deduped insert
echo ripgrep > "$tmp/pkglist-work.txt"
_pi_record kubectl "$tmp/pkglist-work.txt"
_pi_record azure-cli "$tmp/pkglist-work.txt"
_pi_record kubectl "$tmp/pkglist-work.txt"   # dup -> no second entry
assert_eq "$(cat "$tmp/pkglist-work.txt")" "$(printf 'azure-cli\nkubectl\nripgrep')" "record is sorted + deduped"

rm -rf "$tmp"
finish
