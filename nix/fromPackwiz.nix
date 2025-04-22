# Modified from https://github.com/getchoo/packwiz2nix/blob/1c9c0ef2e40fbd1a921b446d8fe5884e645e4308/lib/default.nix#L67
# Original file MIT Licensed, MIT License, Copyright 2022 seth
# and
# https://github.com/Infinidoge/nix-minecraft/blob/08e7432873f6af108912006a40629ab7799799e2/pkgs/tools/fetchPackwizModpack/default.nix
# Original file MIT Licensed, Copyright 2022 Infinidoge

let
  inherit (builtins)
    attrNames
    listToAttrs
    mapAttrs
    readDir
    readFile
    replaceStrings
    fromTOML
    ;

  # loads data from a toml json given
  # the directory (dir) and filename (name)
  # string -> string -> attrset
  fromMod = dir: name: fromTOML (readFile "${dir}/${name}");

  # replaces `.pw.toml` extensions with `.jar`
  # to correct the store paths of jarfiles
  # string -> string
  fixupName = replaceStrings [ ".pw.toml" ] [ ".jar" ];

  # *pkgs*.fetchurl wrapper that downloads a
  # jarfile mod. pkgs.fetchurl is used over builtins
  # here since we have a checksum and can take advantage
  # of fixed output derivations
  # attrset -> string -> attrset -> store path
  fetchMod =
    pkgs: name: mod:
    pkgs.fetchurl {
      name = fixupName name;
      outputHash = mod.download.hash;
      outputHashAlgo = mod.download.hash-format;
      inherit (mod.download) url;
    };

  # maps each mod to the store path of a fixed output derivation
  # attrset -> attrset
  fetchMods = pkgs: mapAttrs (fetchMod pkgs);

  # this is probably what you're looking for if
  # you're an end user trying to implement a modpack in
  # your module.
  #
  # `pkgs` is an instance of nixpkgs for your system,
  # must at least contain `fetchurl`.
  #
  # `dir` is a directory containing the packwiz mod.pw.toml files
  #
  # attrset -> path -> attrset
  mkPackwizPackages = pkgs: dir: fetchMods pkgs (mkModAttrset dir);

  # this is probably what you're looking for if
  # you're a developer trying to use this in your modpack.
  # this is where you create a checksums file for end users
  # to put into mkPackwizPackages, so make sure you keep it up to
  # date!
  #
  # `dir` is a path to the folder containing your .pw.toml files
  # files for mods. make sure they are the only files in the folder
  #
  # path -> attrset
  mkModAttrset =
    dir:
    let
      mods = readDir dir;
    in
    mapAttrs (mod: _: fromMod dir mod) mods;

  # this creates an attrset value for
  # minecraft-servers.servers.<server>.symlinks
  # attrset -> attrset
  mkModLinks =
    mods:
    let
      fixup = map (name: {
        name = "mods/" + fixupName name;
        value = mods.${name};
      }) (attrNames mods);
    in
    listToAttrs fixup;

in
{
  inherit mkPackwizPackages mkModAttrset;

  package =
    pkgs: src:
    let
      manifest = fromTOML (readFile (src + "/pack.toml"));
      modLinks = mkModLinks (mkPackwizPackages pkgs (src + "/mods"));
    in
    pkgs.stdenvNoCC.mkDerivation {
      inherit src;

      pname = manifest.name;
      version = manifest.version;

      installPhase = ''
        mkdir -p $out
        cp -r ./config $out/config
      '';
    }
    // {
      passthru = {
        inherit manifest modLinks;
      };
    };
}
