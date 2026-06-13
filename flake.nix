{
  description = "Packwiz environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        buildInputs = with pkgs; [ packwiz ];
      };
      packages.x86_64-linux.default = pkgs.callPackage ./package.nix { src = ./.; };
    };
}
