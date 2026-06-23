# `pi` — install a pacman package and record it in a dotfiles layer list,
# plus `pi_sync` to refresh the base list. Source from .zshrc.
: "${DOTFILES_DIR:=$HOME/dotfiles}"

# Map a layer token (b/p/w/d or full name) to its list file path. Errors on unknown.
_pi_layer_file() {
  case "$1" in
    b|base)     echo "$DOTFILES_DIR/pkglist.txt" ;;
    w|work)     echo "$DOTFILES_DIR/pkglist-work.txt" ;;
    p|personal) echo "$DOTFILES_DIR/pkglist-personal.txt" ;;
    d|desktop)  echo "$DOTFILES_DIR/pkglist-desktop.txt" ;;
    *) return 1 ;;
  esac
}

# Append a package to a list file, then sort -u in place (sorted + deduped).
_pi_record() {
  local pkg="$1" file="$2"
  printf '%s\n' "$pkg" >> "$file"
  sort -u -o "$file" "$file"
}

# pi <pkg>... [b|p|w|d] — install via pacman --needed and record into the layer.
# If the last arg is a known layer token it selects the layer; otherwise prompt.
pi() {
  [[ $# -ge 1 ]] || { echo "usage: pi <pkg>... [b|p|w|d]"; return 2; }
  local args=("$@") layer="" pkgs=() file
  local last="${args[-1]}"
  if [[ ${#args[@]} -ge 2 ]] && _pi_layer_file "$last" >/dev/null 2>&1; then
    layer="$last"; pkgs=("${args[@]:0:$(( ${#args[@]} - 1 ))}")
  else
    pkgs=("${args[@]}")
  fi
  if [[ -z "$layer" ]]; then
    local ans
    read -r -p "Which layer? [b]ase / [p]ersonal / [w]ork / [d]esktop: " ans
    layer="$ans"
  fi
  file="$(_pi_layer_file "$layer")" || { echo "pi: unknown layer '$layer'"; return 2; }
  sudo pacman -S --needed "${pkgs[@]}" || return 1
  local p; for p in "${pkgs[@]}"; do _pi_record "$p" "$file"; done
  echo "pi: recorded ${pkgs[*]} -> ${file##*/}"
}

# pi_sync — rebuild pkglist.txt from explicitly-installed pacman pkgs, minus the
# other layer lists and AUR/foreign packages (which a fresh base install can't get).
pi_sync() {
  cd "$DOTFILES_DIR" || return 1
  comm -23 <(pacman -Qqe | sort -u) \
    <({ cat pkglist-work.txt pkglist-personal.txt pkglist-desktop.txt pkglist-wsl.txt 2>/dev/null; pacman -Qqem; } | sort -u) \
    > pkglist.txt
  echo "pi_sync: refreshed pkglist.txt ($(wc -l < pkglist.txt) packages)"
}
