# Homelab minimal zsh configuration
# Designed for server environments - fast startup, essential features only

# History configuration
HISTFILE=~/.zhistory
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS

# Initialize completion system
autoload -Uz compinit
compinit

# Case-insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# Completion colors
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Arrow key history search
bindkey '\e[A' history-search-backward
bindkey '\e[B' history-search-forward

# Better word navigation (ctrl+arrow)
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# Editor
export EDITOR=vim

# Load aliases
if [ -f "$HOME/.config/zsh/aliases.bash" ]; then
    source "$HOME/.config/zsh/aliases.bash"
fi

# Bat configuration (better cat)
if command -v bat &> /dev/null; then
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
    export MANROFFOPT="-c"
fi

# Initialize modern tools if available
# zoxide - smart cd replacement
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
fi

# starship - cross-shell prompt
if command -v starship &> /dev/null; then
    export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
    eval "$(starship init zsh)"
fi

# fzf - fuzzy finder
if command -v fzf &> /dev/null; then
    source <(fzf --zsh)
fi
