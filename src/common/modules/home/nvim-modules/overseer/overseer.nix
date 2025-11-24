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
  name = "overseer";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    enable = true;

    autoDetectSuccessColor = true;
    dapIntegration = true;
    defaultTaskStrategy = "terminal";

    templates = [
      "builtin"
    ];

    addExampleTask = false;
    exampleTask = {
      "hello_test" = {
        name = "Hello Test";
        cmd = "echo 'Hello from Overseer!'";
        cwd = "vim.fn.getcwd()";
        components = [ "default" ];
        condition = { };
      };
    };

    customTasks = {
      # Example:
      # "cpp_build" = {
      #   name = "g++ build";
      #   extraLuaCode = ''
      #     local file = vim.fn.expand("%:p")
      #     if not file or file == "" then
      #       vim.notify("No file to compile", vim.log.levels.ERROR)
      #       return nil
      #     end
      #   '';
      #   cmd = [ "g++" ];
      #   args = [ "vim.fn.expand('%:p')" ];
      #   cwd = "vim.fn.expand('%:p:h')";
      #   components = [ "default" ];
      #   condition = {
      #     filetype = [ "cpp" ];
      #   };
      # };
    };

    actions = { };

    taskList = {
      defaultDetail = 1;
      maxWidth = {
        __unkeyed-1 = 0.2;
        __unkeyed-2 = 0.4;
      };
      minWidth = {
        __unkeyed-1 = 40;
        __unkeyed-2 = 0.1;
      };
      width = null;
      maxHeight = {
        __unkeyed-1 = 0.3;
        __unkeyed-2 = 0.4;
      };
      minHeight = 8;
      height = null;
    };
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.overseer = {
          enable = self.settings.enable;
          settings = {
            auto_detect_success_color = self.settings.autoDetectSuccessColor;
            dap = self.settings.dapIntegration;
            strategy = self.settings.defaultTaskStrategy;
            templates = self.settings.templates;
            actions = self.settings.actions;
            task_list = self.settings.taskList;
          };
        };

        keymaps = [
          {
            mode = "n";
            key = "<leader><localleader>r";
            action = "<cmd>OverseerRun<CR>";
            options = {
              desc = "Run overseer task";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader><localleader>t";
            action = "<cmd>OverseerToggle<CR>";
            options = {
              desc = "Toggle overseer task list";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader><localleader>l";
            action = "<cmd>OverseerRestartLast<CR>";
            options = {
              desc = "Restart last task";
              silent = true;
            };
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<leader><localleader>";
            group = "Overseer";
            icon = "⚡";
          }
          {
            __unkeyed-1 = "<leader><localleader>r";
            desc = "Run overseer task";
            icon = "▶";
          }
          {
            __unkeyed-1 = "<leader><localleader>t";
            desc = "Toggle overseer task list";
            icon = "📋";
          }
          {
            __unkeyed-1 = "<leader><localleader>l";
            desc = "Restart last task";
            icon = "🔄";
          }
        ];
      };

      home.file.".config/nvim-init/80-overseer.lua".text = ''
        local overseer = require("overseer")

        overseer.setup()

        ${
          let
            allTasks =
              self.settings.customTasks
              // lib.optionalAttrs self.settings.addExampleTask self.settings.exampleTask;
          in
          lib.concatMapStringsSep "\n" (
            taskName:
            let
              baseTaskConfig = allTasks.${taskName};
              luaValue =
                let
                  stringValueToLua =
                    value: builtins.replaceStrings [ "$HOME" ] [ self.user.home ] (builtins.toJSON value);
                  toLua =
                    value:
                    if builtins.isString value then
                      (if lib.hasPrefix "vim." value then value else stringValueToLua value)
                    else if builtins.isList value then
                      "{ ${lib.concatMapStringsSep ", " (item: toLua item) value} }"
                    else if builtins.isAttrs value then
                      let
                        hasUnkeyed = builtins.hasAttr "__unkeyed-1" value;
                        unkeyedValue = if hasUnkeyed then value.__unkeyed-1 else null;
                        otherAttrs = if hasUnkeyed then builtins.removeAttrs value [ "__unkeyed-1" ] else value;
                        unkeyedPart = if hasUnkeyed then "${toLua unkeyedValue}" else "";
                        otherParts = lib.concatMapStringsSep ", " (key: "${key} = ${toLua otherAttrs.${key}}") (
                          lib.attrNames otherAttrs
                        );
                        allParts = lib.concatStringsSep ", " (
                          lib.filter (x: x != "") [
                            unkeyedPart
                            otherParts
                          ]
                        );
                      in
                      "{ ${allParts} }"
                    else
                      builtins.toJSON value;
                in
                toLua;
              taskConfig = lib.recursiveUpdate {
                args = [ ];
                cwd = "vim.fn.getcwd()";
                components = [
                  {
                    __unkeyed-1 = "display_duration";
                    detail_level = 2;
                  }
                  "on_output_summarize"
                  "on_exit_set_status"
                  "nx.custom_notify"
                  {
                    __unkeyed-1 = "on_complete_dispose";
                    require_view = [
                      "SUCCESS"
                      "FAILURE"
                    ];
                  }
                  {
                    __unkeyed-1 = "timeout";
                    timeout = 900;
                  }
                  "unique"
                  {
                    __unkeyed-1 = "open_output";
                    on_start = "never";
                    on_complete = "failure";
                  }
                  "on_output_quickfix"
                ];
                env = { };
                metadata = { };
                extraLuaCode = "";
                condition = { };
              } baseTaskConfig;
            in
            ''
              overseer.register_template({
                name = "${taskConfig.name or taskConfig.cmd}",
                builder = function(params)
                  ${taskConfig.extraLuaCode}
                  return {
                    cmd = ${luaValue taskConfig.cmd},
                    ${lib.optionalString (
                      taskConfig.args != null && taskConfig.args != [ ]
                    ) "args = ${luaValue taskConfig.args},"}
                    cwd = ${luaValue taskConfig.cwd},
                    components = ${luaValue taskConfig.components},
                    env = ${luaValue taskConfig.env},
                    metadata = ${luaValue taskConfig.metadata},
                  }
                end,
                condition = ${builtins.toJSON taskConfig.condition},
              })
            ''
          ) (lib.attrNames allTasks)
        }

        vim.api.nvim_create_user_command("OverseerRestartLast", function()
          local overseer = require("overseer")
          local tasks = overseer.list_tasks({ recent_first = true })
          if #tasks > 0 then
            overseer.run_action(tasks[1], "restart")
          else
            vim.notify("No tasks to restart", vim.log.levels.WARN)
          end
        end, { desc = "Restart last overseer task" })
      '';

      home.file.".config/nvim/lua/overseer/component/nx/custom_notify.lua".text = ''
        ---@type overseer.ComponentFileDefinition
        return {
          desc = "Custom notifications with icons for task lifecycle",
          editable = false,
          serializable = false,
          constructor = function(params)
            return {
              on_start = function(self, task)
                vim.notify("🚀 " .. (task.name or "Unknown Task"), vim.log.levels.INFO, {
                  title = "Task Started"
                })
              end,
              on_complete = function(self, task, status, result)
                local task_name = task.name or "Unknown Task"
                local STATUS = require("overseer").STATUS
                if status == STATUS.SUCCESS then
                  vim.notify("✅ " .. task_name, vim.log.levels.INFO, {
                    title = "Task Success"
                  })
                elseif status == STATUS.FAILURE then
                  vim.notify("❌ " .. task_name, vim.log.levels.ERROR, {
                    title = "Task Failed"
                  })
                elseif status == STATUS.CANCELED then
                  vim.notify("🛑 " .. task_name, vim.log.levels.WARN, {
                    title = "Task Canceled"
                  })
                else
                  vim.notify("💡 " .. task_name .. " (" .. tostring(status) .. ")", vim.log.levels.INFO, {
                    title = "Task Status"
                  })
                end
              end,
            }
          end,
        }
      '';

    };
}
