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

  defaults = {
    primaryBg = "#dfff00";
    primaryFg = "#00005f";
    secondaryBg = "#444444";
    secondaryFg = "#ffffff";
    statusBg = "#202020";
    statusFg = "#9cffd3";
    borderColor = "#444444";
    activeBorderColor = "#dfff00";
    showHostname = true;
    dateFormat = "%Y-%m-%d";
    timeFormat = "%H:%M";
  };

  configuration =
    context@{ config, options, ... }:
    let
      colors = self.settings;
      hostnameSection = lib.optionalString colors.showHostname " #h ";
    in
    {
      home.packages = with pkgs; [
        tmux
        tmuxinator
      ];

      home.file.".tmux.conf".text = ''
        run-shell 'for conf in ~/.config/tmux/*.conf; do [ -f "$conf" ] && tmux source-file "$conf"; done'
      '';

      home.file.".config/tmux/10-base.conf".text = ''
        set -g default-terminal "screen-256color"
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
      '';

      home.file.".config/tmux/20-keybindings.conf".text = ''
        bind -r H resize-pane -L 10
        bind -r J resize-pane -D 10
        bind -r K resize-pane -U 10
        bind -r L resize-pane -R 10

        setw -g mode-keys vi
        bind -T copy-mode-vi v send-keys -X begin-selection
        bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel 'xclip -in -selection clipboard'
        bind -T copy-mode-vi r send-keys -X rectangle-toggle

        bind C-p previous-window
        bind C-n next-window

        bind v split-window -h -c "#{pane_current_path}"
        bind h split-window -v -c "#{pane_current_path}"

        unbind %
        unbind '"'

        bind r source-file ~/.tmux.conf \; display "Config reloaded!"
      '';

      home.file.".config/tmux/25-vim-tmux-navigator.conf".text = ''
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

      home.file.".config/tmux/30-statusbar.conf".text = ''
        set -g status-justify "centre"
        set -g status "on"
        set -g status-left-style "none"
        set -g message-command-style "fg=${colors.secondaryFg},bg=${colors.secondaryBg}"
        set -g status-right-style "none"
        set -g pane-active-border-style "fg=${colors.activeBorderColor}"
        set -g status-style "none,bg=${colors.statusBg}"
        set -g message-style "fg=${colors.secondaryFg},bg=${colors.secondaryBg}"
        set -g pane-border-style "fg=${colors.borderColor}"
        set -g status-right-length "100"
        set -g status-left-length "100"
        setw -g window-status-activity-style "none"
        setw -g window-status-separator ""
        setw -g window-status-style "none,fg=${colors.statusFg},bg=${colors.statusBg}"
        set -g status-left "#[fg=${colors.primaryFg},bg=${colors.primaryBg}] #S #[fg=${colors.primaryBg},bg=${colors.statusBg},nobold,nounderscore,noitalics]"
        set -g status-right "#[fg=${colors.borderColor},bg=${colors.statusBg},nobold,nounderscore,noitalics]#[fg=${colors.secondaryFg},bg=${colors.secondaryBg}] %Y-%m-%d  %H:%M #[fg=${colors.primaryBg},bg=${colors.secondaryBg},nobold,nounderscore,noitalics]#[fg=${colors.primaryFg},bg=${colors.primaryBg}] #h "
        setw -g window-status-format "#[fg=${colors.statusFg},bg=${colors.statusBg}] #I #[fg=${colors.statusFg},bg=${colors.statusBg}] #W "
        setw -g window-status-current-format "#[fg=${colors.statusBg},bg=${colors.borderColor},nobold,nounderscore,noitalics]#[fg=${colors.secondaryFg},bg=${colors.borderColor}] #I #[fg=${colors.secondaryFg},bg=${colors.borderColor}] #W #[fg=${colors.borderColor},bg=${colors.statusBg},nobold,nounderscore,noitalics]"
      '';

      home.persistence."${self.persist}" = {
        directories = [
          ".tmux"
          ".config/tmux"
        ];
      };
    };
}
