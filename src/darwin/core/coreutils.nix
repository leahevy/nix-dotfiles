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
          "${defs.binDir}/sort".source = "${pkgs.coreutils}/bin/sort";
          "${defs.binDir}/uniq".source = "${pkgs.coreutils}/bin/uniq";
          "${defs.binDir}/cut".source = "${pkgs.coreutils}/bin/cut";
          "${defs.binDir}/tr".source = "${pkgs.coreutils}/bin/tr";
          "${defs.binDir}/scripts/date".source = "${pkgs.coreutils}/bin/date";
          "${defs.binDir}/scripts/stat".source = "${pkgs.coreutils}/bin/stat";
          "${defs.binDir}/readlink".source = "${pkgs.coreutils}/bin/readlink";
          "${defs.binDir}/realpath".source = "${pkgs.coreutils}/bin/realpath";
          "${defs.binDir}/mktemp".source = "${pkgs.coreutils}/bin/mktemp";
          "${defs.binDir}/du".source = "${pkgs.coreutils}/bin/du";
          "${defs.binDir}/df".source = "${pkgs.coreutils}/bin/df";
          "${defs.binDir}/ls".source = "${pkgs.coreutils}/bin/ls";
          "${defs.binDir}/cp".source = "${pkgs.coreutils}/bin/cp";
          "${defs.binDir}/mv".source = "${pkgs.coreutils}/bin/mv";
          "${defs.binDir}/rm".source = "${pkgs.coreutils}/bin/rm";
          "${defs.binDir}/chmod".source = "${pkgs.coreutils}/bin/chmod";
          "${defs.binDir}/chown".source = "${pkgs.coreutils}/bin/chown";
          "${defs.binDir}/head".source = "${pkgs.coreutils}/bin/head";
          "${defs.binDir}/tail".source = "${pkgs.coreutils}/bin/tail";
          "${defs.binDir}/wc".source = "${pkgs.coreutils}/bin/wc";
          "${defs.binDir}/tee".source = "${pkgs.coreutils}/bin/tee";
          "${defs.binDir}/split".source = "${pkgs.coreutils}/bin/split";
          "${defs.binDir}/join".source = "${pkgs.coreutils}/bin/join";
          "${defs.binDir}/paste".source = "${pkgs.coreutils}/bin/paste";
          "${defs.binDir}/fmt".source = "${pkgs.coreutils}/bin/fmt";
          "${defs.binDir}/nl".source = "${pkgs.coreutils}/bin/nl";
          "${defs.binDir}/od".source = "${pkgs.coreutils}/bin/od";
          "${defs.binDir}/base64".source = "${pkgs.coreutils}/bin/base64";
          "${defs.binDir}/install".source = "${pkgs.coreutils}/bin/install";
          "${defs.binDir}/touch".source = "${pkgs.coreutils}/bin/touch";
          "${defs.binDir}/mkdir".source = "${pkgs.coreutils}/bin/mkdir";
          "${defs.binDir}/find".source = "${pkgs.findutils}/bin/find";
          "${defs.binDir}/locate".source = "${pkgs.findutils}/bin/locate";
          "${defs.binDir}/xargs".source = "${pkgs.findutils}/bin/xargs";
          "${defs.binDir}/sed".source = "${pkgs.gnused}/bin/sed";
          "${defs.binDir}/grep".source = "${pkgs.gnugrep}/bin/grep";
          "${defs.binDir}/awk".source = "${pkgs.gawk}/bin/awk";
          "${defs.binDir}/tar".source = "${pkgs.gnutar}/bin/tar";
        };
      };
  };
}
