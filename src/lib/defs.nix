{ lib }:
rec {
  rootPath = ./../..;

  nxConfigPath = ".config/nx";
  coreDirName = "nxcore";
  configDirName = "nxconfig";

  localDevelopmentInputs = {
    common = "${nxConfigPath}/${coreDirName}/src/common";
    linux = "${nxConfigPath}/${coreDirName}/src/linux";
    darwin = "${nxConfigPath}/${coreDirName}/src/darwin";
    themes = "${nxConfigPath}/${coreDirName}/src/themes";
    build = "${nxConfigPath}/${coreDirName}/src/build";
    groups = "${nxConfigPath}/${coreDirName}/src/groups";
    config = "${nxConfigPath}/${configDirName}";
    overlays = "${nxConfigPath}/${coreDirName}/src/overlays";
  };

  coreInputs = [
    "common"
    "linux"
    "darwin"
    "themes"
    "build"
    "groups"
    "overlays"
  ];

  moduleInputsToScan = coreInputs ++ [
    "config"
    "profile"
  ];

  allowedLinuxDesktops = [
    "gnome"
    "niri"
  ];

  allowedDarwinDesktops = [
    "amethyst"
    "yabai"
  ];
}
