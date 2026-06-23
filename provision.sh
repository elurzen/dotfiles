#!/usr/bin/env bash
# provision.sh - turn a BARE Arch box (run as root) into a ready 'vanzen' box.
#
# Creates the vanzen user (wheel sudo + passwords + default WSL user), then runs
# bootstrap.sh AS vanzen so all configs land in /home/vanzen. bootstrap.sh stays the
# user-level stage - run it directly if your user already exists. Any args passed here
# pass through to bootstrap.sh (e.g. ./provision.sh --dry-run).
#
# Real use on a fresh `wsl --install archlinux --no-launch` (enter the distro as root):
#   pacman -Sy --noconfirm git
#   git clone https://github.com/elurzen/dotfiles.git
#   ./dotfiles/provision.sh
# Unattended (tests): set PROVISION_PASSWORD=... to skip the interactive password prompts.
set -euo pipefail
cd "$(dirname "$0")"; REPO="$(pwd)"
USERNAME="vanzen"
PROFILE="${DOTFILES_PROFILE:-work}"

[[ $EUID -eq 0 ]] || { echo "provision.sh must be run as root on a bare box."; exit 1; }
UNATTENDED=0; [[ -n "${PROVISION_PASSWORD:-}" ]] && UNATTENDED=1

# A bare official Arch image has neither git nor sudo; provision needs both (sudo also
# creates /etc/sudoers.d, and vanzen's bootstrap run uses sudo).
echo "==> Ensuring prereqs (git, sudo)"
pacman -Sy --noconfirm --needed git sudo

echo "==> Creating user '$USERNAME' (wheel)"
id -u "$USERNAME" >/dev/null 2>&1 || useradd -m -G wheel "$USERNAME"

echo "==> Setting passwords"
if [[ $UNATTENDED -eq 1 ]]; then
  printf '%s:%s\n' "$USERNAME" "$PROVISION_PASSWORD" | chpasswd
  printf '%s:%s\n' root        "$PROVISION_PASSWORD" | chpasswd
else
  echo "  password for $USERNAME:"; passwd "$USERNAME"
  echo "  password for root:";      passwd root
fi

echo "==> Configuring wheel sudo"
if [[ $UNATTENDED -eq 1 ]]; then
  echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/10-wheel   # unattended: no sudo prompt
else
  echo "%wheel ALL=(ALL:ALL) ALL"          > /etc/sudoers.d/10-wheel   # real: password sudo
fi
chmod 0440 /etc/sudoers.d/10-wheel

echo "==> Setting '$USERNAME' as the default WSL user (applies on next distro start)"
# Only write wsl.conf here. Do NOT call `wsl --manage` from inside - it restarts this
# distro and would kill provision.sh mid-run. The host-side --manage (if needed) is the
# printed follow-up below.
printf '[user]\ndefault=%s\n' "$USERNAME" > /etc/wsl.conf

# Unattended (a throwaway has no GitHub key): clone nvim over public HTTPS. Real boxes
# keep SSH - bootstrap's guided ssh-keygen step + the GitHub pause handle that.
[[ $UNATTENDED -eq 1 ]] && git config --system url."https://github.com/".insteadOf "git@github.com:"

echo "==> Copying dotfiles to /home/$USERNAME and running bootstrap as $USERNAME"
mkdir -p "/home/$USERNAME/dotfiles"
cp -aT "$REPO" "/home/$USERNAME/dotfiles"
chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/dotfiles"
runuser -l "$USERNAME" -c "cd ~/dotfiles && DOTFILES_PROFILE='$PROFILE' ./bootstrap.sh $*"

# Match the real box: make zsh vanzen's login shell (bootstrap installs zsh).
if command -v zsh >/dev/null; then
  grep -qx /usr/bin/zsh /etc/shells || echo /usr/bin/zsh >> /etc/shells
  chsh -s /usr/bin/zsh "$USERNAME"
fi

echo
echo "==> Provisioned. Restart the distro to log in as '$USERNAME' (wsl --terminate <distro>, or reopen)."
echo "    If it still logs in as root, from Windows run: wsl --manage <distro> --set-default-user $USERNAME"
