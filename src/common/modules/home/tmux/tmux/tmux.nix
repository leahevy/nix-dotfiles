args@{
  lib,
  pkgs,
  pkgs-unstable,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "tmux";

  group = "tmux";
  input = "common";
  namespace = "home";

  settings = {
    waylandClipboard = false;
    primaryBg = self.theme.colors.blocks.primary.background.html;
    primaryFg = self.theme.colors.blocks.primary.foreground.html;
    prefixFg = self.theme.colors.blocks.selection.foreground.html;
    prefixBg = self.theme.colors.blocks.selection.background.html;
    secondaryBg = self.theme.colors.blocks.primary.foreground.html;
    secondaryFg = self.theme.colors.blocks.primary.background.html;
    statusBg = self.theme.colors.terminal.normalBackgrounds.primary.html;
    statusFg = self.theme.colors.terminal.colors.cyan.html;
    borderColor = self.theme.colors.blocks.primary.foreground.html;
    activeBorderColor = self.theme.colors.blocks.primary.background.html;
    defaultShell = "fish";
    useTransparency = true;
    tmuxinatorConfigs = { };
    tmuxinatorBaseConfigs = {
      main = { };
    };
  };

  configuration =
    context@{ config, options, ... }:
    let
      colors = self.settings;
      yamlFormat = pkgs.formats.yaml { };

      allConfigs = self.settings.tmuxinatorBaseConfigs // self.settings.tmuxinatorConfigs;

      tmuxinatorFiles = lib.mapAttrs' (name: config: {
        name = ".config/tmuxinator/${name}.yml";
        value.source = yamlFormat.generate "${name}.yml" (
          {
            name = name;
            root = config.root or "~/";
            windows = config.windows or [ { shell = ""; } ];
          }
          // (builtins.removeAttrs config [
            "root"
            "windows"
          ])
        );
      }) allConfigs;
    in
    {
      home.sessionVariables = lib.mkMerge [
        (lib.mkIf self.isDarwin {
          TMUX_URL_SELECT_OPEN_CMD = "open";
          TMUX_URL_SELECT_CLIP_CMD = "pbcopy";
        })
        (lib.mkIf (self.isLinux && self.settings.waylandClipboard) {
          TMUX_URL_SELECT_CLIP_CMD = "wl-copy --trim-newline";
        })
        (lib.mkIf (self.isLinux && !self.settings.waylandClipboard) {
          TMUX_URL_SELECT_CLIP_CMD = "xclip -i";
        })
      ];

      home.packages =
        with pkgs;
        [
          tmux
          tmuxinator
          perl
        ]
        ++ lib.optionals self.isDarwin [
          (helpers.createTerminalDarwinApp pkgs {
            name = "Tmux";
            terminalApp = "Ghostty.app";
            execArgs = "${config.home.homeDirectory}/.local/bin/tx";
            icon = null;
          })
        ];

      home.file = tmuxinatorFiles // {
        ".local/bin/scripts/tmux-url-select" = {
          source = self.file "tmux-url-select/tmux-url-select.pl";
          executable = true;
        };

        ".local/bin/tx" = {
          text = ''
            #!/usr/bin/env bash
            if [ $# -eq 0 ]; then
              exec ${pkgs.tmuxinator}/bin/tmuxinator start main
            else
              exec ${pkgs.tmuxinator}/bin/tmuxinator start "$@"
            fi
          '';
          executable = true;
        };

        ".local/bin/tmux" = {
          text = ''
            #!/usr/bin/env bash
            if [ $# -eq 0 ]; then
              exec ${pkgs.tmuxinator}/bin/tmuxinator start main
            else
              exec ${pkgs.tmux}/bin/tmux "$@"
            fi
          '';
          executable = true;
        };

        ".local/bin/tmuxinator" = {
          text = ''
            #!/usr/bin/env bash
            if [ $# -eq 0 ]; then
              exec ${pkgs.tmuxinator}/bin/tmuxinator start main
            else
              exec ${pkgs.tmuxinator}/bin/tmuxinator "$@"
            fi
          '';
          executable = true;
        };

        ".tmux.conf".text = ''
          run-shell 'for conf in ~/.config/tmux/*.conf; do [ -f "$conf" ] && tmux source-file "$conf"; done'
        '';

        ".config/tmux/10-base.conf".text = ''
          set -g default-terminal "$TERM"
          set -ga terminal-overrides ",*256col*:Tc"
          set -g mouse on
          set -g base-index 1
          setw -g pane-base-index 1
          set -g renumber-windows on
          set -g history-limit 50000
          set -g display-time 4000
          set -g status-interval 5
          set -g focus-events on
          setw -g aggressive-resize on

          set-option -g allow-rename off

          set -g visual-activity off
          set -g visual-bell off
          set -g visual-silence off
          setw -g monitor-activity off
          set -g bell-action none
        '';

        ".config/tmux/20-keybindings.conf".text = ''
          unbind C-b
          set-option -g prefix C-a
          bind-key C-a send-prefix

          bind-key 0 select-window -t :10
          bind-key - select-window -t :11
          bind-key = select-window -t :12

          bind-key -n M-1 select-window -t :1
          bind-key -n M-2 select-window -t :2
          bind-key -n M-3 select-window -t :3
          bind-key -n M-4 select-window -t :4
          bind-key -n M-5 select-window -t :5
          bind-key -n M-6 select-window -t :6
          bind-key -n M-7 select-window -t :7
          bind-key -n M-8 select-window -t :8
          bind-key -n M-9 select-window -t :9
          bind-key -n M-0 select-window -t :10
          bind-key -n M-- select-window -t :11
          bind-key -n M-= select-window -t :12

          bind-key -n C-S-Left previous-window
          bind-key -n C-S-Right next-window

          bind-key -n M-[ previous-window
          bind-key -n M-] next-window
          bind-key -n M-Left previous-window
          bind-key -n M-Right next-window

          bind -r H resize-pane -L 10
          bind -r J resize-pane -D 10
          bind -r K resize-pane -U 10
          bind -r L resize-pane -R 10

          bind -r Left resize-pane -L 10
          bind -r Down resize-pane -D 10
          bind -r Up resize-pane -U 10
          bind -r Right resize-pane -R 10

          setw -g mode-keys vi
          bind -T copy-mode-vi v send-keys -X begin-selection
          bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel '${
            if self.settings.waylandClipboard then
              "wl-copy --trim-newline"
            else
              "xclip -in -selection clipboard"
          }'
          bind -T copy-mode-vi r send-keys -X rectangle-toggle

          bind C-p previous-window
          bind C-n next-window

          bind v split-window -h -c "#{pane_current_path}"
          bind h split-window -v -c "#{pane_current_path}"

          unbind %
          unbind '"'

          bind a copy-mode
          unbind [

          bind u run-shell -b "${config.home.homeDirectory}/.local/bin/scripts/tmux-url-select"

          bind r source-file ~/.tmux.conf \; display "Config reloaded!"

          unbind \;
          unbind :
          bind \; command-prompt
          bind : last-pane

          bind-key -n M-S-Left swap-window -t -1 \; select-window -t -1
          bind-key -n M-S-Right swap-window -t +1 \; select-window -t +1
        '';

        ".config/tmux/25-vim-tmux-navigator.conf".text = ''
          is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
            | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?|fzf)(diff)?'"

          bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h'  'select-pane -L'
          bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j'  'select-pane -D'
          bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k'  'select-pane -U'
          bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l'  'select-pane -R'

          tmux_version='$(tmux -V | sed -En "s/^tmux ([0-9]+(.[0-9]+)?).*/\1/p")'
          if-shell -b '[ "$(echo "$tmux_version < 3.0" | bc)" = 1 ]' \
            "bind-key -n 'C-\\' if-shell \"$is_vim\" 'send-keys C-\\'  'select-pane -l'"
          if-shell -b '[ "$(echo "$tmux_version >= 3.0" | bc)" = 1 ]' \
            "bind-key -n 'C-\\' if-shell \"$is_vim\" 'send-keys C-\\\\'  'select-pane -l'"

          bind-key -T copy-mode-vi 'C-h' select-pane -L
          bind-key -T copy-mode-vi 'C-j' select-pane -D
          bind-key -T copy-mode-vi 'C-k' select-pane -U
          bind-key -T copy-mode-vi 'C-l' select-pane -R
          bind-key -T copy-mode-vi 'C-\' select-pane -l
        '';

        ".config/tmux/30-statusbar.conf".text =
          let
            statusBg = if self.settings.useTransparency then "default" else colors.statusBg;
            statusBgInverted = colors.statusBg;

            powerlineSymbols = {
              left = "";
              right = "";
              leftThin = "";
              rightThin = "";
            };

            status-left = "#{?client_prefix,#[fg=${colors.prefixFg}]#[bg=${colors.prefixBg}] #S #[fg=${colors.prefixBg}]#[bg=${statusBg}]${powerlineSymbols.right},#[fg=${colors.primaryFg}]#[bg=${colors.primaryBg}] #S #[fg=${colors.primaryBg}]#[bg=${statusBg}]${powerlineSymbols.right}}";
            status-right = "#[fg=${colors.borderColor}]#[bg=${statusBg}]#[nobold]#[nounderscore]#[noitalics]${powerlineSymbols.left}#[fg=${colors.secondaryFg}]#[bg=${colors.secondaryBg}] %Y-%m-%d ${powerlineSymbols.leftThin} %H:%M #{?client_prefix,#[fg=${colors.prefixBg}]#[bg=${colors.secondaryBg}]${powerlineSymbols.left}#[fg=${colors.prefixFg}]#[bg=${colors.prefixBg}] #h ,#[fg=${colors.primaryBg}]#[bg=${colors.secondaryBg}]#[nobold]#[nounderscore]#[noitalics]${powerlineSymbols.left}#[fg=${colors.primaryFg}]#[bg=${colors.primaryBg}] #h }";
            window-status-format = "#[fg=${colors.statusFg}]#[bg=${statusBg}] #I ${powerlineSymbols.rightThin}#[fg=${colors.statusFg}]#[bg=${statusBg}] #W ";
            window-status-current-format = "#[fg=${statusBgInverted}]#[bg=${colors.borderColor}]#[nobold]#[nounderscore]#[noitalics]${powerlineSymbols.right}#[fg=${colors.secondaryFg}]#[bg=${colors.borderColor}] #I ${powerlineSymbols.rightThin}#[fg=${colors.secondaryFg}]#[bg=${colors.borderColor}] #W #[fg=${colors.borderColor}]#[bg=${statusBg}]#[nobold]#[nounderscore]#[noitalics]${powerlineSymbols.right}";
          in
          ''
            set -g status-justify "centre"
            set -g status "on"
            set -g status-left-style "none"
            set -g status 2
            set -g status-format[0] "#[bg=default] "
            set -g status-format[1] "#[align=left]${status-left}#[align=centre]#{W:#{E:window-status-format},#{E:window-status-current-format}}#[align=right]${status-right}"
            set -g message-command-style "fg=${colors.secondaryFg},bg=${colors.secondaryBg}"
            set -g status-right-style "none"
            set -g pane-active-border-style "fg=${colors.activeBorderColor}"
            set -g status-style "none,bg=${statusBg}"
            set -g message-style "fg=${colors.secondaryFg},bg=${colors.secondaryBg}"
            set -g pane-border-style "fg=${colors.borderColor}"
            set -g status-right-length "100"
            set -g status-left-length "100"
            setw -g window-status-activity-style "none"
            setw -g window-status-separator ""
            setw -g window-status-style "none,fg=${colors.statusFg},bg=${statusBg}"
            setw -g window-status-format "${window-status-format}"
            setw -g window-status-current-format "${window-status-current-format}"
          '';
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".tmux"
          ".config/tmux"
        ];
      };

      xdg.desktopEntries = lib.optionalAttrs self.isLinux {
        "Tmux" = {
          name = "Tmux";
          genericName = "Tmux terminal multiplexer";
          comment = "Opens the main tmux session";
          exec = "${config.home.homeDirectory}/.local/bin/tx";
          icon = "com.mitchellh.ghostty";
          terminal = true;
          categories = [
            "Utility"
            "TerminalEmulator"
          ];
        };
      };
    };
}
