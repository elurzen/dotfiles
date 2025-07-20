# History Settings
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000

# Shell Options
setopt autocd extendedglob nomatch notify
unsetopt beep

export EDITOR=nvim
export VISUAL=nvim
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

# Enable colors
autoload -U colors && colors

# Tab autocomplete for zsh
zstyle :compinstall filename '/home/vanzen/.zshrc'
autoload -Uz compinit
compinit

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

# z command - replaced cd, uses navigation history with fzf to jump intelligently
eval "$(zoxide init zsh)"

# pretty shell prompt
eval "$(starship init zsh)"

# type "fuck" after an incorrect command to see potential corrected options
eval "$(thefuck --alias)"

# Better Vi Mode
zinit load "jeffreytse/zsh-vi-mode"

# Suggestions, Syntax highlihghting, and completions
zinit load "zsh-users/zsh-autosuggestions"
zinit load "zsh-users/zsh-syntax-highlighting"
zinit load "zsh-users/zsh-completions"

# Better history search with arrow keys
zinit load "zsh-users/zsh-history-substring-search"

# Git aliases without full OMZ
zinit snippet "OMZP::git"

# Common aliases (ll, la, grep colors, etc)
zinit snippet "OMZP::common-aliases"

# EZA - modern ls replacement
zinit from"gh-r" as"program" mv"eza* -> eza" for @eza-community/eza

# # Directory jumping
# zinit load "agkozak/zsh-z"
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

 ############################################ Keybinds ############################################

# Fix autosuggestions integration
function zvm_after_init() {
  zvm_bindkey viins '^k' history-substring-search-up
  zvm_bindkey viins '^j' history-substring-search-down
}
