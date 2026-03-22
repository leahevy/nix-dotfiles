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
  name = "modicator";

  group = "nvim-modules";
  input = "common";

  settings = {
    colors = {
      normal = null;
      insert = null;
      visual = null;
      command = null;
      replace = null;
      select = null;
      terminal = null;
      terminalNormal = null;
    };
  };

  on = {
    home =
      config:
      let
        theme = config.nx.preferences.theme;
        colors = {
          normal =
            if self.settings.colors.normal != null then
              self.settings.colors.normal
            else
              theme.colors.blocks.primary.foreground.html;
          insert =
            if self.settings.colors.insert != null then
              self.settings.colors.insert
            else
              theme.colors.blocks.accent.foreground.html;
          visual =
            if self.settings.colors.visual != null then
              self.settings.colors.visual
            else
              theme.colors.blocks.highlight.foreground.html;
          command =
            if self.settings.colors.command != null then
              self.settings.colors.command
            else
              theme.colors.blocks.warning.foreground.html;
          replace =
            if self.settings.colors.replace != null then
              self.settings.colors.replace
            else
              theme.colors.blocks.critical.foreground.html;
          select =
            if self.settings.colors.select != null then
              self.settings.colors.select
            else
              theme.colors.blocks.neutral.foreground.html;
          terminal =
            if self.settings.colors.terminal != null then
              self.settings.colors.terminal
            else
              theme.colors.blocks.info.foreground.html;
          terminalNormal =
            if self.settings.colors.terminalNormal != null then
              self.settings.colors.terminalNormal
            else
              theme.colors.blocks.info.foreground.html;
        };
      in
      {
        programs.nixvim = {
          plugins.modicator = {
            enable = true;

            settings = {
              show_warnings = false;

              highlights = {
                defaults = {
                  bold = true;
                  italic = false;
                };
                use_cursorline_background = false;
              };

              integration = {
                lualine = {
                  enabled = lib.mkIf (self.isModuleEnabled "nvim-modules.lualine") true;
                  mode_section = null;
                  highlight = "bg";
                };
              };
            };
          };

          extraConfigLua = ''
            _G.nx_modules = _G.nx_modules or {}

            _G.nx_modules["97-modicator"] = function()
              vim.o.termguicolors = true
              vim.o.cursorline = true
              vim.o.number = true

              local function setup_modicator_highlights()
                vim.api.nvim_set_hl(0, "NormalMode", { fg = "${colors.normal}", bold = true })
                vim.api.nvim_set_hl(0, "InsertMode", { fg = "${colors.insert}", bold = true })
                vim.api.nvim_set_hl(0, "VisualMode", { fg = "${colors.visual}", bold = true })
                vim.api.nvim_set_hl(0, "CommandMode", { fg = "${colors.command}", bold = true })
                vim.api.nvim_set_hl(0, "ReplaceMode", { fg = "${colors.replace}", bold = true })
                vim.api.nvim_set_hl(0, "SelectMode", { fg = "${colors.select}", bold = true })
                vim.api.nvim_set_hl(0, "TerminalMode", { fg = "${colors.terminal}", bold = true })
                vim.api.nvim_set_hl(0, "TerminalNormalMode", { fg = "${colors.terminalNormal}", bold = false })
              end

              vim.api.nvim_create_autocmd({"VimEnter", "ColorScheme"}, {
                callback = function()
                  vim.defer_fn(setup_modicator_highlights, 50)
                end,
              })

              setup_modicator_highlights()

              vim.api.nvim_create_autocmd({"BufEnter", "BufWinEnter"}, {
                callback = function()
                  local delay = vim.v.vim_did_enter == 1 and 0 or 300
                  vim.defer_fn(function()
                    local mode = vim.fn.mode()
                    if mode == 'n' then
                      vim.api.nvim_exec_autocmds('ModeChanged', {pattern = 'n:n'})
                    elseif mode == 'i' then
                      vim.api.nvim_exec_autocmds('ModeChanged', {pattern = 'i:i'})
                    end
                  end, delay)
                end,
              })
            end
          '';
        };
      };
  };
}
