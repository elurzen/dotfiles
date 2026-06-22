#!/usr/bin/env bash
# Throwaway Arch WSL instance to test-drive bootstrap.sh end to end, then discard.
#
# Creates an ISOLATED distro named 'arch-testdrive' from the official Arch rootfs.
# It NEVER touches your real distro: separate name, separate filesystem/vhdx. The
# rootfs tarball + the instance's disk image live on the Windows filesystem (disk
# space only); the disk image is freed when you --unregister.
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

command -v wsl.exe >/dev/null || { echo "wsl.exe not found - run this from inside WSL."; exit 1; }

# Windows-side scratch dir (rootfs + the instance vhdx live here, NOT in any distro).
win_tmp="$(wslpath "$(cmd.exe /c 'echo %TEMP%' 2>/dev/null | tr -d '\r')")"
scratch="$win_tmp/arch-testdrive"
rootfs="$win_tmp/arch-rootfs.tar"
mkdir -p "$scratch"

# Safety: only ever act on the throwaway name. If a stale one exists, replace it.
if wsl.exe -l -q 2>/dev/null | tr -d '\r' | grep -qx "$INSTANCE"; then
  echo "==> '$INSTANCE' exists from a prior run; unregistering the old throwaway."
  wsl.exe --unregister "$INSTANCE"
fi

# 1. Official Arch rootfs via the bootstrap tarball (cached; no docker needed).
if [[ ! -f "$rootfs" ]]; then
  echo "==> Fetching official Arch bootstrap rootfs (one-time, cached at $rootfs)"
  bs="$win_tmp/archlinux-bootstrap.tar.zst"
  curl -fSL -o "$bs" "https://geo.mirror.pkgbuild.com/iso/latest/archlinux-bootstrap-x86_64.tar.zst"
  ex="$(mktemp -d)"
  bsdtar -xpf "$bs" -C "$ex"                    # extracts to $ex/root.x86_64/
  bsdtar -cpf "$rootfs" -C "$ex/root.x86_64" .  # repack so files sit at tar root (wsl --import wants that)
  rm -rf "$ex"
fi

# 2. Import the isolated throwaway instance.
echo "==> Importing throwaway '$INSTANCE'"
wsl.exe --import "$INSTANCE" "$(wslpath -w "$scratch")" "$(wslpath -w "$rootfs")"

# 3. Inside the sandbox (runs as root): mirror + keyring, prereqs (incl. sudo, which
#    bootstrap.sh calls), clone the BRANCH over HTTPS, then run bootstrap.
echo "==> Bootstrapping inside '$INSTANCE' (profile=$PROFILE, mode=${MODE:-WET})"
wsl.exe -d "$INSTANCE" -- bash -euc "
  echo 'Server = https://geo.mirror.pkgbuild.com/\$repo/os/\$arch' > /etc/pacman.d/mirrorlist
  pacman-key --init && pacman-key --populate archlinux
  pacman -Sy --noconfirm --needed git openssh sudo
  git clone --branch '$BRANCH' --single-branch https://github.com/elurzen/dotfiles.git /root/dotfiles
  cd /root/dotfiles && DOTFILES_PROFILE='$PROFILE' ./bootstrap.sh $MODE
"

echo
echo "==> Explore it:   wsl.exe -d $INSTANCE"
echo "==> Destroy it:   wsl.exe --unregister $INSTANCE   (frees the disk image)"
