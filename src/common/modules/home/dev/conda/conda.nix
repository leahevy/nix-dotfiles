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
  name = "conda";

  group = "dev";
  input = "common";
  namespace = "home";

  defaults = {
    withPkgInstall = false;
  };

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = lib.mkIf (self.isLinux && self.settings.withPkgInstall) (
        with pkgs;
        [
          conda
        ]
      );

      home.file."${config.xdg.configHome}/fish-init/60-conda.fish".text = ''
        if command -q conda
        ${
          if self.isDarwin then
            ''
              if test -f /opt/homebrew/Caskroom/miniconda/base/bin/conda
                  eval /opt/homebrew/Caskroom/miniconda/base/bin/conda "shell.fish" "hook" $argv | source
              else
                  if test -f "/opt/homebrew/Caskroom/miniconda/base/etc/fish/conf.d/conda.fish"
                      . "/opt/homebrew/Caskroom/miniconda/base/etc/fish/conf.d/conda.fish"
                  else
                      set -x PATH "/opt/homebrew/Caskroom/miniconda/base/bin" $PATH
                  end
              end
            ''
          else
            ''
              if test -f "$HOME/.conda/etc/fish/conf.d/conda.fish"
                  . "$HOME/.conda/etc/fish/conf.d/conda.fish"
              else
                  set -x PATH "$HOME/.conda/bin" $PATH
              end
            ''
        }
        ${lib.optionalString self.isDarwin "else\n  echo 'Install conda on Mac with: brew install --cask miniconda'"}
        end
      '';

      home.file."${config.xdg.configHome}/fish-init/65-conda-path-fix.fish" =
        lib.mkIf (self.isModuleEnabled "nvim-modules.toggleterm")
          {
            text = ''
              function __nvim_fix_conda_path --on-variable CONDA_DEFAULT_ENV
                if test -n "$CONDA_DEFAULT_ENV" -a "$CONDA_DEFAULT_ENV" != "base" -a -n "$CONDA_PREFIX"
                  set -l conda_bin "$CONDA_PREFIX/bin"
                  if test -d "$conda_bin"
                    if not string match -q "$conda_bin" $PATH[1]
                      set -l new_path
                      for p in $PATH
                        if test "$p" != "$conda_bin"
                          set new_path $new_path $p
                        end
                      end
                      set -gx PATH $conda_bin $new_path
                    end
                  end
                end
              end

              __nvim_fix_conda_path
            '';
          };

      home.file.".config/nvim-init/70-toggleterm-conda-fix.lua" =
        lib.mkIf (self.isModuleEnabled "nvim-modules.toggleterm")
          {
            text = ''
              local function setup_conda_fix()
                local toggleterm_ok, toggleterm = pcall(require, "toggleterm")
                if not toggleterm_ok then
                  return
                end

                local original_spawn = require("toggleterm.terminal").Terminal.spawn

                require("toggleterm.terminal").Terminal.spawn = function(self)
                  local conda_env = vim.env.CONDA_DEFAULT_ENV
                  local conda_prefix = vim.env.CONDA_PREFIX

                  if conda_env and conda_prefix and conda_env ~= "base" then
                    local conda_bin = conda_prefix .. "/bin"
                    local stat = vim.loop.fs_stat(conda_bin)

                    if stat then
                      local path = vim.env.PATH or ""
                      if not path:match("^" .. vim.pesc(conda_bin)) then
                        local new_path = path:gsub(vim.pesc(conda_bin) .. ":?", "")
                        vim.env.PATH = conda_bin .. ":" .. new_path
                      end
                    end
                  end

                  return original_spawn(self)
                end
              end

              vim.api.nvim_create_autocmd("VimEnter", {
                pattern = "*",
                callback = function()
                  vim.defer_fn(setup_conda_fix, 100)
                end,
              })
            '';
          };

      home.persistence."${self.persist}" = lib.mkIf self.isLinux {
        directories = [
          ".conda"
        ];
        files = [
          ".condarc"
        ];
      };
    };
}
