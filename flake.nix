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
        fromPackwiz = import ./nix/fromPackwiz.nix;
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [ packwiz ];
        };
        packages.default = fromPackwiz.package pkgs ./.;
      }
    );
}
