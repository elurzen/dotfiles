# Pure helpers for bootstrap. No side effects; safe to source anywhere.
# Tests override the dotfiles location via DOTFILES_DIR.
: "${DOTFILES_DIR:=$HOME/dotfiles}"

# Echo "wsl" on WSL, else "desktop".
detect_machine() {
  if grep -qi microsoft /proc/version 2>/dev/null; then echo wsl; else echo desktop; fi
}

# Echo the stow packages for a machine type.
stow_set() {
  case "$1" in
    wsl)     echo "btop git starship tmux zsh" ;;
    desktop) echo "alacritty btop git hypr mako ncspot starship tmux vesktop waybar zsh" ;;
    *) return 1 ;;
  esac
}

# Echo the pkglist files to install, in order, skipping missing/empty ones.
# Usage: pkglist_files <machine> <role>
pkglist_files() {
  local machine="$1" role="$2" f out=()
  for f in "pkglist.txt" "pkglist-${machine}.txt" ${role:+"pkglist-${role}.txt"}; do
    [[ -s "$DOTFILES_DIR/$f" ]] && out+=("$f")
  done
  echo "${out[*]}"
}
