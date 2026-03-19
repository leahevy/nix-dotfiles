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
  name = "pass";

  group = "proton";
  input = "common";
  namespace = "home";

  unfree = [
    "proton-authenticator"
    "proton-pass-cli"
  ];

  settings = {
    forceX11 = true;
    isolateConfig = true;
  };

  configuration =
    context@{ config, options, ... }:
    let
      needsWrapper = self.isLinux && (self.settings.forceX11 || self.settings.isolateConfig);
      wrapperArgs = lib.concatStringsSep " " (
        lib.optional self.settings.forceX11 "--set XDG_SESSION_TYPE x11"
        ++ lib.optional self.settings.isolateConfig ''--set XDG_CONFIG_HOME "${self.user.home}/.config/proton-pass"''
      );

      protonPassWrapped =
        if needsWrapper then
          (pkgs.symlinkJoin {
            name = "proton-pass-wrapped";
            paths = [ pkgs.proton-pass ];
            buildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/proton-pass ${wrapperArgs}

              rm -f $out/share/applications/proton-pass.desktop
              mkdir -p $out/share/applications
              substitute ${pkgs.proton-pass}/share/applications/proton-pass.desktop \
                $out/share/applications/proton-pass.desktop \
                --replace-fail "Exec=proton-pass" "Exec=$out/bin/proton-pass"
            '';
          })
        else
          pkgs.proton-pass;
    in
    {
      home.packages = [
        protonPassWrapped
      ]
      ++ (with pkgs; [
        proton-authenticator
      ])
      ++ (with pkgs-unstable; [
        proton-pass-cli
      ]);

      home.persistence."${self.persist}" = lib.mkIf self.settings.isolateConfig {
        directories = [ ".config/proton-pass" ];
      };
    };
}
