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
  name = "gnome";

  group = "secondary";
  input = "desktops";
  namespace = "home";

  settings = {
    name = "gnome";

    preferences = {
      fileBrowser = {
        package = pkgs.nautilus;
      };
      archiver = {
        package = pkgs.file-roller;
      };
      textEditor = {
        package = pkgs.gedit;
      };
      advancedTextEditor = {
        package = pkgs.gnome-text-editor;
      };
      terminal = {
        package = pkgs.gnome-terminal;
      };
      imageViewer = {
        package = pkgs.eog;
      };
      imageEditor = {
        package = pkgs.gnome-screenshot;
      };
      paintingProgram = {
        package = pkgs.drawing;
      };
      pdfViewer = {
        package = pkgs.evince;
      };
      videoPlayer = {
        package = pkgs.totem;
      };
      musicPlayer = {
        package = pkgs.gnome-music;
      };
      emailClient = {
        package = pkgs.geary;
      };
      calendar = {
        package = pkgs.gnome-calendar;
      };
      contacts = {
        package = pkgs.gnome-contacts;
      };
      diskUsage = {
        package = pkgs.baobab;
      };
      calculator = {
        package = pkgs.gnome-calculator;
      };
      clock = {
        package = pkgs.gnome-clocks;
      };
      webBrowser = {
        package = pkgs.epiphany;
      };
      dialog = {
        package = pkgs.zenity;
      };
      gitGui = {
        package = pkgs.gitg;
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
        pkgs.xdg-desktop-portal-gnome
        pkgs.xdg-desktop-portal-gtk
      ];
      additionalBasePackages = [
        pkgs.libnotify
      ];
      additionalDesktopPrograms = [
        pkgs.easytag
        pkgs.popsicle
        pkgs.cheese
      ];
      gamePackages = [
        pkgs.gnome-mines
        pkgs.aisleriot
        pkgs.gnome-sudoku
      ];
    };
  };
}
