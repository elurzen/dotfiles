# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
setopt autocd extendedglob nomatch notify
unsetopt beep
bindkey -v

# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/vanzen/.zshrc'

autoload -Uz compinit
compinit
eval "$(zoxide init zsh)"
eval "$(starship init zsh)"
# End of lines added by compinstall

# Enable colors
autoload -U colors && colors

# Color aliases
alias ls='ls --color=auto'
alias ll='ls -la --color=auto'
alias la='ls -A --color=auto'
alias grep='grep --color=auto'
alias diff='diff --color=auto'

#alias for vesktop to launch in scaled mode
alias vesktop='vesktop --force-device-scale-factor=1.25'

#alias to open files with default app
alias o='xdg-open'

# Optional: colored prompt
# export PS1='%F{green}%n@%m%f:%F{blue}%~%f$ '
