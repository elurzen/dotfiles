#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
source ./assert.sh
source ../lib/profile.sh

# stow_set
assert_eq "$(stow_set wsl)" "btop git starship tmux zsh" "wsl stow set"
assert_eq "$(stow_set desktop)" "alacritty btop git hypr mako ncspot starship tmux vesktop waybar zsh" "desktop stow set"

# pkglist_files: point DOTFILES_DIR at a temp fixture
tmp="$(mktemp -d)"
echo base > "$tmp/pkglist.txt"
echo desk > "$tmp/pkglist-desktop.txt"
echo wrk  > "$tmp/pkglist-work.txt"
: > "$tmp/pkglist-personal.txt"   # empty -> must be skipped
DOTFILES_DIR="$tmp"

assert_eq "$(pkglist_files wsl work)"         "pkglist.txt pkglist-work.txt"    "wsl+work files"
assert_eq "$(pkglist_files desktop personal)" "pkglist.txt pkglist-desktop.txt" "desktop+personal skips empty personal"
assert_eq "$(pkglist_files desktop '')"       "pkglist.txt pkglist-desktop.txt" "no role -> base+machine only"
rm -rf "$tmp"

finish
