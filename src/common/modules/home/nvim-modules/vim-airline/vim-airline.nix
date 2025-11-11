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
          let s:N1 = ['#37f499', '#1a4d33', 85, 22]
          let s:N2 = ['#cccccc', '#0a0a0a', 250, 232]
          let s:N3 = ['#888888', '#000000', 245, 232]

          " Insert mode
          let s:I1 = ['#00ff00', '#004400', 46, 22]
          let s:I2 = s:N2
          let s:I3 = s:N3

          " Visual mode
          let s:V1 = ['#ff00ff', '#440044', 201, 53]
          let s:V2 = s:N2
          let s:V3 = s:N3

          " Replace mode
          let s:R1 = ['#ff4444', '#440000', 196, 52]
          let s:R2 = s:N2
          let s:R3 = s:N3

          " Command mode
          let s:C1 = ['#ffaa00', '#332200', 214, 58]
          let s:C2 = s:N2
          let s:C3 = s:N3

          let g:airline#themes#nx#palette.normal = airline#themes#generate_color_map(s:N1, s:N2, s:N3)
          let g:airline#themes#nx#palette.insert = airline#themes#generate_color_map(s:I1, s:I2, s:I3)
          let g:airline#themes#nx#palette.visual = airline#themes#generate_color_map(s:V1, s:V2, s:V3)
          let g:airline#themes#nx#palette.replace = airline#themes#generate_color_map(s:R1, s:R2, s:R3)
          let g:airline#themes#nx#palette.commandline = airline#themes#generate_color_map(s:C1, s:C2, s:C3)

          let s:IA = ['#666666', '#000000', 243, 232]
          let g:airline#themes#nx#palette.inactive = airline#themes#generate_color_map(s:IA, s:IA, s:IA)

          let g:airline#themes#nx#palette.tabline = {
            \ 'airline_tab':     ['#666666', '#0a0a0a', 243, 232],
            \ 'airline_tabsel':  ['#37f499', '#1a4d33', 85, 22],
            \ 'airline_tabtype': ['#cccccc', '#0a0a0a', 250, 232],
            \ 'airline_tabfill': ['#888888', '#000000', 245, 232],
            \ 'airline_tabmod':  ['#ffaa00', '#0a0a0a', 214, 232]
            \ }

          let g:airline#themes#nx#palette.normal.airline_warning = ['#ffaa00', '#332200', 214, 58]
          let g:airline#themes#nx#palette.normal.airline_error = ['#ff4444', '#330000', 196, 52]
        '';

    };
}
