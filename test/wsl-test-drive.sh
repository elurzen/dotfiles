#!/usr/bin/env bash
# Throwaway Arch WSL instance to test-drive bootstrap.sh end to end, then discard.
#
# Installs the OFFICIAL Arch WSL image under an ISOLATED name 'arch-testdrive' via
# `wsl --install` (complete, WSL-ready image - no rootfs download or repack). It
# NEVER touches your real distro: separate name, separate filesystem/vhdx in its
# own --location dir. The disk image is freed when you --unregister.
#
# Usage (run from inside WSL):
#   test/wsl-test-drive.sh                 # dry-run in the sandbox, work profile (default)
#   test/wsl-test-drive.sh --wet           # full real install in the sandbox
#   test/wsl-test-drive.sh --wet personal  # wet run, personal profile
set -euo pipefail

INSTANCE="arch-testdrive"      # distinct throwaway name; we only ever touch this
BRANCH="feat/arch-bootstrap"   # the branch under test (must be pushed to origin)
MODE="--dry-run"               # default: safe plan-only run inside the sandbox
PROFILE="work"
for a in "$@"; do
  case "$a" in
    --wet)              MODE="" ;;
    base|work|personal) PROFILE="$a" ;;
    *) echo "unknown arg: $a (use --wet and/or base|work|personal)"; exit 2 ;;
  esac
done

# Windows binaries aren't on PATH here (appendWindowsPath=false), so resolve them.
WSL="$(command -v wsl.exe || echo /mnt/c/Windows/System32/wsl.exe)"
CMD="$(command -v cmd.exe || echo /mnt/c/Windows/System32/cmd.exe)"
[[ -x "$WSL" ]] || { echo "wsl.exe not found at $WSL"; exit 1; }

win_tmp="$(wslpath "$("$CMD" /c 'echo %TEMP%' 2>/dev/null | tr -d '\r')")"
location="$win_tmp/$INSTANCE"

# Safety: only ever act on the throwaway name. If a stale one exists, replace it.
if "$WSL" -l -q 2>/dev/null | tr -d '\0\r' | grep -qx "$INSTANCE"; then
  echo "==> '$INSTANCE' exists from a prior run; unregistering the old throwaway."
  "$WSL" --unregister "$INSTANCE"
fi

# 1. Install the official Arch image under the throwaway name (no OOBE; isolated dir).
echo "==> Installing the official Arch image as '$INSTANCE' (no launch)"
"$WSL" --install archlinux --name "$INSTANCE" --location "$(wslpath -w "$location")" --no-launch

# 2. Inside the sandbox (as root): ensure prereqs (incl. sudo, which bootstrap calls),
#    rewrite git SSH->HTTPS so bootstrap's public nvim clone needs no key, clone the
#    BRANCH, then run bootstrap.
echo "==> Provisioning via provision.sh inside '$INSTANCE' (profile=$PROFILE, mode=${MODE:-WET})"
# Clone as root, then hand off to the REAL provision.sh (creates vanzen, sets default user
# via wsl --manage interop, runs bootstrap as vanzen). PROVISION_PASSWORD => unattended.
"$WSL" -d "$INSTANCE" -u root -- bash -euc "
  pacman-key --init >/dev/null 2>&1 || true
  pacman-key --populate archlinux >/dev/null 2>&1 || true
  pacman -Sy --noconfirm --needed git
  git clone --branch $BRANCH --single-branch https://github.com/elurzen/dotfiles.git /root/dotfiles
  cd /root/dotfiles && PROVISION_PASSWORD=test DOTFILES_PROFILE=$PROFILE ./provision.sh $MODE
"

# provision.sh wrote wsl.conf; set the default user authoritatively from the host
# (reliable, and avoids the self-restart that killed provision when done from inside),
# then terminate so the next launch logs in fresh as vanzen.
"$WSL" --manage "$INSTANCE" --set-default-user vanzen >/dev/null 2>&1 || true
"$WSL" --terminate "$INSTANCE" >/dev/null 2>&1 || true

echo
echo "==> Explore it:   wsl -d $INSTANCE       (logs in as vanzen; root pw 'root', vanzen pw 'vanzen')"
echo "==> Destroy it:   wsl --unregister $INSTANCE   (frees the disk image)"
