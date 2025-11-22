# Homelab aliases - modern CLI tool replacements

# Modern replacements (only if tools are installed)
if command -v eza &> /dev/null; then
    alias ls='eza'
    alias ll='eza -l'
    alias la='eza -la'
    alias lt='eza -T'
fi

if command -v bat &> /dev/null; then
    alias cat='bat --paging=never'
    alias less='bat --paging=always'
fi

if command -v rg &> /dev/null; then
    alias grep='rg'
fi

if command -v fd &> /dev/null; then
    alias find='fd'
fi

# Quality of life
alias c='clear'
alias h='history'
alias ..='cd ..'
alias ...='cd ../..'

# System info
alias ports='ss -tuln'
alias psgrep='ps aux | grep -v grep | grep -i -e VSZ -e'

# Git shortcuts (keep it minimal)
alias g='git'
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate'
alias ga='git add'
alias gc='git commit'
alias gp='git pull'

# Safer operations
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

# Colorize where possible
alias diff='diff --color=auto'
alias ip='ip -c'
