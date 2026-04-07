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
  name = "qutebrowser";

  group = "browser";
  input = "linux";

  unfree = [ "widevine-cdm" ];

  warning =
    if self.isX86_64 then
      null
    else
      "Qutebrowser is only available for x86_64 architectures. Current: ${
        self.host.architecture or self.user.architecture
      }";

  options = {
    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Final Qutebrowser package";
    };
  };

  submodules = {
    common = {
      browser = {
        qutebrowser-config = true;
      };
    };
  };

  on = {
    linux.enabled =
      config:
      lib.mkIf self.isX86_64 (
        let
          nvidiaQuirks = (self.common.getModuleConfig "browser.qutebrowser-config").nvidiaQuirks;

          qutebrowserPackage =
            let
              qbWithWideVine = pkgs.qutebrowser.override {
                enableWideVine = true;
              };
            in
            qbWithWideVine.overrideAttrs (oldAttrs: {
              propagatedBuildInputs = oldAttrs.propagatedBuildInputs ++ [
                pkgs.python3Packages.pyqt6
                pkgs.python3Packages.adblock
                pkgs.python3Packages.pynacl
              ];
              buildInputs = oldAttrs.buildInputs ++ [
                pkgs.curl
                pkgs.kdePackages.qtpositioning
              ];
              nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [
                pkgs.makeWrapper
              ];
              postInstall =
                let
                  baseWrapperArgs = ''
                    wrapProgram $out/bin/qutebrowser \
                      --prefix LD_LIBRARY_PATH : "${pkgs.curl.out}/lib" \
                      --prefix XDG_DATA_DIRS : "${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}:${pkgs.gsettings-desktop-schemas}/share" \
                      --prefix QT_PLUGIN_PATH : "${pkgs.kdePackages.qtpositioning}/lib/qt-6/plugins"'';

                  nvidiaWrapperArgs =
                    lib.optionalString (nvidiaQuirks && (self.linux.isModuleEnabled "graphics.nvidia-setup"))
                      ''
                        \
                                               --set QTWEBENGINE_FORCE_USE_GBM "0" \
                                               --set QT_XCB_GL_INTEGRATION "none" \
                                               --set QT_WEBENGINE_DISABLE_GPU "1" \
                                               --set QT_OPENGL "software" \
                                               --set QT6_OPENGL "software" \
                                               --set QT_QUICK_BACKEND "software" \
                                               --set QT_FONT_DPI "96" \
                                               --set QT_WEBENGINE_DISABLE_NOUVEAU_WORKAROUND "1" \
                                               --set QT_AUTO_SCREEN_SCALE_FACTOR "0" \
                                               --set QT_ENABLE_HIGHDPI_SCALING "0" \
                                               --set QT_QPA_NO_SIGNAL_HANDLER "1" \
                                               --set QSG_RHI_PREFER_SOFTWARE_RENDERER "1" \
                                               --set QT_SCALE_FACTOR "1" \
                                               --set QT_NO_OPENGL_BUGLIST "1" \
                                               --set QT_WAYLAND_FORCE_DPI "96" \
                                               --set QSG_RHI_BACKEND "opengl"'';
                in
                oldAttrs.postInstall or ""
                + ''
                  ${baseWrapperArgs}${nvidiaWrapperArgs}
                '';
            });
        in
        {
          nx.linux.desktop.niri.autostartPrograms = lib.mkIf (self.isModuleEnabled "desktop.niri") [
            "qutebrowser"
          ];
          nx.preferences.desktop.programs.webBrowser.package = lib.mkForce qutebrowserPackage;
          nx.linux.browser.qutebrowser.package = qutebrowserPackage;
        }
      );

    linux.home =
      config:
      lib.mkIf self.isX86_64 {
        programs.qutebrowser = {
          package = lib.mkForce config.nx.linux.browser.qutebrowser.package;
        };
      };
  };
}
