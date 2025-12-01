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
  name = "dap";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    configurations = {
      python = [
        {
          type = "python";
          request = "attach";
          connect = {
            host = "127.0.0.1";
            port = 5678;
          };
          pathMappings = [
            {
              localRoot = "\${workspaceFolder}";
              remoteRoot = ".";
            }
          ];
        }
      ];
    };

    debugServers = {
      python = {
        port = 5678;
        interpreter = "python3";
        commandTemplate = "{interpreter} -m debugpy --listen localhost:{port} --wait-for-client {file}";
        fileExtension = "*.py";
      };
    };

    signs = {
      breakpoint = "●";
      stopped = "→";
      breakpointCondition = "◆";
      breakpointRejected = "◌";
      logPoint = "◉";
      breakpointColor = "#ff8c00";
    };

    ui = {
      autoOpen = true;
      autoClose = true;
    };
  };

  configuration =
    context@{ config, options, ... }:
    let
      capitalize =
        str:
        let
          firstChar = lib.toUpper (lib.substring 0 1 str);
          rest = lib.substring 1 (-1) str;
        in
        firstChar + rest;

      generateName =
        config:
        let
          baseType = capitalize config.type;
          baseRequest = capitalize config.request;
          baseName = "${baseRequest} to ${baseType}";
        in
        if config ? description then "${baseName} (${config.description})" else baseName;

      addNames =
        configs:
        lib.mapAttrs (
          name: configList: map (config: config // { name = generateName config; }) configList
        ) configs;

      configurationsWithNames = addNames self.settings.configurations;

      filterByType =
        targetType: configs:
        lib.filterAttrs (name: configList: lib.any (config: config.type == targetType) configList) configs;

    in
    {
      programs.nixvim = {
        plugins = {
          dap = {
            enable = true;

            signs = {
              dapBreakpoint = {
                text = self.settings.signs.breakpoint;
                texthl = "DapBreakpoint";
                linehl = null;
                numhl = null;
              };
              dapBreakpointCondition = {
                text = self.settings.signs.breakpointCondition;
                texthl = "DapBreakpointCondition";
                linehl = null;
                numhl = null;
              };
              dapBreakpointRejected = {
                text = self.settings.signs.breakpointRejected;
                texthl = "DapBreakpointRejected";
                linehl = null;
                numhl = null;
              };
              dapLogPoint = {
                text = self.settings.signs.logPoint;
                texthl = "DapLogPoint";
                linehl = null;
                numhl = null;
              };
              dapStopped = {
                text = self.settings.signs.stopped;
                texthl = "DapStopped";
                linehl = "DapStoppedLine";
                numhl = null;
              };
            };

            configurations = configurationsWithNames;
          };

          dap-ui = {
            enable = true;
            settings = {
              controls = {
                element = "repl";
                enabled = true;
                icons = {
                  disconnect = "⏏";
                  pause = "⏸";
                  play = "▶";
                  run_last = "⏮";
                  step_back = "↶";
                  step_into = "↓";
                  step_out = "↑";
                  step_over = "⏭";
                  terminate = "⏹";
                };
              };
              element_mappings = { };
              expand_lines = true;
              floating = {
                border = "single";
                mappings = {
                  close = [
                    "q"
                    "<Esc>"
                  ];
                };
              };
              force_buffers = true;
              icons = {
                collapsed = "▶";
                current_frame = "▶";
                expanded = "▼";
              };
              layouts = [
                {
                  elements = [
                    {
                      id = "scopes";
                      size = 0.25;
                    }
                    {
                      id = "breakpoints";
                      size = 0.25;
                    }
                    {
                      id = "stacks";
                      size = 0.25;
                    }
                    {
                      id = "watches";
                      size = 0.25;
                    }
                  ];
                  position = "left";
                  size = 40;
                }
                {
                  elements = [
                    {
                      id = "repl";
                      size = 0.5;
                    }
                    {
                      id = "console";
                      size = 0.5;
                    }
                  ];
                  position = "bottom";
                  size = 10;
                }
              ];
              mappings = {
                edit = "e";
                expand = [
                  "<CR>"
                  "<2-LeftMouse>"
                ];
                open = "o";
                remove = "d";
                repl = "r";
                toggle = "t";
              };
              render = {
                indent = 1;
                max_value_lines = 100;
              };
            };
          };

          dap-virtual-text = {
            enable = true;
            settings = {
              enabled = true;
              enabled_commands = true;
              highlight_changed_variables = true;
              highlight_new_as_changed = true;
              show_stop_reason = true;
              commented = true;
              only_first_definition = true;
              all_references = true;
              clear_on_continue = false;
              virt_text_pos = "inline";
              all_frames = false;
              virt_lines = false;
              display_callback.__raw = ''
                function(variable, buf, stackframe, node, options)
                  if options.virt_text_pos == 'inline' then
                    return ' = ' .. variable.value:gsub("%s+", " ")
                  else
                    return variable.name .. ' = ' .. variable.value:gsub("%s+", " ")
                  end
                end
              '';
            };
          };

          dap-python = {
            enable = true;
            settings = {
              console = "integratedTerminal";
              justMyCode = true;
            };
          };

          dap-lldb = {
            enable = true;
            settings = {
              configurations = filterByType "lldb" configurationsWithNames;
            };
          };

        };

        keymaps = [
          {
            mode = "n";
            key = "<leader>DD";
            action.__raw = "function() _G.nx_dap_toggle_breakpoint() end";
            options = {
              desc = "Toggle breakpoint";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>Dc";
            action.__raw = "function() _G.nx_dap_continue() end";
            options = {
              desc = "Continue/Start debugging";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>Dn";
            action.__raw = "function() require('dap').step_over() end";
            options = {
              desc = "Step over (next)";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>Di";
            action.__raw = "function() require('dap').step_into() end";
            options = {
              desc = "Step into";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>Do";
            action.__raw = "function() require('dap').step_out() end";
            options = {
              desc = "Step out";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>Du";
            action.__raw = "function() require('dapui').toggle() end";
            options = {
              desc = "Toggle DAP UI";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>Dr";
            action.__raw = "function() require('dap').repl.open() end";
            options = {
              desc = "Open REPL";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>Da";
            action.__raw = "function() require('dap').continue() end";
            options = {
              desc = "Attach to process";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>Dd";
            action.__raw = "function() _G.nx_dap_disconnect() end";
            options = {
              desc = "Disconnect/Stop debugging";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>Dl";
            action.__raw = "function() require('dap').list_breakpoints() end";
            options = {
              desc = "List breakpoints";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>Dx";
            action.__raw = "function() _G.nx_dap_clear_breakpoints() end";
            options = {
              desc = "Clear all breakpoints";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>Ds";
            action.__raw = "function() _G.nx_dap_start_server() end";
            options = {
              desc = "Start debug server";
              silent = true;
            };
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") ([
          {
            __unkeyed-1 = "<leader>D";
            group = "Debugging";
            icon = "🐛";
          }
          {
            __unkeyed-1 = "<leader>DD";
            desc = "Toggle breakpoint";
            icon = "●";
          }
          {
            __unkeyed-1 = "<leader>Dc";
            desc = "Continue/Start debugging";
            icon = "▶";
          }
          {
            __unkeyed-1 = "<leader>Dn";
            desc = "Step over (next)";
            icon = "⤵";
          }
          {
            __unkeyed-1 = "<leader>Di";
            desc = "Step into";
            icon = "⤴";
          }
          {
            __unkeyed-1 = "<leader>Do";
            desc = "Step out";
            icon = "↩";
          }
          {
            __unkeyed-1 = "<leader>Du";
            desc = "Toggle DAP UI";
            icon = "⇄";
          }
          {
            __unkeyed-1 = "<leader>Dr";
            desc = "Open REPL";
            icon = "→";
          }
          {
            __unkeyed-1 = "<leader>Da";
            desc = "Attach to process";
            icon = "↗";
          }
          {
            __unkeyed-1 = "<leader>Dd";
            desc = "Disconnect/Stop";
            icon = "⏹";
          }
          {
            __unkeyed-1 = "<leader>Dl";
            desc = "List breakpoints";
            icon = "↓";
          }
          {
            __unkeyed-1 = "<leader>Dx";
            desc = "Clear all breakpoints";
            icon = "×";
          }
          {
            __unkeyed-1 = "<leader>Ds";
            desc = "Start debug server";
            icon = "🚀";
          }
        ]);

        extraConfigLua = ''
          _G.nx_modules = _G.nx_modules or {}
          _G.nx_modules["50-dap"] = function()
            vim.api.nvim_set_hl(0, "DapBreakpoint", { fg = "${self.settings.signs.breakpointColor}" })
            local dap = require('dap')
            local dapui = require('dapui')

            local debug_servers = ${lib.generators.toLua { } self.settings.debugServers}
            local configurations = ${lib.generators.toLua { } self.settings.configurations}

            _G.nx_find_interpreter = function(base_name)
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

            for ft, configs in pairs(configurations) do
              local server_config = debug_servers[ft]
              if server_config and configs[1] then
                local config_type = configs[1].type
                if server_config.interpreter then
                  local ok, dap_module = pcall(require, 'dap-' .. config_type)
                  if ok and dap_module.setup then
                    local resolved_interpreter = _G.nx_find_interpreter(server_config.interpreter)
                    dap_module.setup(resolved_interpreter)
                  end
                end
              end
            end

            local configurationsWithNames = ${lib.generators.toLua { } configurationsWithNames}
            for lang, configs in pairs(configurationsWithNames) do
              dap.configurations[lang] = configs
            end

            ${
              if self.settings.ui.autoOpen then
                ''
                  dap.listeners.before.attach.dapui_config = function()
                    dapui.open()
                    vim.notify('Session started', vim.log.levels.INFO, {
                      title = "Debugger"
                    })
                  end

                  dap.listeners.before.launch.dapui_config = function()
                    dapui.open()
                    vim.notify('Session started', vim.log.levels.INFO, {
                      title = "Debugger"
                    })
                  end
                ''
              else
                ""
            }

            ${
              if self.settings.ui.autoClose then
                ''
                  dap.listeners.before.event_terminated.dapui_config = function()
                    dapui.close()
                    vim.notify('Session ended', vim.log.levels.INFO, {
                      title = "Debugger"
                    })
                  end

                  dap.listeners.before.event_exited.dapui_config = function()
                    dapui.close()
                    vim.notify('Session ended', vim.log.levels.INFO, {
                      title = "Debugger"
                    })
                  end
                ''
              else
                ""
            }

            local function start_debug_server(filetype)
              if not pcall(require, 'telescope') then
                vim.notify('Telescope not available', vim.log.levels.ERROR, { title = "Debugger" })
                return
              end

              local overseer_available = pcall(require, 'overseer')

              local server_config = debug_servers[filetype]
              if not server_config then
                vim.notify('Filetype ' .. filetype .. ' is not configured', vim.log.levels.WARN, {
                  title = "Debugger"
                })
                return
              end

              require('telescope.builtin').find_files({
                prompt_title = "Select file for: " .. filetype,
                cwd = vim.fn.getcwd(),
                find_command = { "find", ".", "-name", server_config.fileExtension, "-type", "f" },
                attach_mappings = function(_, map)
                  map("i", "<CR>", function(prompt_bufnr)
                    local selection = require('telescope.actions.state').get_selected_entry()
                    require('telescope.actions').close(prompt_bufnr)

                    local file_path = selection.path or selection.value


                    local interpreter = _G.nx_find_interpreter(server_config.interpreter)
                    local cmd = server_config.commandTemplate
                      :gsub("{interpreter}", interpreter)
                      :gsub("{port}", tostring(server_config.port))
                      :gsub("{file}", file_path)

                    if overseer_available then
                      local overseer = require('overseer')
                      local task = overseer.new_task({
                        name = "Debug Server (" .. filetype .. ")",
                        cmd = { "/usr/bin/env", "bash", "-c", cmd },
                        env = vim.fn.environ(),
                        components = { "default", "on_output_summarize", "on_exit_set_status" }
                      })

                      task:start()
                      vim.notify('Debug server started as overseer task\nUsing: ' .. interpreter .. '\nCommand: ' .. cmd, vim.log.levels.INFO, {
                        title = "Debugger"
                      })
                    else
                      vim.cmd('terminal ' .. cmd)
                      vim.notify('Debug server started in terminal\nUsing: ' .. interpreter .. '\nCommand: ' .. cmd, vim.log.levels.INFO, {
                        title = "Debugger"
                      })
                    end
                  end)
                  return true
                end
              })
            end

            _G.nx_dap_toggle_breakpoint = function()
              require('dap').toggle_breakpoint()
              local line = vim.api.nvim_win_get_cursor(0)[1]
              vim.notify('Breakpoint toggled on line ' .. line, vim.log.levels.INFO, {
                title = "Debugger"
              })
            end

            _G.nx_dap_continue = function()
              if dap.session() then
                dap.continue()
              else
                vim.notify('Starting new debug session...', vim.log.levels.INFO, {
                  title = "Debugger"
                })
                dap.continue()
              end
            end

            _G.nx_dap_disconnect = function()
              require('dap').disconnect()
              vim.notify('Debug session disconnected', vim.log.levels.INFO, {
                title = "Debugger"
              })
            end

            _G.nx_dap_clear_breakpoints = function()
              require('dap').clear_breakpoints()
              vim.notify('All breakpoints cleared', vim.log.levels.INFO, {
                title = "Debugger"
              })
            end

            ${
              if self.isModuleEnabled "nvim-modules.overseer" then
                ''
                  _G.nx_dap_start_server = function()
                    local filetype = vim.bo.filetype
                    start_debug_server(filetype)
                  end
                ''
              else
                ""
            }
          end
        '';
      };
    };
}
