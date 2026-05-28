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
  name = "starship";

  group = "shell";
  input = "common";

  settings = {
    enableTransience = true;
    scanTimeout = 5000;
    commandTimeout = 2500;
  };

  module = {
    home =
      config:
      let
        timeFormat = "%d %b %Y %I:%M:%S %p";
        theme = config.nx.preferences.theme;
        deploymentMode = helpers.resolveFromHostOrUser config [ "deploymentMode" ] "develop";
        isHeadless = deploymentMode == "managed" || deploymentMode == "server";
        primaryBlock = if isHeadless then theme.colors.blocks.neutral else theme.colors.blocks.primary;
        accentColor =
          if isHeadless then
            theme.colors.blocks.neutral.foreground.html
          else
            theme.colors.main.foregrounds.primary.html;
      in
      {
        home.file."${config.xdg.configHome}/fish-init/20-starship.fish".text = ''
          if command -v starship > /dev/null
            function starship_transient_prompt_func
              echo
              starship module directory
              echo -n " "
            end

            function starship_transient_rprompt_func
              set -l time_output (date +"${timeFormat}")

              set_color '${primaryBlock.background.html}'
              printf ""

              set_color --background '${primaryBlock.background.html}' --bold '${primaryBlock.foreground.html}'
              printf "%s" $time_output

              set_color --background '${primaryBlock.background.html}' '${config.nx.preferences.theme.colors.terminal.normalBackgrounds.primary.html}'
              printf ""

              set_color normal
            end

            starship init fish | source

            ${if self.settings.enableTransience then "enable_transience" else ""}
          end
        '';

        programs.starship = {
          enable = true;

          settings = {
            add_newline = true;
            format = lib.concatStringsSep "\n" [
              ""
              "[┌─](fg:${config.nx.preferences.theme.colors.separators.ultraDark.html})$time[$fill](fg:${config.nx.preferences.theme.colors.separators.ultraDark.html})$status$cmd_duration[────](fg:${config.nx.preferences.theme.colors.separators.ultraDark.html})"
              "[│](fg:${config.nx.preferences.theme.colors.separators.ultraDark.html}) $os$shell$username$hostname$all"
              "[└───](fg:${config.nx.preferences.theme.colors.separators.ultraDark.html})$directory$character"
            ];
            right_format = "";
            scan_timeout = self.settings.scanTimeout;
            command_timeout = self.settings.commandTimeout;

            time = {
              format = "[]($style)[ $time ]($style)";
              disabled = false;
              style = "fg:${config.nx.preferences.theme.colors.separators.ultraDark.html}";
              time_format = timeFormat;
            };

            status = {
              symbol = "🔻";
              disabled = false;
              format = "[($symbol $status )]($style)";
              style = "bold fg:${config.nx.preferences.theme.colors.semantic.error.html}";
            };

            sudo = {
              disabled = false;
              symbol = "🔑  ";
              style = "bold fg:${accentColor}";
              format = "[$symbol]($style)";
            };

            character = {
              success_symbol = "";
              error_symbol = "[ ✗](bold fg:${config.nx.preferences.theme.colors.semantic.error.html})";
            };

            username = {
              style_user = "bold fg:${config.nx.preferences.theme.colors.semantic.error.html}";
              style_root = "bold fg:${config.nx.preferences.theme.colors.main.base.blue.html}";
              format = "[$user]($style) ";
              disabled = false;
              show_always = false;
            };

            hostname = {
              ssh_only = true;
              format = "[on ](fg:${config.nx.preferences.theme.colors.separators.ultraDark.html})[$hostname](bold fg:${config.nx.preferences.theme.colors.semantic.warning.html}) ";
              disabled = false;
            };

            directory = {
              home_symbol = "󰋞 ~";
              read_only_style = "bold fg:${config.nx.preferences.theme.colors.semantic.warning.html}";
              read_only = "  ";
              format = "[](fg:${config.nx.preferences.theme.colors.terminal.normalBackgrounds.primary.html} bg:${primaryBlock.background.html})[$path](bold fg:${primaryBlock.foreground.html} bg:${primaryBlock.background.html})[](fg:${primaryBlock.background.html})[$read_only]($read_only_style)";
              style = "";
              truncate_to_repo = true;
              use_os_path_sep = false;
              truncation_length = 3;
              truncation_symbol = "…";
              substitutions = {
                "nxcore" = "@nx:";
                "nxconfig" = "@config:";
              };
              fish_style_pwd_dir_length = 1;
            };

            git_branch = {
              symbol = " ";
              format = "[$symbol $branch]($style) ";
              style = "bold fg:${accentColor}";
            };

            git_status = {
              format = "[\($all_status$ahead_behind\)]($style) ";
              style = "bold fg:${accentColor}";
              conflicted = "(c)";
              up_to_date = " ";
              untracked = " ";
              ahead = "⇡\${count}";
              diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
              behind = "⇣\${count}";
              stashed = "(s) ";
              modified = " ";
              staged = "[++\($count\)](bold fg:${config.nx.preferences.theme.colors.semantic.success.html})";
              renamed = "(r) ";
              deleted = " ";
            };

            localip = {
              disabled = false;
              style = "bold fg:${config.nx.preferences.theme.colors.semantic.warning.html}";
              ssh_only = true;
              format = "[⟶  ](fg:${config.nx.preferences.theme.colors.separators.ultraDark.html}) [$localipv4]($style) ";
            };

            os = {
              disabled = true;
              symbols = {
                Ubuntu = "🐧";
                Debian = "🐧";
              };
              format = "[$symbol]($style) ";
              style = "bold fg:${accentColor}";
            };

            shell = {
              fish_indicator = "🐟";
              bash_indicator = "⭕";
              zsh_indicator = "🟠";
              unknown_indicator = "🔴";
              disabled = true;
              style = "bold fg:${accentColor}";
              format = " [$indicator]($style)  ";
            };

            aws = {
              style = "bold fg:${accentColor}";
            };

            azure = {
              style = "bold fg:${accentColor}";
            };

            buf = {
              style = "bold fg:${accentColor}";
            };

            bun = {
              style = "bold fg:${accentColor}";
            };

            c = {
              style = "bold fg:${accentColor}";
            };

            cmake = {
              style = "bold fg:${accentColor}";
            };

            cobol = {
              style = "bold fg:${accentColor}";
            };

            crystal = {
              style = "bold fg:${accentColor}";
            };

            daml = {
              style = "bold fg:${accentColor}";
            };

            dart = {
              style = "bold fg:${accentColor}";
            };

            deno = {
              style = "bold fg:${accentColor}";
            };

            dotnet = {
              style = "bold fg:${accentColor}";
            };

            elixir = {
              style = "bold fg:${accentColor}";
            };

            elm = {
              style = "bold fg:${accentColor}";
            };

            erlang = {
              style = "bold fg:${accentColor}";
            };

            fennel = {
              style = "bold fg:${accentColor}";
            };

            fossil_branch = {
              style = "bold fg:${accentColor}";
            };

            gcloud = {
              style = "bold fg:${accentColor}";
            };

            git_commit = {
              style = "bold fg:${accentColor}";
            };

            git_state = {
              style = "bold fg:${accentColor}";
            };

            git_metrics = {
              added_style = "bold fg:${config.nx.preferences.theme.colors.semantic.warning.html}";
              deleted_style = "bold fg:${config.nx.preferences.theme.colors.main.base.purple.html}";
            };

            gleam = {
              style = "bold fg:${accentColor}";
            };

            golang = {
              style = "bold fg:${accentColor}";
            };

            gradle = {
              style = "bold fg:${accentColor}";
            };

            guix_shell = {
              style = "bold fg:${accentColor}";
            };

            haskell = {
              style = "bold fg:${accentColor}";
            };

            haxe = {
              style = "bold fg:${accentColor}";
            };

            helm = {
              style = "bold fg:${accentColor}";
            };

            hg_branch = {
              style = "bold fg:${accentColor}";
            };

            java = {
              style = "bold fg:${accentColor}";
            };

            julia = {
              style = "bold fg:${accentColor}";
            };

            kotlin = {
              style = "bold fg:${accentColor}";
            };

            kubernetes = {
              style = "bold fg:${accentColor}";
            };

            lua = {
              style = "bold fg:${accentColor}";
            };

            meson = {
              style = "bold fg:${accentColor}";
            };

            nim = {
              style = "bold fg:${accentColor}";
            };

            nix_shell = {
              style = "bold fg:${accentColor}";
            };

            ocaml = {
              style = "bold fg:${accentColor}";
            };

            opa = {
              style = "bold fg:${accentColor}";
            };

            openstack = {
              style = "bold fg:${accentColor}";
            };

            package = {
              format = "[is]($style) [$symbol$version]($style) ";
              style = "bold fg:${config.nx.preferences.theme.colors.main.base.blue.html}";
            };

            perl = {
              style = "bold fg:${accentColor}";
            };

            php = {
              style = "bold fg:${accentColor}";
            };

            pijul_channel = {
              style = "bold fg:${accentColor}";
            };

            pulumi = {
              style = "bold fg:${accentColor}";
            };

            purescript = {
              style = "bold fg:${accentColor}";
            };

            quarto = {
              style = "bold fg:${accentColor}";
            };

            raku = {
              style = "bold fg:${accentColor}";
            };

            red = {
              style = "bold fg:${accentColor}";
            };

            rlang = {
              style = "bold fg:${accentColor}";
            };

            ruby = {
              style = "bold fg:${accentColor}";
            };

            rust = {
              style = "bold fg:${accentColor}";
            };

            scala = {
              style = "bold fg:${accentColor}";
            };

            singularity = {
              style = "bold fg:${accentColor}";
            };

            solidity = {
              style = "bold fg:${accentColor}";
            };

            spack = {
              style = "bold fg:${accentColor}";
            };

            swift = {
              style = "bold fg:${accentColor}";
            };

            terraform = {
              style = "bold fg:${accentColor}";
            };

            typst = {
              style = "bold fg:${accentColor}";
            };

            vagrant = {
              style = "bold fg:${accentColor}";
            };

            vlang = {
              style = "bold fg:${accentColor}";
            };

            vcsh = {
              style = "bold fg:${accentColor}";
            };

            zig = {
              style = "bold fg:${accentColor}";
            };

            battery = { };

            cmd_duration = {
              format = "[]($style)[$duration]($style)";
              style = "fg:${config.nx.preferences.theme.colors.separators.ultraDark.html}";
              min_time = 1000;
              show_notifications = true;
              min_time_to_notify = 600000;
            };

            direnv = {
              style = "bold fg:${accentColor}";
            };

            env_var = {
              style = "bold fg:${accentColor}";
            };

            fill = {
              symbol = "─";
              style = "fg:none bg:none";
            };

            fossil_metrics = {
              added_style = "bold fg:${config.nx.preferences.theme.colors.semantic.warning.html}";
              deleted_style = "bold fg:${config.nx.preferences.theme.colors.main.base.purple.html}";
            };

            jobs = {
              style = "bold fg:${accentColor}";
            };

            line_break = {
              disabled = true;
              style = "bold fg:${accentColor}";
            };

            memory_usage = {
              style = "bold fg:${accentColor}";
            };

            shlvl = {
              style = "bold fg:${accentColor}";
            };

            docker_context = {
              format = "[via]($style) [$symbol$context]($style) ";
              style = "bold fg:${accentColor}";
            };

            python = {
              format = "[via]($style) [$symbol$pyenv_prefix($version )(\\($virtualenv\\) )]($style)";
              style = "bold fg:${accentColor}";
            };

            nodejs = {
              format = "[via]($style) [$symbol($version )]($style)";
              style = "bold fg:${accentColor}";
            };

            conda = {
              format = "[via]($style) [$symbol$environment]($style) ";
              style = "bold fg:${accentColor}";
            };
          };
        };
      };
  };
}
