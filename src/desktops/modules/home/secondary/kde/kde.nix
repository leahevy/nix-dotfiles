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
  name = "kde";

  group = "secondary";
  input = "desktops";
  namespace = "home";

  settings = {
    name = "kde";

    preferences = {
      fileBrowser = {
        package = pkgs.kdePackages.dolphin;
      };
      archiver = {
        package = pkgs.kdePackages.ark;
      };
      textEditor = {
        package = pkgs.kdePackages.kate;
      };
      advancedTextEditor = {
        package = pkgs.kdePackages.ghostwriter;
      };
      terminal = {
        package = pkgs.kdePackages.konsole;
      };
      imageViewer = {
        package = pkgs.kdePackages.gwenview;
      };
      imageEditor = {
        package = pkgs.kdePackages.spectacle;
      };
      paintingProgram = {
        package = pkgs.kdePackages.kolourpaint;
      };
      pdfViewer = {
        package = pkgs.kdePackages.okular;
      };
      videoPlayer = {
        package = pkgs.kdePackages.dragon;
      };
      musicPlayer = {
        package = pkgs.kdePackages.elisa;
      };
      emailClient = {
        package = pkgs.kdePackages.kmail;
      };
      calendar = {
        package = pkgs.kdePackages.korganizer;
      };
      contacts = {
        package = pkgs.kdePackages.kaddressbook;
      };
      diskUsage = {
        package = pkgs.kdePackages.filelight;
      };
      calculator = {
        package = pkgs.kdePackages.kcalc;
      };
      clock = {
        package = pkgs.kdePackages.kclock;
      };
      webBrowser = {
        package = pkgs.kdePackages.falkon;
      };
      dialog = {
        package = pkgs.kdePackages.kdialog;
      };
      gitGui = {
        name = "dolphin";
        package = pkgs.kdePackages.dolphin-plugins;
        openCommand = "dolphin";
        openFileCommand = "dolphin";
      };
      officeSuite = {
        name = "onlyoffice";
        package = pkgs.onlyoffice-desktopeditors;
        desktopFile = "onlyoffice-desktopeditors.desktop";
      };
      drawingProgram = {
        package = pkgs.gimp;
      };
      desktopPortals = [
        pkgs.xdg-desktop-portal
        pkgs.kdePackages.xdg-desktop-portal-kde
      ];
      additionalBasePackages = [
        pkgs.libnotify
        pkgs.kdePackages.qttools
        pkgs.kdePackages.kcmutils
      ];
      additionalDesktopPrograms = [
        pkgs.easytag
        pkgs.popsicle
        pkgs.cheese
      ];
      gamePackages = [
        pkgs.kdePackages.kmines
        pkgs.kdePackages.kpat
        pkgs.kdePackages.ksudoku
      ];
    };
  };
}
