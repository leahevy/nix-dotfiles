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
            style = "bold red";
          };

          sudo = {
            disabled = false;
            symbol = "🔑  ";
            style = "bold green";
            format = "[$symbol]($style)";
          };

          character = {
            success_symbol = "[⇒ ](bold green)";
            error_symbol = "[⇒ ](bold purple)";
          };

          username = {
            style_user = "bold red";
            style_root = "bold blue";
            format = "[$user]($style) ";
            disabled = false;
            show_always = false;
          };

          hostname = {
            ssh_only = true;
            format = "[on ](bright-black)[$hostname](bold yellow) ";
            disabled = false;
          };

          directory = {
            home_symbol = "󰋞 ~";
            read_only_style = "bold yellow";
            read_only = "  ";
            format = "[$path]($style)[$read_only]($read_only_style) ";
            style = "bold red";
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
            style = "bold green";
          };

          git_status = {
            format = "[\($all_status$ahead_behind\)]($style) ";
            style = "bold green";
            conflicted = "(c)";
            up_to_date = " ";
            untracked = " ";
            ahead = "⇡\${count}";
            diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
            behind = "⇣\${count}";
            stashed = "(s) ";
            modified = " ";
            staged = "[++\($count\)](bold green)";
            renamed = "(r) ";
            deleted = " ";
          };

          localip = {
            disabled = false;
            style = "bold yellow";
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
            style = "bold green";
          };

          azure = {
            style = "bold green";
          };

          buf = {
            style = "bold green";
          };

          bun = {
            style = "bold green";
          };

          c = {
            style = "bold green";
          };

          cmake = {
            style = "bold green";
          };

          cobol = {
            style = "bold green";
          };

          crystal = {
            style = "bold green";
          };

          daml = {
            style = "bold green";
          };

          dart = {
            style = "bold green";
          };

          deno = {
            style = "bold green";
          };

          dotnet = {
            style = "bold green";
          };

          elixir = {
            style = "bold green";
          };

          elm = {
            style = "bold green";
          };

          erlang = {
            style = "bold green";
          };

          fennel = {
            style = "bold green";
          };

          fossil_branch = {
            style = "bold green";
          };

          gcloud = {
            style = "bold green";
          };

          git_commit = {
            style = "bold green";
          };

          git_state = {
            style = "bold green";
          };

          git_metrics = {
            added_style = "bold yellow";
            deleted_style = "purple";
          };

          gleam = {
            style = "bold green";
          };

          golang = {
            style = "bold green";
          };

          gradle = {
            style = "bold green";
          };

          guix_shell = {
            style = "bold green";
          };

          haskell = {
            style = "bold green";
          };

          haxe = {
            style = "bold green";
          };

          helm = {
            style = "bold green";
          };

          hg_branch = {
            style = "bold green";
          };

          java = {
            style = "bold green";
          };

          julia = {
            style = "bold green";
          };

          kotlin = {
            style = "bold green";
          };

          kubernetes = {
            style = "bold green";
          };

          lua = {
            style = "bold green";
          };

          meson = {
            style = "bold green";
          };

          nim = {
            style = "bold green";
          };

          nix_shell = {
            style = "bold green";
          };

          ocaml = {
            style = "bold green";
          };

          opa = {
            style = "bold green";
          };

          openstack = {
            style = "bold green";
          };

          package = {
            format = "[is]($style) [$symbol$version]($style) ";
            style = "bold blue";
          };

          perl = {
            style = "bold green";
          };

          php = {
            style = "bold green";
          };

          pijul_channel = {
            style = "bold green";
          };

          pulumi = {
            style = "bold green";
          };

          purescript = {
            style = "bold green";
          };

          quarto = {
            style = "bold green";
          };

          raku = {
            style = "bold green";
          };

          red = {
            style = "bold green";
          };

          rlang = {
            style = "bold green";
          };

          ruby = {
            style = "bold green";
          };

          rust = {
            style = "bold green";
          };

          scala = {
            style = "bold green";
          };

          singularity = {
            style = "bold green";
          };

          solidity = {
            style = "bold green";
          };

          spack = {
            style = "bold green";
          };

          swift = {
            style = "bold green";
          };

          terraform = {
            style = "bold green";
          };

          typst = {
            style = "bold green";
          };

          vagrant = {
            style = "bold green";
          };

          vlang = {
            style = "bold green";
          };

          vcsh = {
            style = "bold green";
          };

          zig = {
            style = "bold green";
          };

          battery = { };

          cmd_duration = {
            format = "[]($style)[$duration]($style) ";
            style = "bright-black";
            min_time = 1000;
            show_notifications = true;
            min_time_to_notify = 100000;
          };

          direnv = {
            style = "bold green";
          };

          env_var = {
            style = "bold green";
          };

          fill = {
            symbol = "─";
            style = "bright-black";
          };

          fossil_metrics = {
            added_style = "bold yellow";
            deleted_style = "purple";
          };

          jobs = {
            style = "bold green";
          };

          line_break = {
            disabled = true;
            style = "bold green";
          };

          memory_usage = {
            style = "bold green";
          };

          shlvl = {
            style = "bold green";
          };

          docker_context = {
            format = "[via]($style) [$symbol$context]($style) ";
            style = "bold green";
          };

          python = {
            format = "[via]($style) [$symbol$pyenv_prefix($version )(\\($virtualenv\\) )]($style)";
            style = "bold green";
          };

          nodejs = {
            format = "[via]($style) [$symbol($version )]($style)";
            style = "bold green";
          };

          conda = {
            format = "[via]($style) [$symbol$environment]($style) ";
            style = "bold green";
          };
        };
      };
    };
}
