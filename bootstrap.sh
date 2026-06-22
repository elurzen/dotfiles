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
# Refresh the base list after any pacman install. Subtract the profile layers (so
# work/personal packages never leak into base) AND foreign/AUR packages (pacman -S
# can't install those from the official repos - they'd break a fresh base install).
# Use cat, not sort, for the layer files: cat tolerates a missing personal list,
# whereas `sort a b` fails on it and silently subtracts nothing (leaking everything):
#   comm -23 <(pacman -Qqe | sort -u) \
#     <({ cat pkglist-work.txt pkglist-personal.txt 2>/dev/null; pacman -Qqem; } | sort -u) > pkglist.txt
#
set -euo pipefail
cd "$(dirname "$0")"

# --- profile resolution ---------------------------------------------------
PROFILE="${DOTFILES_PROFILE:-$(cat "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/profile" 2>/dev/null || echo base)}"
PROFILE="${PROFILE// /}"   # tolerate stray spaces in the marker/env value
echo "==> Profile: $PROFILE"
has_profile() { [[ ",$PROFILE," == *",$1,"* ]]; }

# --- shared helpers + machine detection -----------------------------------
source "$(dirname "$0")/lib/profile.sh"
MACHINE="$(detect_machine)"
echo "==> Machine: $MACHINE"

# --- pacman layer ---------------------------------------------------------
# Compose base + machine + role lists; full -Syu on the first (base) install to
# avoid Arch partial-upgrade breakage, --needed installs for the rest.
ROLE=""
has_profile work && ROLE=work
has_profile personal && ROLE=personal
read -r -a _lists <<< "$(pkglist_files "$MACHINE" "$ROLE")"
echo "==> Installing pacman layers: ${_lists[*]}"
first=1
for _l in "${_lists[@]}"; do
  if [[ $first -eq 1 ]]; then
    sudo pacman -Syu --needed - < "$_l"; first=0
  else
    sudo pacman -S --needed - < "$_l"
  fi
done

# --- dotfiles (GNU stow) --------------------------------------------------
# Each top-level dir is a stow package mirroring $HOME. The set is machine-aware
# (see lib/profile.sh): wsl gets the core set, desktop adds the Wayland configs.
read -r -a STOW_PKGS <<< "$(stow_set "$MACHINE")"
echo "==> Stowing ($MACHINE): ${STOW_PKGS[*]}"
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
# Neovim config (SLVim, htx-labs branch = the lightweight WSL/work editing setup).
#   It lives in its own repo (github.com/elurzen/SLVim), so clone it into place
#   rather than stow it. Idempotent: skip if ~/.config/nvim already exists.
#   Depends on unzip (pkglist.txt) so mason can extract stylua/terraform-ls.
NVIM_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
if [ ! -d "$NVIM_CONFIG" ]; then
  echo "==> Cloning nvim config (SLVim htx-labs) -> $NVIM_CONFIG"
  git clone --branch htx-labs --single-branch git@github.com:elurzen/SLVim.git "$NVIM_CONFIG"
  echo "    First nvim launch installs plugins + LSP servers (lazy.nvim + mason)."
else
  echo "==> nvim config already present at $NVIM_CONFIG, skipping"
fi
#
# Claude Code node-based MCP servers (context7, playwright):
#   No extra step — they launch via `npx`, which nodejs+npm (above) provide.
#   npx fetches the server packages on demand; no global npm install needed.
#
# Claude Code OAuth MCP servers (slack, figma) — NOT scriptable (interactive login):
#   In Claude Code run:  /mcp   then authenticate each.

# tmux autostart on interactive WSL login (optional, prompted).
# WSL-only ergonomic. Appended to ~/.zshrc.local (machine-local, not stowed) so it
# loads LAST, after the aliases there. Idempotent via the marker it writes.
if grep -qi microsoft /proc/version 2>/dev/null; then
  zlocal="$HOME/.zshrc.local"
  if [[ -f "$zlocal" ]] && grep -q '>>> tmux-autostart (bootstrap)' "$zlocal"; then
    echo "==> tmux autostart already in ~/.zshrc.local, skipping"
  else
    _ans=""
    [[ -t 0 ]] && { read -r -p "Enable tmux autostart on interactive WSL login? [Y/n] " _ans || true; }
    case "${_ans:-Y}" in
      [Nn]*) echo "==> Skipping tmux autostart (re-run bootstrap to add it later)" ;;
      *)
        echo "==> Adding tmux autostart to ~/.zshrc.local"
        cat >> "$zlocal" <<'EOF'

# >>> tmux-autostart (bootstrap) >>>
# Auto-start tmux on interactive WSL login. Attach to the 'main' session or create it.
# Guards: interactive + real TTY, not already in tmux, tmux installed, not the VS Code
# terminal - so non-TTY shells (Claude Code, scripts) and the VS Code integrated
# terminal are never grabbed. Keep this LAST: `exec` replaces the shell.
if [[ $- == *i* ]] && [[ -t 1 ]] && [[ -z $TMUX ]] && command -v tmux >/dev/null 2>&1 \
     && [[ $TERM_PROGRAM != vscode ]] && [[ -z $VSCODE_INJECTION ]]; then
  exec tmux new-session -A -s main
fi
# <<< tmux-autostart (bootstrap) <<<
EOF
        ;;
    esac
  fi
fi

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

  # git: work identity + ADO credentials (machine-local, NOT stowed).
  # The personal identity is the stowed default (~/.gitconfig -> dotfiles/git).
  # These two files layer the work identity onto repos under ~/htx/repos and supply
  # ADO credentials. Generated here (not committed) so work config stays out of the
  # personal dotfiles and the helper path uses $HOME instead of being hardcoded.
  #   Routing lives in the stowed personal ~/.gitconfig:
  #     [includeIf "gitdir:~/htx/repos/"] path = ~/.config/git/work.gitconfig
  #   PREREQ (manual, like the kubeconfig): the gpg credential store needs a gpg key
  #   + `pass` initialised, and the ADO PAT stored at pass:git/https/dev.azure.com/<org>
  #   (see the arch-wsl-bootstrap note). Written generate-if-absent so local edits win.
  mkdir -p "$HOME/.config/git"
  if [[ ! -f "$HOME/.config/git/work.gitconfig" ]]; then
    echo "==> Writing ~/.config/git/work.gitconfig (work identity + diff/merge tools)"
    cat > "$HOME/.config/git/work.gitconfig" <<'EOF'
# Work identity + diff/merge tools for this WSL box.
# Applied ONLY inside ~/htx/repos, via the includeIf at the end of ~/.gitconfig
# (the stowed personal config). Machine-local: intentionally NOT in the dotfiles repo.
[user]
	name = Evan Urzen
	email = evan@htxlabs.com
[diff]
	tool = vscode
[merge]
	tool = vscode
[difftool "vscode"]
	cmd = code --wait --diff \"$LOCAL\" \"$REMOTE\"
[mergetool "vscode"]
	cmd = code --wait \"$MERGED\"
[difftool]
	prompt = false
[mergetool]
	keepBackup = false
EOF
  else
    echo "==> ~/.config/git/work.gitconfig exists, leaving it"
  fi
  if [[ ! -f "$HOME/.config/git/config" ]]; then
    echo "==> Writing ~/.config/git/config (ADO credentials; \$HOME-based)"
    cat > "$HOME/.config/git/config" <<EOF
# Machine-local GLOBAL git config for this WSL work box. NOT in the dotfiles repo.
# Holds ADO credential config only. Kept here (global + unconditional) rather than in
# the work.gitconfig include because \`git clone\` of a new ADO repo must authenticate
# BEFORE the repo - and thus the gitdir includeIf - exists. Read at XDG scope, before
# ~/.gitconfig; harmless because these keys don't overlap with the personal identity.
[credential]
	helper =
	helper = $HOME/.local/bin/git-credential-manager
	credentialStore = gpg
[credential "https://dev.azure.com"]
	useHttpPath = false
	provider = generic
EOF
  else
    echo "==> ~/.config/git/config exists, leaving it"
  fi
fi

echo
echo "==> Done. Manual step left: in Claude Code run '/mcp' to auth slack + figma."
