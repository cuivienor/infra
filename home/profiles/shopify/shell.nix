# home/profiles/shopify/shell.nix
{ config, pkgs, lib, ... }:

{
  programs.zsh.initContent = lib.mkAfter ''
    # ===========================================
    # Shopify Work Environment
    # ===========================================

    # Shopify dev tool
    [ -f /opt/dev/dev.sh ] && source /opt/dev/dev.sh

    # Homebrew (for casks and work-specific tools)
    [[ -x /opt/homebrew/bin/brew ]] && eval $(/opt/homebrew/bin/brew shellenv)

    # chruby for Ruby version management (lazy-loaded)
    [[ -f /opt/dev/sh/chruby/chruby.sh ]] && { type chruby >/dev/null 2>&1 || chruby () { source /opt/dev/sh/chruby/chruby.sh; chruby "$@"; } }

    # tec agent initialization
    [[ -x /Users/cuiv/.local/state/tec/profiles/base/current/global/init ]] && eval "$(/Users/cuiv/.local/state/tec/profiles/base/current/global/init zsh)"

    # shadowenv for per-directory environments (must come after PATH modifications)
    if command -v shadowenv &> /dev/null; then
      eval "$(shadowenv init zsh)"
    fi

    # Ensure Nix-managed tools take priority over Homebrew
    # This must come last to override brew shellenv
    export PATH="$HOME/.nix-profile/bin:$PATH"
  '';
}
