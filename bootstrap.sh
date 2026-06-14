#!/usr/bin/env bash
#
# bootstrap.sh — bring a fresh Arch (WSL) box back to baseline.
#
# Prereq: git + openssh installed and this repo cloned to ~/dotfiles.
#
# Reproducibility model
# ---------------------
#   pacman layer    : pkglist.txt — ALWAYS recoverable via `pacman -Qqe`. Declarative.
#   non-pacman layer: everything below the pacman step. `pacman -Qe` does NOT
#                     capture these (npm globals, curl|bash installs, manual
#                     edits, OAuth tokens), so they must be written down HERE
#                     or they are lost. Append to this file as you add them.
#
# Refresh the package list after installing anything new with pacman:
#   pacman -Qqe > pkglist.txt
#
set -euo pipefail
cd "$(dirname "$0")"

# --- pacman layer ---------------------------------------------------------
# Full sync + upgrade alongside the install to avoid Arch partial-upgrade breakage.
echo "==> Installing pacman packages from pkglist.txt"
sudo pacman -Syu --needed - < pkglist.txt

# --- dotfiles (GNU stow) --------------------------------------------------
# Each top-level dir is a stow package mirroring $HOME.
# TODO(evan): confirm the WSL stow set. Desktop/Wayland configs
# (hypr mako waybar vesktop ncspot alacritty) are skipped here — add them on a
# desktop machine.
STOW_PKGS=(btop git starship tmux zsh)
echo "==> Stowing: ${STOW_PKGS[*]}"
stow -v "${STOW_PKGS[@]}"

# --- non-pacman layer (append as you go) ----------------------------------
#
# pay-respects — Rust "thefuck" replacement (type `fuck` to correct the last command).
#   AUR-only, so installed as a pinned static musl binary into ~/.local/bin (already on
#   PATH via .zshrc) rather than dragging in base-devel/an AUR helper for one tool.
#   To bump: change PR_VER and re-run. (.zshrc guards on the binary existing.)
PR_VER=0.8.8
if ! command -v pay-respects >/dev/null 2>&1; then
  echo "==> Installing pay-respects ${PR_VER} -> ~/.local/bin"
  pr_asset="pay-respects-${PR_VER}-x86_64-unknown-linux-musl.tar.zst"
  pr_tmp="$(mktemp -d)"
  curl -fsSL --max-time 120 -o "$pr_tmp/$pr_asset" \
    "https://github.com/iffse/pay-respects/releases/download/v${PR_VER}/${pr_asset}"
  tar --zstd -xf "$pr_tmp/$pr_asset" -C "$pr_tmp"
  mkdir -p "$HOME/.local/bin"
  install -m 0755 "$pr_tmp/pay-respects" "$HOME/.local/bin/pay-respects"
  # runtime-rules module = the larger correction ruleset (discovered via PATH)
  install -m 0755 "$pr_tmp/_pay-respects-module-100-runtime-rules" \
    "$HOME/.local/bin/_pay-respects-module-100-runtime-rules"
  rm -rf "$pr_tmp"
else
  echo "==> pay-respects already installed, skipping"
fi
#
# Claude Code node-based MCP servers (context7, playwright):
#   No extra step — they launch via `npx`, which nodejs+npm (above) provide.
#   npx fetches the server packages on demand; no global npm install needed.
#
# Claude Code OAuth MCP servers (slack, figma) — NOT scriptable (interactive login):
#   In Claude Code run:  /mcp   then authenticate each.
#
echo
echo "==> Done. Manual step left: in Claude Code run '/mcp' to auth slack + figma."
