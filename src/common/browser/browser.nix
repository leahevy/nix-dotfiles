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
let
  searchEngineType = lib.types.submodule {
    options = {
      shortName = lib.mkOption { type = lib.types.str; };
      queryUrl = lib.mkOption { type = lib.types.str; };
      homeUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
    };
  };
in
{
  name = "browser";

  group = "browser";
  input = "common";

  options = {
    privacySearch = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    startpageAsPrivacySearch = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    addAmazon = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    amazonDomain = lib.mkOption {
      type = lib.types.str;
      default = "amazon.com";
    };
    googleDomain = lib.mkOption {
      type = lib.types.str;
      default = "google.com";
    };
    home = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    baseBookmarks = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {
        nixpkgs = "https://github.com/NixOS/nixpkgs";
        nix-datatypes = "https://nlewo.github.io/nixos-manual-sphinx/development/option-types.xml.html";
        nixos-wiki = "https://nixos.wiki/wiki/Main_Page";
        mynixos = "https://mynixos.com/";
        nx = "https://github.com/leahevy/nix-dotfiles";
        nxac = "https://github.com/leahevy/nix-dotfiles/actions/workflows/update-flake-lock.yml";
        nxpr = "https://github.com/leahevy/nix-dotfiles/pulls";
      };
    };
    bookmarks = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
    };
    baseSearchEngines = lib.mkOption {
      type = lib.types.attrsOf searchEngineType;
      default = {
        nix-packages = {
          shortName = "pkgs";
          queryUrl = "https://search.nixos.org/packages?query={}";
        };
        nix-options = {
          shortName = "opts";
          queryUrl = "https://search.nixos.org/options?query={}";
        };
        mynixos = {
          shortName = "nix";
          queryUrl = "https://mynixos.com/search?q={}";
        };
      };
    };
    additionalSearchEngines = lib.mkOption {
      type = lib.types.attrsOf searchEngineType;
      default = { };
    };
    themedCSS = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    defaultSearchUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://www.startpage.com/sp/search?q=";
    };
    homeUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://www.startpage.com";
    };
    final = lib.mkOption {
      type = lib.types.submodule {
        options = {
          searchEngines = lib.mkOption {
            type = lib.types.attrsOf searchEngineType;
            default = { };
          };
          bookmarks = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = { };
          };
          userContentCSS = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.submodule {
                options = {
                  data = lib.mkOption { type = lib.types.str; };
                  derivation = lib.mkOption { type = lib.types.package; };
                };
              }
            );
            default = null;
          };
        };
      };
      default = { };
    };
  };

  module = {
    enabled = config: {
      nx.common.browser.browser.defaultSearchUrl =
        if config.nx.common.browser.browser.privacySearch then
          if config.nx.common.browser.browser.startpageAsPrivacySearch then
            "https://www.startpage.com/sp/search?q="
          else
            "https://duckduckgo.com/?q="
        else
          "https://${config.nx.common.browser.browser.googleDomain}/search?q=";

      nx.common.browser.browser.homeUrl =
        if config.nx.common.browser.browser.home != null then
          config.nx.common.browser.browser.home
        else if config.nx.common.browser.browser.privacySearch then
          if config.nx.common.browser.browser.startpageAsPrivacySearch then
            "https://www.startpage.com"
          else
            "https://duckduckgo.com"
        else
          "https://${config.nx.common.browser.browser.googleDomain}";

      nx.common.browser.browser.final.searchEngines = {
        google = {
          shortName = "google";
          queryUrl = "https://${config.nx.common.browser.browser.googleDomain}/search?q={}";
          homeUrl = "https://${config.nx.common.browser.browser.googleDomain}";
        };
      }
      // lib.optionalAttrs config.nx.common.browser.browser.addAmazon {
        amazon = {
          shortName = "amazon";
          queryUrl = "https://${config.nx.common.browser.browser.amazonDomain}/s?k={}";
          homeUrl = "https://${config.nx.common.browser.browser.amazonDomain}";
        };
      }
      // lib.optionalAttrs config.nx.common.browser.browser.startpageAsPrivacySearch {
        startpage = {
          shortName = "start";
          queryUrl = "https://www.startpage.com/sp/search?q={}";
          homeUrl = "https://www.startpage.com";
        };
      }
      // lib.optionalAttrs (!config.nx.common.browser.browser.startpageAsPrivacySearch) {
        duckduckgo = {
          shortName = "duck";
          queryUrl = "https://duckduckgo.com/?q={}";
          homeUrl = "https://duckduckgo.com";
        };
      }
      // config.nx.common.browser.browser.baseSearchEngines
      // config.nx.common.browser.browser.additionalSearchEngines;

      nx.common.browser.browser.final.bookmarks =
        lib.recursiveUpdate config.nx.common.browser.browser.baseBookmarks config.nx.common.browser.browser.bookmarks;

      nx.common.browser.browser.final.userContentCSS =
        lib.mkIf config.nx.common.browser.browser.themedCSS
          (
            let
              data =
                builtins.replaceStrings
                  [
                    "#000"
                    "#262626"
                    "#2a2a2a"
                    "#2e2e2e"
                    "#323232"
                    "#363636"
                    "#2c4125"
                    "#5e6263"
                    "#797fd4"
                    "#909396"
                    "#a6aaab"
                    "#b8bbbd"
                    "#c7c9ca"
                    "#d2d8d9"
                    "#fff"
                    "#fba"
                    "#aba"
                    "#2f7bde"
                    "#639ce6"
                    "#15968d"
                    "#436237"
                    "#598249"
                    "#b68800"
                    "#e05f27"
                    "#5e1c19"
                    "#bd3832"
                    "#ce4139"
                    "#a8366b"
                  ]
                  [
                    config.nx.preferences.theme.colors.main.backgrounds.primary.html
                    config.nx.preferences.theme.colors.main.backgrounds.primary.html
                    config.nx.preferences.theme.colors.main.backgrounds.primary.html
                    config.nx.preferences.theme.colors.main.backgrounds.primary.html
                    config.nx.preferences.theme.colors.main.backgrounds.secondary.html
                    config.nx.preferences.theme.colors.main.backgrounds.tertiary.html
                    config.nx.preferences.theme.colors.main.backgrounds.themed.html
                    config.nx.preferences.theme.colors.main.foregrounds.subtle.html
                    config.nx.preferences.theme.colors.main.foregrounds.secondary.html
                    config.nx.preferences.theme.colors.main.foregrounds.subtle.html
                    config.nx.preferences.theme.colors.main.foregrounds.secondary.html
                    config.nx.preferences.theme.colors.main.foregrounds.strong.html
                    config.nx.preferences.theme.colors.main.foregrounds.strong.html
                    config.nx.preferences.theme.colors.main.foregrounds.strong.html
                    config.nx.preferences.theme.colors.main.foregrounds.primary.html
                    config.nx.preferences.theme.colors.main.foregrounds.emphasized.html
                    config.nx.preferences.theme.colors.main.foregrounds.strong.html
                    config.nx.preferences.theme.colors.semantic.modifiedDarker.html
                    config.nx.preferences.theme.colors.semantic.removedDarker.html
                    config.nx.preferences.theme.colors.semantic.success.html
                    config.nx.preferences.theme.colors.semantic.successDarker.html
                    config.nx.preferences.theme.colors.semantic.success.html
                    config.nx.preferences.theme.colors.semantic.warning.html
                    config.nx.preferences.theme.colors.semantic.error.html
                    config.nx.preferences.theme.colors.semantic.errorDarker.html
                    config.nx.preferences.theme.colors.semantic.info.html
                    config.nx.preferences.theme.colors.semantic.info.html
                    config.nx.preferences.theme.colors.semantic.selected.html
                  ]
                  (
                    builtins.readFile "${self.inputs.solarized-everything-css}/css/darculized/darculized-all-sites.css"
                  );
            in
            {
              inherit data;
              derivation = pkgs.writeText "browser-user-content.css" data;
            }
          );
    };
  };
}
