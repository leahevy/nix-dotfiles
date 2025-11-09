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
  namespace = "home";

  unfree = [ "widevine-cdm" ];

  submodules = {
    common = {
      browser = {
        qutebrowser-config = true;
      };
    };
  };

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");

      customPkgs = self.pkgs-unstable {
        overlays = [
          (final: prev: {
            qutebrowser =
              let
                qbWithWideVine = prev.qutebrowser.override {
                  enableWideVine = true;
                };
              in
              qbWithWideVine.overrideAttrs (oldAttrs: {
                propagatedBuildInputs = oldAttrs.propagatedBuildInputs ++ [
                  final.python3Packages.pyqt6
                  final.python3Packages.adblock
                  final.python3Packages.pynacl
                ];
                buildInputs = oldAttrs.buildInputs ++ [
                  prev.curl
                  prev.kdePackages.qtpositioning
                ];
                nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [
                  prev.makeWrapper
                ];
                postInstall = oldAttrs.postInstall or "" + ''
                  wrapProgram $out/bin/qutebrowser \
                    --prefix LD_LIBRARY_PATH : "${prev.curl.out}/lib" \
                    --prefix XDG_DATA_DIRS : "${prev.gtk3}/share/gsettings-schemas/${prev.gtk3.name}:${prev.gsettings-desktop-schemas}/share" \
                    --prefix QT_PLUGIN_PATH : "${prev.kdePackages.qtpositioning}/lib/qt-6/plugins" \
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
                    --set QSG_RHI_BACKEND "opengl" \
                    --set QTWEBENGINE_CHROMIUM_FLAGS "--disable-gpu --disable-gpu-compositing --disable-software-rasterizer --disable-features=VizDisplayCompositor --force-device-scale-factor=1"
                '';
              });
          })
        ];
      };
    in
    {
      programs.qutebrowser = {
        package = lib.mkForce customPkgs.qutebrowser;
      };
    };
}
