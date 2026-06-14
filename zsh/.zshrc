# History Settings
HISTFILE=~/.histfile
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY        # record timestamp of each command
setopt SHARE_HISTORY           # share history across sessions/panes live
setopt INC_APPEND_HISTORY      # append as you go, not only on shell exit
setopt HIST_IGNORE_ALL_DUPS    # drop older duplicates of a command
setopt HIST_IGNORE_SPACE       # space-prefixed commands stay out of history
setopt HIST_REDUCE_BLANKS      # trim superfluous blanks
setopt HIST_VERIFY             # show !-expansions before running them

# Shell Options
setopt autocd extendedglob nomatch notify
setopt AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT  # cd builds a dir stack (dirs -v / cd -<n>)
setopt INTERACTIVE_COMMENTS    # allow # comments on the interactive line
setopt GLOB_DOTS               # globs match dotfiles too
unsetopt beep

export EDITOR=nvim
export VISUAL=nvim
export KEYTIMEOUT=1            # snappy ESC / vi-mode switching (10ms)
export EZA_COLORS="\
di=1;38;2;200;80;60:\
ex=1;38;2;255;140;80:\
fi=38;2;180;180;180:\
ln=1;38;2;220;100;60:\
or=1;38;2;255;120;120:\
pi=38;2;140;140;140:\
so=38;2;140;140;140:\
bd=38;2;255;140;80:\
cd=38;2;255;140;80:\
su=1;38;2;200;80;60:\
sg=1;38;2;200;80;60:\
tw=1;38;2;200;80;60:\
ow=1;38;2;200;80;60:\
st=38;2;120;120;120:\
*.tar=38;2;255;140;80:\
*.zip=38;2;255;140;80:\
*.gz=38;2;255;140;80:\
*.rar=38;2;255;140;80:\
*.7z=38;2;255;140;80:\
*.txt=38;2;160;160;160:\
*.md=38;2;220;100;60:\
*.py=1;38;2;200;80;60:\
*.js=1;38;2;255;140;80:\
*.ts=1;38;2;255;140;80:\
*.rs=1;38;2;220;100;60:\
*.go=1;38;2;200;80;60:\
*.c=38;2;180;180;180:\
*.cpp=38;2;180;180;180:\
*.h=38;2;180;180;180:\
*.json=38;2;220;100;60:\
*.yaml=38;2;220;100;60:\
*.yml=38;2;220;100;60:\
*.toml=38;2;220;100;60:\
*.conf=38;2;140;140;140:\
*.log=38;2;120;120;120"

#Disable Telemetry for dotnet scaffolding
export DOTNET_CLI_TELEMETRY_OPTOUT=1

# Enable colors
autoload -U colors && colors

# Completion styling + caching (set before compinit runs below)
[[ -d $HOME/.cache/zsh/zcompcache ]] || mkdir -p "$HOME/.cache/zsh/zcompcache"
zstyle ':completion:*' matcher-list 'm:{[:lower:]}={[:upper:]}'   # case-insensitive match
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$HOME/.cache/zsh/zcompcache"

# Open files with default app
alias o='xdg-open'
alias open='xdg-open'

### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

### End of Zinit's installer chunk


############################################ Plugins ############################################
#
# External Tools

# z command - replaced cd, uses navigation history to jump intelligently
eval "$(zoxide init zsh)"

# pretty shell prompt
eval "$(starship init zsh)"

# Smart command correction: type "f" after a bad command (Rust thefuck replacement).
# Installed as a standalone binary in ~/.local/bin (see dotfiles/bootstrap.sh); guard so a
# fresh box that hasn't run bootstrap yet doesn't error on shell start.
(( $+commands[pay-respects] )) && eval "$(pay-respects zsh)"

# fzf: register its widgets/completion here (zle -N must run at top level, not inside
# the zvm hook). The keys themselves are (re)bound in zvm_after_init below, because
# zsh-vi-mode resets bindings on init and would otherwise shadow fzf's Ctrl-R.
(( $+commands[fzf] )) && [[ -t 1 ]] && source <(fzf --zsh)

# Completions: load BEFORE compinit so they actually register, then compile (cached).
zinit ice blockf atpull'zinit creinstall -q .'
zinit light zsh-users/zsh-completions
autoload -Uz compinit
compinit -C -d "$HOME/.cache/zsh/zcompdump"

# Interactive widget stack - kept synchronous so zsh-vi-mode's ZLE rebinds stay
# deterministic. Order matters: fast-syntax-highlighting must come after the other
# widget-wrapping plugins, and history-substring-search must come after highlighting.
zinit light jeffreytse/zsh-vi-mode
zinit light zsh-users/zsh-autosuggestions
zinit light zdharma-continuum/fast-syntax-highlighting
zinit light zsh-users/zsh-history-substring-search

# Deferred extras (turbo: load just after the first prompt).
# NOTE: OMZ snippets stay synchronous on purpose - common-aliases would otherwise load
# after, and clobber the eza ll/la aliases defined below.
zinit snippet "OMZP::git"            # git aliases without full OMZ
zinit snippet "OMZP::common-aliases" # ll, la, grep colors, etc.
zinit wait lucid from"gh-r" as"program" mv"eza* -> eza" for @eza-community/eza  # modern ls

############################################ Aliases ############################################

# EZA rebinds
alias ls='eza --icons'
alias ll='eza -hl --icons'
alias la='eza -hla --icons'
alias tree='eza --tree --icons'

# Color Support
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Claude Code: launch with permission prompts bypassed (matches Windows .zshrc)
alias claude='claude --dangerously-skip-permissions'

# tome - personal todo/notes vault (read-only viewer in ~/tome/bin/tome; structured writes via the /tome skill)
tome() { bash "$HOME/tome/bin/tome" "$@"; }

 ############################################ Keybinds ############################################

# zsh-vi-mode resets keybindings on init, so anything custom (and fzf's Ctrl-R) must be
# (re)bound from inside this hook, otherwise vi-mode clobbers it.
function zvm_after_init() {
  zvm_bindkey viins '^k' history-substring-search-up
  zvm_bindkey viins '^j' history-substring-search-down
  # fzf: Ctrl-R history, Ctrl-T file picker, Alt-C cd-into-subdir. Widgets are
  # defined at top level above; bind through zvm_bindkey so vi-mode's own ^R/^T
  # binds (applied after this hook) don't shadow them.
  if (( $+functions[fzf-history-widget] )); then
    zvm_bindkey viins '^R' fzf-history-widget
    zvm_bindkey viins '^T' fzf-file-widget
    zvm_bindkey viins '^[c' fzf-cd-widget
  fi
  # pay-respects inline fix on Ctrl-X Ctrl-X (the eval above defines the widget)
  (( $+functions[__pr_inline] )) && bindkey '^X^X' __pr_inline
}

export PATH="$HOME/.local/bin:$PATH"

# Machine-local overrides (e.g. VS Code path on the work box) - not stowed/committed.
[[ -f $HOME/.zshrc.local ]] && source "$HOME/.zshrc.local"
