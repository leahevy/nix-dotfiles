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
  name = "tardis";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    keymap = {
      next = "J";
      prev = "K";
      quit = "q";
      revision_message = "<C-m>";
      commit = "<C-g>";
    };

    settings = {
      initial_revisions = 10;
      max_revisions = 256;
      show_commit_index = true;
    };
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        extraPlugins = [
          (pkgs.vimUtils.buildVimPlugin {
            name = "tardis-nvim";
            src = pkgs.fetchFromGitHub {
              owner = "FredeHoey";
              repo = "tardis.nvim";
              rev = "f050686a6c299dba95d07990550174c20aba56dd";
              sha256 = "sha256-VgVvcnBaWnZ4V5INtIn3ecqffo3EQvzUmxzg05WaVH4=";
            };
            dependencies = with pkgs.vimPlugins; [
              plenary-nvim
            ];
          })
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<leader>gh";
            desc = "Git history (time travel)";
            icon = "󰉁";
          }
        ];

        extraConfigLua = ''
          _G.nx_modules = _G.nx_modules or {}
          _G.nx_modules["90-tardis"] = function()
            require('tardis-nvim').setup({
              keymap = {
                ["next"] = "${self.settings.keymap.next}",
                ["prev"] = "${self.settings.keymap.prev}",
                ["quit"] = "${self.settings.keymap.quit}",
                ["revision_message"] = "${self.settings.keymap.revision_message}",
                ["commit"] = "${self.settings.keymap.commit}"
              },
              initial_revisions = ${toString self.settings.settings.initial_revisions},
              max_revisions = ${toString self.settings.settings.max_revisions},
              show_commit_index = ${if self.settings.settings.show_commit_index then "true" else "false"}
            })

            vim.keymap.set('n', '<leader>gh', ':Tardis git<CR>', {
              desc = 'Git history (time travel)',
              silent = true
            })

            local Session = require('tardis-nvim.session').Session
            Session.create_info_buffer = function(self, revision)
              local rev_info = self.adapter.get_revision_info(revision, self)
              if not rev_info.message or #rev_info.message == 0 then
                vim.notify('Revision message was empty', vim.log.levels.WARN, {
                  title = "Tardis"
                })
                return
              end

              local message = table.concat(rev_info.message, '\n')
              vim.notify(message, vim.log.levels.INFO, {
                title = "Git Revision: " .. revision:sub(1, 7)
              })
            end

            Session.next_buffer = function(self)
              if not self:goto_buffer(self.curret_buffer_index + 1) then
                vim.notify('No earlier revisions of file', vim.log.levels.WARN, {
                  title = "Tardis"
                })
              else
                local revision = self.log[self.curret_buffer_index]
                if revision then
                  local rev_info = self.adapter.get_revision_info(revision, self)
                  local message = rev_info.message and table.concat(rev_info.message, '\n') or 'No commit message'
                  vim.notify(message, vim.log.levels.INFO, {
                    title = "Now viewing revision: " .. revision:sub(1, 7)
                  })
                end
              end
            end

            Session.prev_buffer = function(self)
              if not self:goto_buffer(self.curret_buffer_index - 1) then
                vim.notify('No later revisions of file', vim.log.levels.WARN, {
                  title = "Tardis"
                })
              else
                local revision = self.log[self.curret_buffer_index]
                if revision then
                  local rev_info = self.adapter.get_revision_info(revision, self)
                  local message = rev_info.message and table.concat(rev_info.message, '\n') or 'No commit message'
                  vim.notify(message, vim.log.levels.INFO, {
                    title = "Now viewing revision: " .. revision:sub(1, 7)
                  })
                end
              end
            end

            Session.commit_to_origin = function(self)
              local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
              vim.api.nvim_buf_set_lines(self.origin, 0, -1, false, lines)
              local revision = self.log[self.curret_buffer_index]
              if revision then
                local rev_info = self.adapter.get_revision_info(revision, self)
                local message = rev_info.message and table.concat(rev_info.message, '\n') or 'No commit message'
                vim.notify(message, vim.log.levels.INFO, {
                  title = "Committed revision: " .. revision:sub(1, 7)
                })
              end
              self:close()
            end

            local SessionManager = require('tardis-nvim.session_manager').SessionManager
            SessionManager.on_session_opened = function(self, session)
              self.sessions[session.filename] = session
              vim.notify('Entered Tardis mode for ' .. vim.fn.fnamemodify(session.filename, ':t'), vim.log.levels.INFO, {
                title = "Tardis"
              })
            end

            SessionManager.on_session_closed = function(self, session)
              self.sessions[session.filename] = nil
              vim.notify('Left Tardis mode', vim.log.levels.INFO, {
                title = "Tardis"
              })
            end
          end
        '';
      };
    };
}
