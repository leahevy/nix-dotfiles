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

  configuration =
    context@{ config, options, ... }:
    {
      home.file."${config.xdg.configHome}/fish-init/20-starship.fish".text = ''
        command -q starship; and starship init fish | source
      '';

      programs.starship = {
        enable = true;

        settings = {
          add_newline = true;
          format = "\n[┌─](bright-black)$time$fill $status$os$shell$username$hostname$all$cmd_duration[───┐](bright-black)\n[└─>](bright-black) $directory$character";
          right_format = "";

          time = {
            format = "[]($style)[ $time ]($style)";
            disabled = false;
            style = "bright-black";
            time_format = "%d %b %Y %I:%M:%S %p";
          };

          status = {
            symbol = "🔻";
            disabled = false;
            format = "[$symbol $status]($style) ";
            style = "bold ${self.theme.colors.semantic.error.name}";
          };

          sudo = {
            disabled = false;
            symbol = "🔑  ";
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
            format = "[$symbol]($style)";
          };

          character = {
            success_symbol = "[⇒ ](bold ${self.theme.colors.semantic.success.name})";
            error_symbol = "[⇒ ](bold ${self.theme.colors.main.base.purple.name})";
          };

          username = {
            style_user = "bold ${self.theme.colors.semantic.error.name}";
            style_root = "bold ${self.theme.colors.main.base.blue.name}";
            format = "[$user]($style) ";
            disabled = false;
            show_always = false;
          };

          hostname = {
            ssh_only = true;
            format = "[on ](bright-black)[$hostname](bold ${self.theme.colors.semantic.warning.name}) ";
            disabled = false;
          };

          directory = {
            home_symbol = "󰋞 ~";
            read_only_style = "bold ${self.theme.colors.semantic.warning.name}";
            read_only = "  ";
            format = "[$path]($style)[$read_only]($read_only_style) ";
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
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
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          git_status = {
            format = "[\($all_status$ahead_behind\)]($style) ";
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
            conflicted = "(c)";
            up_to_date = " ";
            untracked = " ";
            ahead = "⇡\${count}";
            diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
            behind = "⇣\${count}";
            stashed = "(s) ";
            modified = " ";
            staged = "[++\($count\)](bold ${self.theme.colors.semantic.success.name})";
            renamed = "(r) ";
            deleted = " ";
          };

          localip = {
            disabled = false;
            style = "bold ${self.theme.colors.semantic.warning.name}";
            ssh_only = true;
            format = "[⟶  ](bright-black) [$localipv4]($style) ";
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
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          azure = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          buf = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          bun = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          c = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          cmake = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          cobol = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          crystal = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          daml = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          dart = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          deno = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          dotnet = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          elixir = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          elm = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          erlang = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          fennel = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          fossil_branch = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          gcloud = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          git_commit = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          git_state = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          git_metrics = {
            added_style = "bold ${self.theme.colors.semantic.warning.name}";
            deleted_style = "${self.theme.colors.main.base.purple.name}";
          };

          gleam = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          golang = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          gradle = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          guix_shell = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          haskell = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          haxe = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          helm = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          hg_branch = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          java = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          julia = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          kotlin = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          kubernetes = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          lua = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          meson = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          nim = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          nix_shell = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          ocaml = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          opa = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          openstack = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          package = {
            format = "[is]($style) [$symbol$version]($style) ";
            style = "bold ${self.theme.colors.main.base.blue.name}";
          };

          perl = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          php = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          pijul_channel = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          pulumi = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          purescript = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          quarto = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          raku = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          red = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          rlang = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          ruby = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          rust = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          scala = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          singularity = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          solidity = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          spack = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          swift = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          terraform = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          typst = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          vagrant = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          vlang = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          vcsh = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          zig = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          battery = { };

          cmd_duration = {
            format = "[]($style)[$duration]($style) ";
            style = "bright-black";
            min_time = 1000;
            show_notifications = true;
            min_time_to_notify = 600000;
          };

          direnv = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          env_var = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          fill = {
            symbol = "─";
            style = "bright-black";
          };

          fossil_metrics = {
            added_style = "bold ${self.theme.colors.semantic.warning.name}";
            deleted_style = "${self.theme.colors.main.base.purple.name}";
          };

          jobs = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          line_break = {
            disabled = true;
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          memory_usage = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          shlvl = {
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          docker_context = {
            format = "[via]($style) [$symbol$context]($style) ";
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          python = {
            format = "[via]($style) [$symbol$pyenv_prefix($version )(\\($virtualenv\\) )]($style)";
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          nodejs = {
            format = "[via]($style) [$symbol($version )]($style)";
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };

          conda = {
            format = "[via]($style) [$symbol$environment]($style) ";
            style = "bold ${self.theme.colors.main.foregrounds.primary.name}";
          };
        };
      };
    };
}
