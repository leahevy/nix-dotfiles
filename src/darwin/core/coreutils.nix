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
  name = "coreutils";

  group = "core";
  input = "darwin";

  module = {
    darwin.standalone =
      { config, ... }:
      {
        home.file = {
          ".local/bin/sort".source = "${pkgs.coreutils}/bin/sort";
          ".local/bin/uniq".source = "${pkgs.coreutils}/bin/uniq";
          ".local/bin/cut".source = "${pkgs.coreutils}/bin/cut";
          ".local/bin/tr".source = "${pkgs.coreutils}/bin/tr";
          ".local/bin/scripts/date".source = "${pkgs.coreutils}/bin/date";
          ".local/bin/scripts/stat".source = "${pkgs.coreutils}/bin/stat";
          ".local/bin/readlink".source = "${pkgs.coreutils}/bin/readlink";
          ".local/bin/realpath".source = "${pkgs.coreutils}/bin/realpath";
          ".local/bin/mktemp".source = "${pkgs.coreutils}/bin/mktemp";
          ".local/bin/du".source = "${pkgs.coreutils}/bin/du";
          ".local/bin/df".source = "${pkgs.coreutils}/bin/df";
          ".local/bin/ls".source = "${pkgs.coreutils}/bin/ls";
          ".local/bin/cp".source = "${pkgs.coreutils}/bin/cp";
          ".local/bin/mv".source = "${pkgs.coreutils}/bin/mv";
          ".local/bin/rm".source = "${pkgs.coreutils}/bin/rm";
          ".local/bin/chmod".source = "${pkgs.coreutils}/bin/chmod";
          ".local/bin/chown".source = "${pkgs.coreutils}/bin/chown";
          ".local/bin/head".source = "${pkgs.coreutils}/bin/head";
          ".local/bin/tail".source = "${pkgs.coreutils}/bin/tail";
          ".local/bin/wc".source = "${pkgs.coreutils}/bin/wc";
          ".local/bin/tee".source = "${pkgs.coreutils}/bin/tee";
          ".local/bin/split".source = "${pkgs.coreutils}/bin/split";
          ".local/bin/join".source = "${pkgs.coreutils}/bin/join";
          ".local/bin/paste".source = "${pkgs.coreutils}/bin/paste";
          ".local/bin/fmt".source = "${pkgs.coreutils}/bin/fmt";
          ".local/bin/nl".source = "${pkgs.coreutils}/bin/nl";
          ".local/bin/od".source = "${pkgs.coreutils}/bin/od";
          ".local/bin/base64".source = "${pkgs.coreutils}/bin/base64";
          ".local/bin/install".source = "${pkgs.coreutils}/bin/install";
          ".local/bin/touch".source = "${pkgs.coreutils}/bin/touch";
          ".local/bin/mkdir".source = "${pkgs.coreutils}/bin/mkdir";
          ".local/bin/find".source = "${pkgs.findutils}/bin/find";
          ".local/bin/locate".source = "${pkgs.findutils}/bin/locate";
          ".local/bin/xargs".source = "${pkgs.findutils}/bin/xargs";
          ".local/bin/sed".source = "${pkgs.gnused}/bin/sed";
          ".local/bin/grep".source = "${pkgs.gnugrep}/bin/grep";
          ".local/bin/awk".source = "${pkgs.gawk}/bin/awk";
          ".local/bin/tar".source = "${pkgs.gnutar}/bin/tar";
        };
      };
  };
}
