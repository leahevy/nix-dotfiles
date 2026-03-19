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
  name = "minuet";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    provider = "openai_fim_compatible";
    model = "qwen2.5-coder:7b";
    endpoint = "http://localhost:11434/v1/completions";
    cpuOptimised = false;
    n_completions = 1;
    context_window = 1024;
    context_ratio = 0.5;
    max_tokens = 50;
    temperature = 0.4;
    top_p = 0.8;
    debounce = 30;
    throttle = 30;
    multilineCompletion = false;
    additionalStopCharacters = [ ];
    request_timeout = 30;
    baseFiletypesToEnable = [
      "nix"
      "python"
      "rust"
      "go"
      "javascript"
      "typescript"
      "lua"
      "c"
      "cpp"
      "c_sharp"
      "haskell"
      "ruby"
      "scala"
      "swift"
      "r"
      "matlab"
      "objc"
      "solidity"
      "html"
      "css"
      "scss"
      "graphql"
      "bash"
      "fish"
      "powershell"
      "vim"
      "dockerfile"
      "terraform"
      "cmake"
      "make"
      "asm"
      "nasm"
      "glsl"
      "sql"
      "proto"
      "groovy"
    ];
    additionalFiletypesToEnable = [ ];
  };

  assertions = [
    {
      assertion = !(self.isModuleEnabled "nvim-modules.copilot");
      message = "minuet and copilot modules are mutually exclusive!";
    }
    {
      assertion = (self.isModuleEnabled "services.ollama") || (self.darwin.isModuleEnabled "dev.ollama");
      message = "minuet requires either common services.ollama or darwin dev.ollama to be enabled!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    let
      allFiletypes = self.settings.baseFiletypesToEnable ++ self.settings.additionalFiletypesToEnable;
      theme = config.nx.preferences.theme;
      stopCharacters =
        (lib.optionals (!self.settings.multilineCompletion) [
          "\n"
          "\r"
        ])
        ++ self.settings.additionalStopCharacters;

      ollamaConfig =
        if self.isModuleEnabled "services.ollama" then self.getModuleConfig "services.ollama" else null;

      effectiveModel = if ollamaConfig != null then ollamaConfig.codingModel else self.settings.model;

      effectiveEndpoint =
        if ollamaConfig != null then
          "http://${ollamaConfig.host}:${toString ollamaConfig.port}/v1/completions"
        else
          self.settings.endpoint;

      cpuMultiplier =
        attr: multiplier:
        if self.settings.cpuOptimised then
          builtins.floor (self.settings.${attr} * multiplier)
        else
          self.settings.${attr};

      effectiveContextWindow = cpuMultiplier "context_window" 0.5;
      effectiveMaxTokens = cpuMultiplier "max_tokens" 0.6;
      effectiveDebounce = cpuMultiplier "debounce" 5;
      effectiveThrottle = cpuMultiplier "throttle" 3;
    in
    {
      programs.nixvim = {
        plugins.minuet = {
          enable = true;
          settings = {
            provider = self.settings.provider;
            n_completions = self.settings.n_completions;
            context_window = effectiveContextWindow;
            context_ratio = self.settings.context_ratio;
            request_timeout = self.settings.request_timeout;
            debounce = effectiveDebounce;
            throttle = effectiveThrottle;
            virtualtext = {
              auto_trigger_ft = allFiletypes;
              keymap = {
                accept = false;
                accept_line = false;
                accept_n_lines = false;
                prev = false;
                next = false;
                dismiss = false;
              };
            };
            provider_options = {
              openai_fim_compatible = {
                api_key = "TERM";
                name = "Ollama";
                end_point = effectiveEndpoint;
                model = effectiveModel;
                optional = {
                  max_tokens = effectiveMaxTokens;
                  temperature = self.settings.temperature;
                  top_p = self.settings.top_p;
                }
                // lib.optionalAttrs (stopCharacters != [ ]) {
                  stop = stopCharacters;
                };
              };
            };
          };
        };

        keymaps = [
          {
            mode = "i";
            key = "<Tab>";
            action.__raw = ''
              function()
                local vt = require('minuet.virtualtext')
                if vt.action.is_visible() then
                  vt.action.accept()
                else
                  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Tab>', true, false, true), 'n', false)
                end
              end
            '';
            options = {
              desc = "Accept Minuet suggestion";
              silent = true;
              expr = false;
            };
          }
          {
            mode = "i";
            key = "<M-Tab>";
            action.__raw = ''
              function()
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Tab>', true, false, true), 'n', false)
              end
            '';
            options = {
              desc = "Insert tab (fallback)";
              silent = true;
              expr = false;
            };
          }
          {
            mode = "n";
            key = "<leader>cq";
            action = ":lua _G.toggle_minuet_manual()<CR>";
            options = {
              desc = "Toggle Minuet";
              silent = false;
            };
          }
        ];

        autoCmd = lib.mkIf (self.isModuleEnabled "nvim-modules.vimwiki") [
          {
            event = [ "BufEnter" ];
            pattern = [ "*.md" ];
            callback.__raw = ''
              function()
                if vim.bo.filetype == "vimwiki" then
                  vim.defer_fn(function()
                    vim.keymap.set('i', '<Tab>',
                      function()
                        local vt = require('minuet.virtualtext')
                        if vt.action.is_visible() then
                          vt.action.accept()
                        else
                          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Tab>', true, false, true), 'n', false)
                        end
                      end,
                      { buffer = 0, desc = "Accept Minuet suggestion", silent = true }
                    )
                  end, 10)
                end
              end
            '';
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<Tab>";
            desc = "Accept Minuet suggestion or tab";
            icon = "🤖";
          }
          {
            __unkeyed-1 = "<M-Tab>";
            desc = "Insert tab (fallback)";
            icon = "->";
          }
          {
            __unkeyed-1 = "<leader>cq";
            desc = "Toggle Minuet";
            icon = "🤖";
          }
        ];

        extraConfigLua = ''
          _G.nx_modules = _G.nx_modules or {}
          _G.nx_modules["50-minuet-filetypes"] = function()
            vim.api.nvim_set_hl(0, "MinuetVirtualText", { fg = "${theme.colors.terminal.foregrounds.dim.html}", italic = true })

            local minuet_filetypes = {
              ${lib.concatStringsSep ",\n          " (map (ft: "\"${ft}\"") allFiletypes)}
            }

            local minuet_ft_set = {}
            for _, ft in ipairs(minuet_filetypes) do
              minuet_ft_set[ft] = true
            end

            local function has_manual_override(bufnr)
              return vim.b[bufnr].minuet_manual_override == true
            end

            local toggle_timer = nil
            local last_notified_state = nil

            local function toggle_minuet_for_filetype()
              if toggle_timer then
                vim.fn.timer_stop(toggle_timer)
                toggle_timer = nil
              end

              toggle_timer = vim.fn.timer_start(100, function()
                toggle_timer = nil

                local bufnr = vim.api.nvim_get_current_buf()
                local current_ft = vim.api.nvim_buf_get_option(bufnr, 'filetype')
                local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')

                if buftype == "prompt" or buftype == "nofile" or current_ft == "TelescopePrompt" then
                  return
                end

                if has_manual_override(bufnr) then
                  return
                end

                local should_be_enabled = minuet_ft_set[current_ft] == true
                local current_state = vim.g.minuet_enabled == true

                if should_be_enabled ~= current_state then
                  if should_be_enabled then
                    vim.b.minuet_virtual_text_auto_trigger = true
                    vim.g.minuet_enabled = true
                    if last_notified_state ~= true then
                      vim.defer_fn(function()
                        if current_ft == "" then
                          current_ft = "current buffer"
                        end
                        vim.notify('Auto-enabled for ' .. current_ft, vim.log.levels.INFO, {
                          icon = '✅',
                          title = 'Minuet'
                        })
                      end, 200)
                      last_notified_state = true
                    end
                  else
                    vim.b.minuet_virtual_text_auto_trigger = false
                    vim.g.minuet_enabled = false
                    if last_notified_state ~= false then
                      vim.defer_fn(function()
                        if current_ft == "" then
                          current_ft = "current buffer"
                        end
                        vim.notify('Auto-disabled for ' .. current_ft, vim.log.levels.INFO, {
                          icon = '⚠️',
                          title = 'Minuet'
                        })
                      end, 200)
                      last_notified_state = false
                    end
                  end
                  ${lib.optionalString (self.isModuleEnabled "nvim-modules.cmp") "_G.refresh_cmp_autocomplete()"}
                end
              end)
            end

            function _G.toggle_minuet_manual()
              if toggle_timer then
                vim.fn.timer_stop(toggle_timer)
                toggle_timer = nil
              end

              local bufnr = vim.api.nvim_get_current_buf()
              local current_ft = vim.api.nvim_buf_get_option(bufnr, 'filetype')

              local current_state = vim.g.minuet_enabled == true

              if current_state then
                vim.b[bufnr].minuet_virtual_text_auto_trigger = false
                vim.g.minuet_enabled = false
                vim.notify('Manually disabled', vim.log.levels.INFO, {
                  icon = '❌',
                  title = 'Minuet'
                })
                last_notified_state = false
                vim.b[bufnr].minuet_manual_override = true
                vim.b[bufnr].minuet_manual_state = false
                vim.b[bufnr].minuet_force_enable = false
              else
                vim.b[bufnr].minuet_virtual_text_auto_trigger = true
                vim.g.minuet_enabled = true
                vim.notify('Manually enabled', vim.log.levels.INFO, {
                  icon = '✅',
                  title = 'Minuet'
                })
                last_notified_state = true
                vim.b[bufnr].minuet_manual_override = true
                vim.b[bufnr].minuet_manual_state = true

                if not minuet_ft_set[current_ft] then
                  vim.b[bufnr].minuet_force_enable = true
                end
              end
              ${lib.optionalString (self.isModuleEnabled "nvim-modules.cmp") "_G.refresh_cmp_autocomplete()"}
            end

            vim.api.nvim_create_autocmd({
              "FileType", "BufEnter", "WinEnter", "TabEnter",
              "BufWinEnter", "WinNew", "TabNew", "FocusGained"
            }, {
              pattern = "*",
              callback = function()
                local bufnr = vim.api.nvim_get_current_buf()

                if vim.b[bufnr].minuet_force_enable then
                  vim.defer_fn(function()
                    vim.b[bufnr].minuet_virtual_text_auto_trigger = true
                    vim.g.minuet_enabled = true
                  end, 50)
                else
                  vim.defer_fn(toggle_minuet_for_filetype, 50)
                end
              end,
              desc = "Enable/disable Minuet based on filetype"
            })

            vim.api.nvim_create_autocmd("VimEnter", {
              callback = function()
                vim.defer_fn(toggle_minuet_for_filetype, 200)
              end,
              desc = "Initial Minuet filetype check on startup"
            })
          end
        '';
      };
    };
}
