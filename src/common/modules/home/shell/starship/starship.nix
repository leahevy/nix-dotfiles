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
  namespace = "home";

  settings = {
    enableTransience = true;
  };

  configuration =
    context@{ config, options, ... }:
    {
      home.file."${config.xdg.configHome}/fish-init/20-starship.fish".text = ''
        if command -v starship > /dev/null
          function starship_transient_prompt_func
            echo
            starship module directory
            echo -n " "
          end

          function starship_transient_rprompt_func
            starship module time
          end

          starship init fish | source

          ${if self.settings.enableTransience then "enable_transience" else ""}
        end
      '';

      programs.starship = {
        enable = true;

        settings = {
          add_newline = true;
          format = "\n[┌─](fg:${self.theme.colors.separators.ultraDark.html})$time$fill $status$os$shell$username$hostname$all$cmd_duration[───┐](fg:${self.theme.colors.separators.ultraDark.html})\n[│](fg:${self.theme.colors.separators.ultraDark.html})\n[└───](fg:${self.theme.colors.separators.ultraDark.html})$directory$character";
          right_format = "";

          time = {
            format = "[]($style)[ $time ]($style)";
            disabled = false;
            style = "fg:${self.theme.colors.separators.ultraDark.html}";
            time_format = "%d %b %Y %I:%M:%S %p";
          };

          status = {
            symbol = "🔻";
            disabled = false;
            format = "[$symbol $status]($style) ";
            style = "bold fg:${self.theme.colors.semantic.error.html}";
          };

          sudo = {
            disabled = false;
            symbol = "🔑  ";
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
            format = "[$symbol]($style)";
          };

          character = {
            success_symbol = "";
            error_symbol = "[ ✗](bold fg:${self.theme.colors.semantic.error.html})";
          };

          username = {
            style_user = "bold fg:${self.theme.colors.semantic.error.html}";
            style_root = "bold fg:${self.theme.colors.main.base.blue.html}";
            format = "[$user]($style) ";
            disabled = false;
            show_always = false;
          };

          hostname = {
            ssh_only = true;
            format = "[on ](fg:${self.theme.colors.separators.ultraDark.html})[$hostname](bold fg:${self.theme.colors.semantic.warning.html}) ";
            disabled = false;
          };

          directory = {
            home_symbol = "󰋞 ~";
            read_only_style = "bold fg:${self.theme.colors.semantic.warning.html}";
            read_only = "  ";
            format = "[](fg:${self.theme.colors.terminal.normalBackgrounds.primary.html} bg:${self.theme.colors.blocks.primary.background.html})[$path](bold fg:${self.theme.colors.blocks.primary.foreground.html} bg:${self.theme.colors.blocks.primary.background.html})[](bg:${self.theme.colors.terminal.normalBackgrounds.primary.html} fg:${self.theme.colors.blocks.primary.background.html})[$read_only]($read_only_style)";
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
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          git_status = {
            format = "[\($all_status$ahead_behind\)]($style) ";
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
            conflicted = "(c)";
            up_to_date = " ";
            untracked = " ";
            ahead = "⇡\${count}";
            diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
            behind = "⇣\${count}";
            stashed = "(s) ";
            modified = " ";
            staged = "[++\($count\)](bold fg:${self.theme.colors.semantic.success.html})";
            renamed = "(r) ";
            deleted = " ";
          };

          localip = {
            disabled = false;
            style = "bold fg:${self.theme.colors.semantic.warning.html}";
            ssh_only = true;
            format = "[⟶  ](fg:${self.theme.colors.separators.ultraDark.html}) [$localipv4]($style) ";
          };

          os = {
            disabled = true;
            symbols = {
              Ubuntu = "🐧";
              Debian = "🐧";
            };
            format = "[$symbol]($style) ";
            style = "blue";
          };

          shell = {
            fish_indicator = "🐟";
            bash_indicator = "⭕";
            zsh_indicator = "🟠";
            unknown_indicator = "🔴";
            disabled = true;
            style = "cyan";
            format = " [$indicator]($style)  ";
          };

          aws = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          azure = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          buf = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          bun = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          c = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          cmake = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          cobol = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          crystal = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          daml = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          dart = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          deno = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          dotnet = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          elixir = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          elm = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          erlang = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          fennel = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          fossil_branch = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          gcloud = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          git_commit = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          git_state = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          git_metrics = {
            added_style = "bold fg:${self.theme.colors.semantic.warning.html}";
            deleted_style = "bold fg:${self.theme.colors.main.base.purple.html}";
          };

          gleam = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          golang = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          gradle = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          guix_shell = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          haskell = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          haxe = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          helm = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          hg_branch = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          java = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          julia = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          kotlin = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          kubernetes = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          lua = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          meson = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          nim = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          nix_shell = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          ocaml = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          opa = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          openstack = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          package = {
            format = "[is]($style) [$symbol$version]($style) ";
            style = "bold fg:${self.theme.colors.main.base.blue.html}";
          };

          perl = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          php = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          pijul_channel = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          pulumi = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          purescript = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          quarto = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          raku = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          red = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          rlang = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          ruby = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          rust = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          scala = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          singularity = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          solidity = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          spack = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          swift = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          terraform = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          typst = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          vagrant = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          vlang = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          vcsh = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          zig = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          battery = { };

          cmd_duration = {
            format = "[]($style)[$duration]($style) ";
            style = "fg:${self.theme.colors.separators.ultraDark.html}";
            min_time = 1000;
            show_notifications = true;
            min_time_to_notify = 600000;
          };

          direnv = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          env_var = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          fill = {
            symbol = "─";
            style = "fg:${self.theme.colors.separators.ultraDark.html}";
          };

          fossil_metrics = {
            added_style = "bold fg:${self.theme.colors.semantic.warning.html}";
            deleted_style = "bold fg:${self.theme.colors.main.base.purple.html}";
          };

          jobs = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          line_break = {
            disabled = true;
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          memory_usage = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          shlvl = {
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          docker_context = {
            format = "[via]($style) [$symbol$context]($style) ";
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          python = {
            format = "[via]($style) [$symbol$pyenv_prefix($version )(\\($virtualenv\\) )]($style)";
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          nodejs = {
            format = "[via]($style) [$symbol($version )]($style)";
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };

          conda = {
            format = "[via]($style) [$symbol$environment]($style) ";
            style = "bold fg:${self.theme.colors.main.foregrounds.primary.html}";
          };
        };
      };
    };
}
