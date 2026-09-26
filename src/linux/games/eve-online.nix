args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "eve-online";
  description = "EVE Online suite with all related modules and settings";

  group = "games";
  input = "linux";

  submodules = {
    linux.games = {
      eve-lens = true;
      eve-rift = true;
      eve-settings-manager = true;
      steam = true;
      game-quirks = {
        eveOnline = true;
      };
    };
  };

  options = {
    mainCharacterId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Main EVE Online character ID.";
    };
    additionalCharacterIds = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional EVE Online character IDs.";
    };
  };

  module = {
    enabled =
      config:
      let
        characterId = config.nx.linux.games.eve-online.mainCharacterId;
        zkillboardUrl =
          if characterId != null then
            "https://zkillboard.com/character/${characterId}/"
          else
            "https://zkillboard.com";
      in
      {
        nx.common.browser.browser.bookmarks = {
          "Games" = {
            "EVE Online" = {
              "Zkillboard" = zkillboardUrl;
              "Account Management" = "https://secure.eveonline.com/account";
              "Official Store" = "https://store.eveonline.com/";
              "Gatecheck" = "https://eve-gatecheck.space/eve/";
              "EVE Scout" = "https://www.eve-scout.com/#/";
              "EVE-University Wiki" = "https://wiki.eveuniversity.org/Main_Page";
              "Dotlan" = "https://evemaps.dotlan.net/route";
              "PI Planner" = "https://evepitool.com/";
              "Nexum" = "https://eve-nexum.com";
            };
          };
        };
      };
  };
}
