{ config, pkgs, ... }:

{
  programs = {
    # Zsh configuration
    zsh = {
      enable = true;

      # Enable built-in features
      enableCompletion = true;
      autosuggestion.enable = true; # Fish-like suggestions
      syntaxHighlighting.enable = true; # Syntax highlighting

      # Vi mode
      defaultKeymap = "viins";

      # History configuration
      history = {
        size = 10000;
        save = 10000;
        share = true; # Share history between sessions
        ignoreDups = true; # Don't save duplicates
        ignoreSpace = true; # Don't save commands starting with space
        expireDuplicatesFirst = true;
      };

      # Shell aliases
      shellAliases = {
        # Modern replacements (eza, bat configured via programs.*)
        cat = "bat --paging=never";
        less = "bat --paging=always";
        grep = "rg";
        find = "fd";

        # Navigation
        ".." = "cd ..";
        "..." = "cd ../..";
        "...." = "cd ../../..";

        # Git shortcuts
        g = "git";
        gs = "git status";
        gd = "git diff";
        ga = "git add";
        gc = "git commit";
        gp = "git pull";
        gl = "git lg"; # Uses our git alias

        # Quality of life
        c = "clear";
        h = "history";
        ports = "ss -tuln";

        # Safer operations
        rm = "rm -i";
        mv = "mv -i";
        cp = "cp -i";

        # Reload config
        reload = "source ~/.zshrc";
      };

      # Additional init commands (renamed from initExtra in 25.11)
      initContent = ''
        # Vi mode settings
        bindkey -v
        export KEYTIMEOUT=1

        # Arrow key history search
        bindkey '^[[A' history-search-backward
        bindkey '^[[B' history-search-forward

        # Better word navigation
        bindkey '^[[1;5C' forward-word
        bindkey '^[[1;5D' backward-word

        # Edit command in $EDITOR with ctrl-e
        autoload -U edit-command-line
        zle -N edit-command-line
        bindkey '^e' edit-command-line

        # Case-insensitive completion
        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

        # Completion colors
        zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
      '';

      # Environment variables
      sessionVariables = {
        EDITOR = "nvim";
        VISUAL = "nvim";
        MANPAGER = "sh -c 'col -bx | bat -l man -p'";
      };
    };

    # Starship prompt with Catppuccin theme
    starship = {
      enable = true;
      settings = {
        command_timeout = 10000;
        palette = "catppuccin_mocha";

        # Catppuccin Mocha palette
        palettes.catppuccin_mocha = {
          rosewater = "#f5e0dc";
          flamingo = "#f2cdcd";
          pink = "#f5c2e7";
          mauve = "#cba6f7";
          red = "#f38ba8";
          maroon = "#eba0ac";
          peach = "#fab387";
          yellow = "#f9e2af";
          green = "#a6e3a1";
          teal = "#94e2d5";
          sky = "#89dceb";
          sapphire = "#74c7ec";
          blue = "#89b4fa";
          lavender = "#b4befe";
          text = "#cdd6f4";
          subtext1 = "#bac2de";
          subtext0 = "#a6adc8";
          overlay2 = "#9399b2";
          overlay1 = "#7f849c";
          overlay0 = "#6c7086";
          surface2 = "#585b70";
          surface1 = "#45475a";
          surface0 = "#313244";
          base = "#1e1e2e";
          mantle = "#181825";
          crust = "#11111b";
        };
      };
    };

    # Direnv with nix-direnv and zsh integration
    direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableZshIntegration = true;
    };
  };
}
