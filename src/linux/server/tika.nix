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
  name = "tika";
  description = "Apache Tika document content extraction service";

  group = "server";
  input = "linux";

  options = {
    ocrLanguages = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      description = "Tesseract OCR language codes for Tika embedded-image OCR, or null to auto-derive from linux.server.paperless-ngx when enabled.";
    };
  };

  module = {
    ifEnabled.linux.server.paperless-ngx = {
      linux.system = config: {
        services.paperless.configureTika = true;
      };
    };

    linux.system =
      { config, ocrLanguages, ... }:
      let
        effectiveLanguages =
          if ocrLanguages != null then
            ocrLanguages
          else if config.nx.linux.server.paperless-ngx.enable then
            lib.splitString "+" config.nx.linux.server.paperless-ngx.ocrLanguage
          else
            [
              "deu"
              "eng"
            ];
      in
      {
        services.tika = {
          enable = true;
          package = pkgs.tika.override {
            tesseract = pkgs.tesseract5.override {
              enableLanguages = lib.unique (
                [
                  "equ"
                  "osd"
                  "eng"
                ]
                ++ effectiveLanguages
              );
            };
          };
        };
      };
  };
}
