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
    baseOcrLanguages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "deu"
        "eng"
      ];
      description = "Base Tesseract OCR language codes always included in the Tika build, independent of module contributions.";
    };

    ocrLanguages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional Tesseract OCR language codes contributed by other modules, concatenated with baseOcrLanguages.";
    };
  };

  module = {
    enabled = config: {
      nx.packages.extra = [ pkgs.tika ];
    };

    ifEnabled.linux.server.paperless-ngx = {
      linux.system = config: {
        services.paperless.configureTika = true;
      };
    };

    linux.system =
      {
        config,
        baseOcrLanguages,
        ocrLanguages,
        ...
      }:
      let
        effectiveLanguages = lib.unique (
          [
            "equ"
            "osd"
            "eng"
          ]
          ++ baseOcrLanguages
          ++ ocrLanguages
        );
      in
      {
        services.tika = {
          enable = true;
          package = pkgs.tika.override {
            tesseract = pkgs.tesseract5.override {
              enableLanguages = effectiveLanguages;
            };
          };
        };
      };
  };
}
