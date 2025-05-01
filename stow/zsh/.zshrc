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
HISTSIZE=999
setopt HIST_EXPIRE_DUPS_FIRST

# autocompletion using arrow keys (based on history)
bindkey '\e[A' history-search-backward
bindkey '\e[B' history-search-forward

eval "$(zoxide init zsh)"
plugins=(aliases alias-finder git git-auto-fetch gpg-agent sudo zsh-autosuggestions zsh-navigation-tools zsh-syntax-highlighting zsh-vi-mode)

source $ZSH/oh-my-zsh.sh

# Enable alias finder plugin
zstyle ':omz:plugins:alias-finder' autoload yes
# zstyle ':omz:plugins:alias-finder' longer yes
zstyle ':omz:plugins:alias-finder' exact yes
# zstyle ':omz:plugins:alias-finder' cheaper yes

export STARSHIP_CONFIG=$XDG_CONFIG_HOME/starship/starship.toml
eval "$(starship init zsh)"

source <(fzf --zsh)

# Source custom aliases
if [ -f "$ZSH_CUSTOM/aliases.bash" ]; then
	source "$ZSH_CUSTOM/aliases.bash"
fi


# Bat integrations

export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export MANROFFOPT="-c"

# Configure ssh agent (Relies on a user systemd service)

export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"

# TODO: Doesn't actually work due to passphrase. Look into integrating with a keyring manager
if [ -z "$(ssh-add -l 2>/dev/null)" ]; then
	ssh-add ~/.ssh/id_ed25519
fi

. "$HOME/.local/share/../bin/env"

# NPM configuration

export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"

# Gives shell completion for relevant git files
# Got from (https://www.reddit.com/r/zsh/comments/ass2tc/gitadd_completion_with_full_paths_listed_at_once/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button)
# TODO: Move to a better location
__git_status_files () {
  local -a status_files=( ${"${(0)"$(git status -z)"}"} )
  local -a unstaged_files
  local -a staged_files
  for entry in ${status_files}; do
    local stts=$entry[1,3]
    local file=$entry[4,-1]

    if [[ $stts[2] != ' ' ]]
    then
      unstaged_files+=$file
    fi

    if [[ $stts[1] != ' ' ]] && [[ $stts[1] != '?' ]]
    then
      staged_files+=$file
    fi
  done

  _describe -t unstaged 'Unstaged' unstaged_files && ret=0
  _describe -t staged 'Staged' staged_files && ret=0

  return $ret
}

__git_staged_files () {
  local -a staged_files=( ${"${(0)"$(git diff-index -z --name-only --no-color --cached HEAD)"}"} )
  _describe -t staged 'Staged files' staged_files && ret=0
  return $ret
}

__git_modified_files () {
  __git_status_files
}

__git_treeish-to-index_files () {
  __git_staged_files
}

__git_other_files () { 
}


