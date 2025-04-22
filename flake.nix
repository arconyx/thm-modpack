{
  description = "Packwiz environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = import ./nix/fromPackwiz.nix;
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [ packwiz ];
        };
        apps.generateModSet = lib.mkModAttrsetApp pkgs ./mods;
      }
    );
}
