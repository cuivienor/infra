ZSH_CUSTOM=$HOME/.config/zsh
# Configure XDG data environment
if [ -f "$HOME/.config/xdg_config.bash" ]; then
	source "$HOME/.config/xdg_config.bash"
fi

# Modify Path
if [ -f "$XDG_CONFIG_HOME/path.bash" ]; then
	source "${XDG_CONFIG_HOME}/path.bash"
fi

# Remove duplicate paths which can happen in nester shell invokations
typeset -U PATH

# Source secrets if they exist
if [ -f "$HOME/.env" ]; then
	source "$HOME/.env"
fi

export EDITOR="nvim"
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="catppuccin"

zstyle ':omz:update' mode reminder

# AUTOCOMPLETION

# initialize autocompletion
autoload -U compinit && compinit

# history setup
setopt SHARE_HISTORY
HISTFILE=$HOME/.zhistory
SAVEHIST=1000
HISTSIZE=1000
setopt HIST_EXPIRE_DUPS_FIRST

# autocompletion using arrow keys (based on history)
bindkey '\e[A' history-search-backward
bindkey '\e[B' history-search-forward

# NOTE: zoxide init moved to after PATH setup is complete

ZVM_INIT_MODE=sourcing # Fixes some vi mode issues with other plugins key bindins like fzf
# https://github.com/jeffreytse/zsh-vi-mode/issues/24
plugins=(aliases alias-finder git git-auto-fetch gpg-agent sudo zsh-autosuggestions zsh-navigation-tools zsh-syntax-highlighting zsh-vi-mode fzf)

source $ZSH/oh-my-zsh.sh

# Enable alias finder plugin
zstyle ':omz:plugins:alias-finder' autoload yes
# zstyle ':omz:plugins:alias-finder' longer yes
zstyle ':omz:plugins:alias-finder' exact yes
# zstyle ':omz:plugins:alias-finder' cheaper yes

# NOTE: starship init moved to after PATH setup is complete
export STARSHIP_CONFIG=$XDG_CONFIG_HOME/starship/starship.toml


# Source custom aliases
if [ -f "$ZSH_CUSTOM/aliases.bash" ]; then
	source "$ZSH_CUSTOM/aliases.bash"
fi

# Source corporate-specific configuration if it exists
# This file is not checked into version control
if [ -f "$HOME/.corporate.zshrc" ]; then
	source "$HOME/.corporate.zshrc"
fi


# Bat integrations

export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export MANROFFOPT="-c"

# Configure ssh agent (Relies on a user systemd service)

export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"

# TODO: Doesn't actually work due to passphrase. Look into integrating with a keyring manager
# if [ -z "$(ssh-add -l 2>/dev/null)" ]; then
# 	ssh-add ~/.ssh/id_ed25519
# fi

# Source local environment if it exists
# Moved to after homebrew and chruby initialization

# Initialize tools that depend on PATH being fully set up
# zoxide - smart cd replacement
if command -v zoxide &> /dev/null; then
	eval "$(zoxide init zsh)"
fi

# starship - cross-shell prompt
if command -v starship &> /dev/null; then
	eval "$(starship init zsh)"
fi

# fzf - fuzzy finder (uncomment if needed)
# if command -v fzf &> /dev/null; then
# 	source <(fzf --zsh)
# fi

# NPM configuration

# export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"

# NPM configuration

export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"

# Gives shell completion for relevant git files
# Got from (https://www.reddit.com/r/zsh/comments/ass2tc/gitadd_completion_with_full_paths_listed_at_once/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button)
# TODO: Move to a better location
__git_status_files () {
  # Check if we're in a git repository
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 1
  fi

  local ret=1
  local -a status_files unstaged_files staged_files
  
  # Get git status with null-terminated output
  status_files=("${(@0)$(git status --porcelain=v1 -z 2>/dev/null)}")
  
  # Parse each status entry
  for entry in "${status_files[@]}"; do
    if [[ -z "$entry" ]]; then continue; fi
    
    local status_code="${entry[1,2]}"
    local file_path="${entry[4,-1]}"
    
    # Skip if no file path
    [[ -z "$file_path" ]] && continue
    
    # Check for unstaged changes (second character not space)
    if [[ "${status_code[2]}" != " " ]]; then
      unstaged_files+=("$file_path")
    fi
    
    # Check for staged changes (first character not space and not untracked)
    if [[ "${status_code[1]}" != " " && "${status_code[1]}" != "?" ]]; then
      staged_files+=("$file_path")
    fi
  done

  # Provide completions
  if (( ${#unstaged_files[@]} > 0 )); then
    _describe -t unstaged 'Unstaged files' unstaged_files && ret=0
  fi
  
  if (( ${#staged_files[@]} > 0 )); then
    _describe -t staged 'Staged files' staged_files && ret=0
  fi

  return $ret
}

__git_staged_files () {
  # Check if we're in a git repository
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 1
  fi

  local ret=1
  local -a staged_files
  
  # Get staged files with null-terminated output
  staged_files=("${(@0)$(git diff --name-only --cached -z 2>/dev/null)}")
  
  # Filter out empty entries
  staged_files=("${staged_files[@]:#}")
  
  if (( ${#staged_files[@]} > 0 )); then
    _describe -t staged 'Staged files' staged_files && ret=0
  fi
  
  return $ret
}

__git_modified_files () {
  __git_status_files
}

__git_treeish-to-index_files () {
  __git_staged_files
}

__git_other_files () {
  # Check if we're in a git repository
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 1
  fi

  local ret=1
  local -a other_files
  
  # Get untracked files
  other_files=("${(@0)$(git ls-files --others --exclude-standard -z 2>/dev/null)}")
  
  # Filter out empty entries
  other_files=("${other_files[@]:#}")
  
  if (( ${#other_files[@]} > 0 )); then
    _describe -t other 'Untracked files' other_files && ret=0
  fi
  
  return $ret
}



[[ -x /opt/homebrew/bin/brew ]] && eval $(/opt/homebrew/bin/brew shellenv)

[[ -f /opt/dev/sh/chruby/chruby.sh ]] && { type chruby >/dev/null 2>&1 || chruby () { source /opt/dev/sh/chruby/chruby.sh; chruby "$@"; } }

# Source local environment to add ~/.local/bin to PATH
if [ -f "$HOME/.local/bin/env" ]; then
	. "$HOME/.local/bin/env"
fi

# Initialize shadowenv for directory-based environment management
# This must come after all PATH modifications
if command -v shadowenv &> /dev/null; then
	eval "$(shadowenv init zsh)"
fi


# opencode
export PATH=/Users/cuiv/.opencode/bin:$PATH

# Added by tec agent
[[ -x /Users/cuiv/.local/state/tec/profiles/base/current/global/init ]] && eval "$(/Users/cuiv/.local/state/tec/profiles/base/current/global/init zsh)"
