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
  name = "vim-airline";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    powerlineSymbols = true;
    themeOverride = true;
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.airline = {
          enable = true;
          settings = {
            powerline_fonts = lib.mkIf self.settings.powerlineSymbols 1;
            skip_empty_sections = 1;
          }
          // lib.optionalAttrs self.settings.themeOverride {
            theme = "nx";
          };
        };

        globals = {
          "airline#extensions#tabline#enabled" = 1;
          "airline#extensions#tabline#show_close_button" = 0;
        };
      };

      home.file.".config/nvim/autoload/airline/themes/nx.vim".text =
        lib.mkIf self.settings.themeOverride ''
          let g:airline#themes#nx#palette = {}

          " Normal mode
          let s:N1 = ['${config.nx.preferences.theme.colors.blocks.primary.foreground.html}', '${config.nx.preferences.theme.colors.blocks.primary.background.html}', ${builtins.toString config.nx.preferences.theme.colors.blocks.primary.foreground.term}, ${builtins.toString config.nx.preferences.theme.colors.blocks.primary.background.term}]
          let s:N2 = ['${config.nx.preferences.theme.colors.terminal.foregrounds.primary.html}', '${config.nx.preferences.theme.colors.terminal.normalBackgrounds.secondary.html}', ${builtins.toString config.nx.preferences.theme.colors.terminal.foregrounds.primary.term}, ${builtins.toString config.nx.preferences.theme.colors.terminal.normalBackgrounds.secondary.term}]
          let s:N3 = ['${config.nx.preferences.theme.colors.terminal.foregrounds.dim.html}', '${config.nx.preferences.theme.colors.terminal.normalBackgrounds.primary.html}', ${builtins.toString config.nx.preferences.theme.colors.terminal.foregrounds.dim.term}, ${builtins.toString config.nx.preferences.theme.colors.terminal.normalBackgrounds.primary.term}]

          " Insert mode
          let s:I1 = ['${config.nx.preferences.theme.colors.blocks.accent.foreground.html}', '${config.nx.preferences.theme.colors.blocks.accent.background.html}', ${builtins.toString config.nx.preferences.theme.colors.blocks.accent.foreground.term}, ${builtins.toString config.nx.preferences.theme.colors.blocks.accent.background.term}]
          let s:I2 = s:N2
          let s:I3 = s:N3

          " Visual mode
          let s:V1 = ['${config.nx.preferences.theme.colors.blocks.highlight.foreground.html}', '${config.nx.preferences.theme.colors.blocks.highlight.background.html}', ${builtins.toString config.nx.preferences.theme.colors.blocks.highlight.foreground.term}, ${builtins.toString config.nx.preferences.theme.colors.blocks.highlight.background.term}]
          let s:V2 = s:N2
          let s:V3 = s:N3

          " Replace mode
          let s:R1 = ['${config.nx.preferences.theme.colors.blocks.critical.foreground.html}', '${config.nx.preferences.theme.colors.blocks.critical.background.html}', ${builtins.toString config.nx.preferences.theme.colors.blocks.critical.foreground.term}, ${builtins.toString config.nx.preferences.theme.colors.blocks.critical.background.term}]
          let s:R2 = s:N2
          let s:R3 = s:N3

          " Command mode
          let s:C1 = ['${config.nx.preferences.theme.colors.blocks.warning.foreground.html}', '${config.nx.preferences.theme.colors.blocks.warning.background.html}', ${builtins.toString config.nx.preferences.theme.colors.blocks.warning.foreground.term}, ${builtins.toString config.nx.preferences.theme.colors.blocks.warning.background.term}]
          let s:C2 = s:N2
          let s:C3 = s:N3

          let g:airline#themes#nx#palette.normal = airline#themes#generate_color_map(s:N1, s:N2, s:N3)
          let g:airline#themes#nx#palette.insert = airline#themes#generate_color_map(s:I1, s:I2, s:I3)
          let g:airline#themes#nx#palette.visual = airline#themes#generate_color_map(s:V1, s:V2, s:V3)
          let g:airline#themes#nx#palette.replace = airline#themes#generate_color_map(s:R1, s:R2, s:R3)
          let g:airline#themes#nx#palette.commandline = airline#themes#generate_color_map(s:C1, s:C2, s:C3)

          let s:IA = ['${config.nx.preferences.theme.colors.separators.normal.html}', '${config.nx.preferences.theme.colors.terminal.normalBackgrounds.primary.html}', ${builtins.toString config.nx.preferences.theme.colors.separators.normal.term}, ${builtins.toString config.nx.preferences.theme.colors.terminal.normalBackgrounds.primary.term}]
          let g:airline#themes#nx#palette.inactive = airline#themes#generate_color_map(s:IA, s:IA, s:IA)

          let g:airline#themes#nx#palette.tabline = {
            \ 'airline_tab':     ['${config.nx.preferences.theme.colors.separators.normal.html}', '${config.nx.preferences.theme.colors.terminal.normalBackgrounds.secondary.html}', ${builtins.toString config.nx.preferences.theme.colors.separators.normal.term}, ${builtins.toString config.nx.preferences.theme.colors.terminal.normalBackgrounds.secondary.term}],
            \ 'airline_tabsel':  ['${config.nx.preferences.theme.colors.blocks.primary.foreground.html}', '${config.nx.preferences.theme.colors.blocks.primary.background.html}', ${builtins.toString config.nx.preferences.theme.colors.blocks.primary.foreground.term}, ${builtins.toString config.nx.preferences.theme.colors.blocks.primary.background.term}],
            \ 'airline_tabtype': ['${config.nx.preferences.theme.colors.terminal.foregrounds.primary.html}', '${config.nx.preferences.theme.colors.terminal.normalBackgrounds.secondary.html}', ${builtins.toString config.nx.preferences.theme.colors.terminal.foregrounds.primary.term}, ${builtins.toString config.nx.preferences.theme.colors.terminal.normalBackgrounds.secondary.term}],
            \ 'airline_tabfill': ['${config.nx.preferences.theme.colors.terminal.foregrounds.dim.html}', '${config.nx.preferences.theme.colors.terminal.normalBackgrounds.primary.html}', ${builtins.toString config.nx.preferences.theme.colors.terminal.foregrounds.dim.term}, ${builtins.toString config.nx.preferences.theme.colors.terminal.normalBackgrounds.primary.term}],
            \ 'airline_tabmod':  ['${config.nx.preferences.theme.colors.blocks.warning.foreground.html}', '${config.nx.preferences.theme.colors.terminal.normalBackgrounds.secondary.html}', ${builtins.toString config.nx.preferences.theme.colors.blocks.warning.foreground.term}, ${builtins.toString config.nx.preferences.theme.colors.terminal.normalBackgrounds.secondary.term}]
            \ }

          let g:airline#themes#nx#palette.normal.airline_warning = ['${config.nx.preferences.theme.colors.blocks.warning.foreground.html}', '${config.nx.preferences.theme.colors.blocks.warning.background.html}', ${builtins.toString config.nx.preferences.theme.colors.blocks.warning.foreground.term}, ${builtins.toString config.nx.preferences.theme.colors.blocks.warning.background.term}]
          let g:airline#themes#nx#palette.normal.airline_error = ['${config.nx.preferences.theme.colors.blocks.critical.foreground.html}', '${config.nx.preferences.theme.colors.blocks.critical.background.html}', ${builtins.toString config.nx.preferences.theme.colors.blocks.critical.foreground.term}, ${builtins.toString config.nx.preferences.theme.colors.blocks.critical.background.term}]
        '';

    };
}
