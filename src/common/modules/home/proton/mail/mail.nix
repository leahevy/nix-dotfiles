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
  name = "mail";

  group = "proton";
  input = "common";
  namespace = "home";

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
        ++ lib.optional self.settings.isolateConfig ''--set XDG_CONFIG_HOME "${self.user.home}/.config/proton-mail"''
      );

      protonmailWrapped =
        if needsWrapper then
          (pkgs.symlinkJoin {
            name = "protonmail-desktop-wrapped";
            paths = [ pkgs.protonmail-desktop ];
            buildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/proton-mail ${wrapperArgs}

              rm -f $out/share/applications/proton-mail.desktop
              mkdir -p $out/share/applications
              substitute ${pkgs.protonmail-desktop}/share/applications/proton-mail.desktop \
                $out/share/applications/proton-mail.desktop \
                --replace-fail "Exec=proton-mail" "Exec=$out/bin/proton-mail"
            '';
          })
        else
          pkgs.protonmail-desktop;
    in
    {
      home.packages = [
        protonmailWrapped
      ];

      home.persistence."${self.persist}" = lib.mkIf self.settings.isolateConfig {
        directories = [ ".config/proton-mail" ];
      };
    };
}
