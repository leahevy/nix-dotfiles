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
    build = "${nxConfigPath}/${coreDirName}/src/build";
    groups = "${nxConfigPath}/${coreDirName}/src/groups";
    config = "${nxConfigPath}/${configDirName}";
  };
}
