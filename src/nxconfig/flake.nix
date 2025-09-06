{
  description = "Personal configuration with additional inputs";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      ...
    }@inputs:
    {
      configInputs = { };
    };
}
