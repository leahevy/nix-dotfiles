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
  name = "neotest";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  submodules = {
    common = {
      nvim-modules = {
        treesitter = true;
        lsp = true;
      };
    };
  };

  settings = {
    adapters = {
      python = {
        enabled = true;
        runner = "pytest";
        args = [
          "--tb=long"
          "-v"
        ];
      };
      rust = {
        enabled = true;
        args = [ "--no-capture" ];
      };
      jest = {
        enabled = true;
        jestCommand = "npm test --";
      };
    };

    projects = { };
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.neotest = {
          enable = true;

          adapters = {
            python = {
              enable = self.settings.adapters.python.enabled;
              settings = {
                dap.justMyCode = true;
                args = self.settings.adapters.python.args;
                runner = self.settings.adapters.python.runner;
                python.__raw = ''
                  function()
                    local function find_interpreter(base_name)
                      local candidates = {}

                      local conda_prefix = os.getenv("CONDA_PREFIX")
                      if conda_prefix then
                        table.insert(candidates, conda_prefix .. "/bin/" .. base_name)
                      end

                      local venv_prefix = os.getenv("VIRTUAL_ENV")
                      if venv_prefix then
                        table.insert(candidates, venv_prefix .. "/bin/" .. base_name)
                      end

                      local home = os.getenv("HOME")
                      if home then
                        table.insert(candidates, home .. "/.nix-profile/bin/" .. base_name)
                      end

                      local user = os.getenv("USER")
                      if user then
                        table.insert(candidates, "/etc/profiles/per-user/" .. user .. "/bin/" .. base_name)
                      end

                      table.insert(candidates, base_name)

                      for _, candidate in ipairs(candidates) do
                        if vim.fn.executable(candidate) == 1 then
                          return candidate
                        end
                      end

                      return base_name
                    end

                    local python = find_interpreter("python3")
                    if python == "python3" then
                      python = find_interpreter("python")
                    end
                    return python
                  end
                '';
              };
            };

            rust = {
              enable = self.settings.adapters.rust.enabled;
              settings = {
                args = self.settings.adapters.rust.args;
                dapAdapter = "lldb-vscode";
              };
            };

            jest = {
              enable = self.settings.adapters.jest.enabled;
              settings = {
                jestCommand.__raw = ''
                  function(path)
                    local function find_node_interpreter(base_name)
                      local candidates = {}

                      local nvm_prefix = os.getenv("NVM_BIN")
                      if nvm_prefix then
                        table.insert(candidates, nvm_prefix .. "/" .. base_name)
                      end

                      local home = os.getenv("HOME")
                      if home then
                        table.insert(candidates, home .. "/.nix-profile/bin/" .. base_name)
                        table.insert(candidates, home .. "/.local/bin/" .. base_name)
                      end

                      local user = os.getenv("USER")
                      if user then
                        table.insert(candidates, "/etc/profiles/per-user/" .. user .. "/bin/" .. base_name)
                      end

                      local cwd = vim.fn.getcwd()
                      table.insert(candidates, cwd .. "/node_modules/.bin/" .. base_name)

                      table.insert(candidates, base_name)

                      for _, candidate in ipairs(candidates) do
                        if vim.fn.executable(candidate) == 1 then
                          return candidate
                        end
                      end

                      return base_name
                    end

                    local cwd = vim.fn.getcwd()
                    if string.find(cwd, "monorepo") then
                      local yarn = find_node_interpreter("yarn")
                      return yarn .. " workspace " .. vim.fn.fnamemodify(path, ":h:t") .. " test"
                    end

                    local npm = find_node_interpreter("npm")
                    return npm .. " test --"
                  end
                '';
                jestConfigFile.__raw = ''
                  function(file)
                    if string.find(file, "/packages/") then
                      local match = string.match(file, "(.*/[^/]+/)src")
                      if match then
                        return match .. "jest.config.ts"
                      end
                    end
                    local jest_config_ts = vim.fn.getcwd() .. "/jest.config.ts"
                    if vim.fn.filereadable(jest_config_ts) == 1 then
                      return jest_config_ts
                    end
                    return vim.fn.getcwd() .. "/jest.config.js"
                  end
                '';
                cwd.__raw = ''
                  function(path)
                    if string.find(path, "/packages/") then
                      local match = string.match(path, "(.*/[^/]+/)src")
                      if match then
                        return match
                      end
                    end
                    return vim.fn.getcwd()
                  end
                '';
                env = {
                  CI = "true";
                };
              };
            };
          };

          settings = {
            consumers = lib.mkIf (self.isModuleEnabled "nvim-modules.overseer") {
              overseer.__raw = ''require("neotest.consumers.overseer")'';
            };

            default_strategy =
              if (self.isModuleEnabled "nvim-modules.overseer") then "overseer" else "integrated";

            discovery = {
              enabled = true;
              concurrent = 1;
            };

            diagnostic = {
              enabled = true;
              severity = 1;
            };

            floating = {
              border = "rounded";
              max_height = 0.6;
              max_width = 0.8;
              options = {
                winblend = 0;
              };
            };

            highlights = {
              adapter_name = "NeotestAdapterName";
              border = "NeotestBorder";
              dir = "NeotestDir";
              expand_marker = "NeotestExpandMarker";
              failed = "NeotestFailed";
              file = "NeotestFile";
              focused = "NeotestFocused";
              indent = "NeotestIndent";
              marked = "NeotestMarked";
              namespace = "NeotestNamespace";
              passed = "NeotestPassed";
              running = "NeotestRunning";
              select_win = "NeotestWinSelect";
              skipped = "NeotestSkipped";
              target = "NeotestTarget";
              test = "NeotestTest";
              unknown = "NeotestUnknown";
              watching = "NeotestWatching";
            };

            icons = {
              passed = "✔";
              running = "🗘";
              failed = "✖";
              unknown = "?";
              running_animated = [
                "⠋"
                "⠙"
                "⠹"
                "⠸"
                "⠼"
                "⠴"
                "⠦"
                "⠧"
                "⠇"
                "⠏"
              ];
              watching = "👁";
              child_indent = "│";
              child_prefix = "├";
              collapsed = "─";
              expanded = "╮";
              final_child_indent = " ";
              final_child_prefix = "╰";
              non_collapsible = "─";
              skipped = "ﰸ";
            };

            jump = {
              enabled = true;
            };

            log_level = "warn";

            output = {
              enabled = true;
              open_on_run = !(self.isModuleEnabled "nvim-modules.overseer");
            };

            output_panel = {
              enabled = true;
              open = "botright split | resize 15";
            };

            projects = self.settings.projects;

            quickfix = {
              enabled = true;
              open = false;
            };

            run = {
              enabled = true;
            };

            running = {
              concurrent = true;
            };

            state = {
              enabled = true;
            };

            status = {
              enabled = true;
              virtual_text = true;
              signs = true;
            };

            strategies = {
              integrated = {
                width = 120;
                height = 40;
              };
            }
            // lib.optionalAttrs (self.isModuleEnabled "nvim-modules.overseer") {
              overseer = {
                components.__raw = ''
                  {
                    { "display_duration", detail_level = 2 },
                    "on_output_summarize",
                    "on_exit_set_status",
                    "nx.custom_notify",
                    { "open_output", direction = "horizontal", on_start = "always", on_complete = "failure", focus = false },
                    { "on_complete_dispose", require_view = { "FAILURE" }, statuses = { "SUCCESS", "FAILURE", "CANCELED" }, timeout = 10800 },
                  }
                '';
              };
            };

            summary = {
              animated = true;
              enabled = true;
              expand_errors = true;
              follow = true;
              mappings = {
                attach = "a";
                clear_marked = "M";
                clear_target = "T";
                debug = "d";
                debug_marked = "D";
                expand = [
                  "<CR>"
                  "<2-LeftMouse>"
                ];
                expand_all = "e";
                jumpto = "i";
                mark = "m";
                next_failed = "J";
                output = "o";
                prev_failed = "K";
                run = "r";
                run_marked = "R";
                short = "O";
                stop = "u";
                target = "t";
                watch = "w";
              };
              open = "botright vsplit | vertical resize 50";
            };

            watch = {
              enabled = true;
            };
          };
        };

        extraConfigLua = ''
          _G.nx_modules = _G.nx_modules or {}
          _G.nx_modules["40-neotest-highlights"] = function()
            vim.api.nvim_create_autocmd("ColorScheme", {
              pattern = "*",
              callback = function()
                vim.api.nvim_set_hl(0, "NeotestPassed", { fg = "${self.theme.colors.semantic.success.html}" })
                vim.api.nvim_set_hl(0, "NeotestFailed", { fg = "${self.theme.colors.semantic.error.html}" })
                vim.api.nvim_set_hl(0, "NeotestRunning", { fg = "${self.theme.colors.semantic.warning.html}" })
                vim.api.nvim_set_hl(0, "NeotestSkipped", { fg = "${self.theme.colors.separators.light.html}" })
                vim.api.nvim_set_hl(0, "NeotestUnknown", { fg = "${self.theme.colors.separators.normal.html}" })
                vim.api.nvim_set_hl(0, "NeotestWatching", { fg = "${self.theme.colors.semantic.info.html}" })
              end,
            })
          end

          _G.nx_modules["41-neotest-summary-keymap"] = function()
            vim.api.nvim_create_autocmd("FileType", {
              pattern = "neotest-summary",
              callback = function()
                vim.api.nvim_buf_set_keymap(0, 'n', 'q', '<cmd>close<CR>', { noremap = true, silent = true })
              end,
            })
          end

          ${lib.optionalString (self.isModuleEnabled "nvim-modules.telescope") ''
            _G.nx_modules["42-neotest-telescope"] = function()
              _G.nx_neotest_pick_and_run = function()
                local neotest = require('neotest')

                require('telescope.builtin').find_files({
                  prompt_title = "Select test file to run",
                  cwd = vim.fn.getcwd(),
                  find_command = { "find", ".", "-type", "f", "(",
                    "-name", "test_*.py", "-o",
                    "-name", "*_test.py", "-o",
                    "-name", "test*.py", "-o",
                    "-name", "*test.py", "-o",
                    "-name", "*.test.js", "-o",
                    "-name", "*.spec.js", "-o",
                    "-name", "test*.js", "-o",
                    "-name", "*test.js", "-o",
                    "-name", "*.test.ts", "-o",
                    "-name", "*.spec.ts", "-o",
                    "-name", "test*.ts", "-o",
                    "-name", "*test.ts", "-o",
                    "-name", "*_test.rs", "-o",
                    "-name", "test*.rs", "-o",
                    "-name", "*test.rs", "-o",
                    "-path", "*/tests/*.rs",
                  ")" },
                  attach_mappings = function(_, map)
                    map("i", "<CR>", function(prompt_bufnr)
                      local selection = require('telescope.actions.state').get_selected_entry()
                      require('telescope.actions').close(prompt_bufnr)

                      local file_path = selection.path or selection.value
                      local absolute_path = vim.fn.fnamemodify(file_path, ":p")

                      vim.notify("Running tests in: " .. vim.fn.fnamemodify(file_path, ":t"), vim.log.levels.INFO, {
                        icon = "🧪",
                        title = "Neotest"
                      })

                      neotest.run.run(absolute_path)
                    end)
                    return true
                  end
                })
              end
            end
          ''}
        '';

        keymaps = [
          {
            mode = "n";
            key = "<leader>Tt";
            action.__raw = ''function() require("neotest").run.run() end'';
            options = {
              desc = "Run nearest test";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>TT";
            action.__raw = ''function() require("neotest").run.run(vim.fn.expand("%")) end'';
            options = {
              desc = "Run test file";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>Ta";
            action.__raw = ''function() require("neotest").run.run(vim.loop.cwd()) end'';
            options = {
              desc = "Run all tests";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>Tl";
            action.__raw = ''function() require("neotest").run.run_last() end'';
            options = {
              desc = "Run last test";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>Td";
            action.__raw = ''function() require("neotest").run.run({strategy = "dap"}) end'';
            options = {
              desc = "Debug nearest test";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>Ts";
            action.__raw = ''function() require("neotest").run.stop() end'';
            options = {
              desc = "Stop test";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>To";
            action.__raw = ''function() require("neotest").output.open({ enter = true, auto_close = true }) end'';
            options = {
              desc = "Show test output";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>TO";
            action.__raw = ''function() require("neotest").output_panel.toggle() end'';
            options = {
              desc = "Toggle output panel";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>TS";
            action.__raw = ''function() require("neotest").summary.toggle() end'';
            options = {
              desc = "Toggle summary";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "[T";
            action.__raw = ''function() require("neotest").jump.prev({ status = "failed" }) end'';
            options = {
              desc = "Jump to previous failed test";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "]T";
            action.__raw = ''function() require("neotest").jump.next({ status = "failed" }) end'';
            options = {
              desc = "Jump to next failed test";
              silent = true;
            };
          }
        ]
        ++ lib.optionals (self.isModuleEnabled "nvim-modules.telescope") [
          {
            mode = "n";
            key = "<leader>Tp";
            action.__raw = ''function() _G.nx_neotest_pick_and_run() end'';
            options = {
              desc = "Pick test file to run";
              silent = true;
            };
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") (
          [
            {
              __unkeyed-1 = "<leader>T";
              group = "test";
              icon = "󰙨";
            }
            {
              __unkeyed-1 = "<leader>Tt";
              desc = "Run nearest test";
              icon = "▶";
            }
            {
              __unkeyed-1 = "<leader>TT";
              desc = "Run test file";
              icon = "📄";
            }
            {
              __unkeyed-1 = "<leader>Ta";
              desc = "Run all tests";
              icon = "🔄";
            }
            {
              __unkeyed-1 = "<leader>Tl";
              desc = "Run last test";
              icon = "⏮";
            }
            {
              __unkeyed-1 = "<leader>Td";
              desc = "Debug nearest test";
              icon = "🐛";
            }
            {
              __unkeyed-1 = "<leader>Ts";
              desc = "Stop test";
              icon = "⏹";
            }
            {
              __unkeyed-1 = "<leader>To";
              desc = "Show test output";
              icon = "📋";
            }
            {
              __unkeyed-1 = "<leader>TO";
              desc = "Toggle output panel";
              icon = "📊";
            }
            {
              __unkeyed-1 = "<leader>TS";
              desc = "Toggle summary";
              icon = "📑";
            }
            {
              __unkeyed-1 = "[T";
              desc = "Previous failed test";
              icon = "⬆";
            }
            {
              __unkeyed-1 = "]T";
              desc = "Next failed test";
              icon = "⬇";
            }
          ]
          ++ lib.optionals (self.isModuleEnabled "nvim-modules.telescope") [
            {
              __unkeyed-1 = "<leader>Tp";
              desc = "Pick test file to run";
              icon = "🔎";
            }
          ]
        );
      };
    };
}
