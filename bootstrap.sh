#!/usr/bin/env bash
#
# bootstrap.sh — bring a fresh Arch (WSL) box back to baseline.
#
# Prereq: git + openssh installed and this repo cloned to ~/dotfiles.
#
# Reproducibility model
# ---------------------
#   pacman layer    : pkglist*.txt — ALWAYS recoverable via `pacman -Qqe`. Declarative.
#   non-pacman layer: everything below the pacman step. `pacman -Qe` does NOT
#                     capture these (npm globals, curl|bash installs, manual
#                     edits, OAuth tokens), so they must be written down HERE
#                     or they are lost. Append to this file as you add them.
#
# Profiles (base + opt-in layers)
# -------------------------------
#   base     : pkglist.txt          — every machine.
#   work     : pkglist-work.txt + kubelogin — htxlabs Azure/k8s tooling.
#   personal : pkglist-personal.txt — personal-only machines.
# Base always installs. Pick extra layers with the DOTFILES_PROFILE env var
# (comma-separated) or a per-machine marker file at ~/.config/dotfiles/profile.
# Default is base only.
#   DOTFILES_PROFILE=work ./bootstrap.sh
#   echo work > ~/.config/dotfiles/profile      # persist the choice on this box
#
# Refresh the base list after any pacman install — subtract the profile lists so
# work/personal packages never leak into base:
#   comm -23 <(pacman -Qqe | sort) <(sort pkglist-work.txt pkglist-personal.txt 2>/dev/null) > pkglist.txt
#
set -euo pipefail
cd "$(dirname "$0")"

# --- profile resolution ---------------------------------------------------
PROFILE="${DOTFILES_PROFILE:-$(cat "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/profile" 2>/dev/null || echo base)}"
PROFILE="${PROFILE// /}"   # tolerate stray spaces in the marker/env value
echo "==> Profile: $PROFILE"
has_profile() { [[ ",$PROFILE," == *",$1,"* ]]; }

# --- pacman layer ---------------------------------------------------------
# Full sync + upgrade alongside the install to avoid Arch partial-upgrade breakage.
echo "==> Installing base pacman packages from pkglist.txt"
sudo pacman -Syu --needed - < pkglist.txt

if has_profile work && [[ -s pkglist-work.txt ]]; then
  echo "==> Installing work pacman packages from pkglist-work.txt"
  sudo pacman -S --needed - < pkglist-work.txt
fi
if has_profile personal && [[ -s pkglist-personal.txt ]]; then
  echo "==> Installing personal pacman packages from pkglist-personal.txt"
  sudo pacman -S --needed - < pkglist-personal.txt
fi

# --- dotfiles (GNU stow) --------------------------------------------------
# Each top-level dir is a stow package mirroring $HOME.
# TODO(evan): confirm the WSL stow set. Desktop/Wayland configs
# (hypr mako waybar vesktop ncspot alacritty) are skipped here — add them on a
# desktop machine.
STOW_PKGS=(btop git starship tmux zsh)
echo "==> Stowing: ${STOW_PKGS[*]}"
stow -v "${STOW_PKGS[@]}"

# --- non-pacman layer: base (append as you go) ----------------------------
#
# pay-respects — Rust "thefuck" replacement (type `f` to correct the last command).
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

# --- non-pacman layer: work (htxlabs) -------------------------------------
if has_profile work; then
  # kubelogin — AKS AAD exec-credential plugin for kubectl/k9s. AUR-only, so
  # pinned as a static binary into ~/.local/bin (mirrors pay-respects), verified
  # against its published sha256. To bump: change KUBELOGIN_VER and re-run.
  KUBELOGIN_VER=0.2.18
  if ! command -v kubelogin >/dev/null 2>&1; then
    echo "==> Installing kubelogin ${KUBELOGIN_VER} -> ~/.local/bin"
    kl_base="https://github.com/Azure/kubelogin/releases/download/v${KUBELOGIN_VER}"
    kl_tmp="$(mktemp -d)"
    curl -fsSL --max-time 120 -o "$kl_tmp/kubelogin.zip"        "$kl_base/kubelogin-linux-amd64.zip"
    curl -fsSL --max-time 60  -o "$kl_tmp/kubelogin.zip.sha256" "$kl_base/kubelogin-linux-amd64.zip.sha256"
    echo "$(awk '{print $1}' "$kl_tmp/kubelogin.zip.sha256")  $kl_tmp/kubelogin.zip" | sha256sum -c -
    # bsdtar (libarchive, always present on Arch) extracts the zip — no unzip dep.
    bsdtar -xf "$kl_tmp/kubelogin.zip" -C "$kl_tmp" bin/linux_amd64/kubelogin
    mkdir -p "$HOME/.local/bin"
    install -m 0755 "$kl_tmp/bin/linux_amd64/kubelogin" "$HOME/.local/bin/kubelogin"
    rm -rf "$kl_tmp"
  else
    echo "==> kubelogin already installed, skipping"
  fi
  # The kubeconfig itself is a per-machine secret and lives in its own git repo,
  # NOT here. Seed it once:  cp /mnt/c/Users/<you>/.kube/config ~/.kube/config
  # (commercial AKS clusters need the corp VPN; gov uses its own.)
fi

echo
echo "==> Done. Manual step left: in Claude Code run '/mcp' to auth slack + figma."
