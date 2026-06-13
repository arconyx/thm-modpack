# Modified from https://github.com/getchoo/packwiz2nix/blob/1c9c0ef2e40fbd1a921b446d8fe5884e645e4308/lib/default.nix#L67
# Original file MIT Licensed, MIT License, Copyright 2022 seth
{
  stdenvNoCC,
  lib,
  fetchurl,

  src,
}:
let
  inherit (builtins)
    readFile
    filter
    ;

  #  Fetch the mods defined in .pw.toml files within src/mods
  tomlFiles = lib.fileset.toList (lib.fileset.fileFilter (file: file.hasExt "toml") (src + "/mods"));
  # Convert packwiz toml files into a list of toml data
  modDataList = map (path: fromTOML (readFile path)) tomlFiles;
  # Filter mod list to only serverside mods
  serverMods = filter (mod: mod.side == "server" || mod.side == "both") modDataList;
  # Fetch mods from the remotes
  modStorePaths = map (
    toml:
    fetchurl {
      name = toml.filename;
      outputHash = toml.download.hash;
      outputHashAlgo = toml.download.hash-format;
      inherit (toml.download) url;
    }
  ) serverMods;

  copyAllMods = lib.concatLines (map (mod: "cp ${mod} mods/${mod.name}") modStorePaths);

  manifest = fromTOML (readFile (src + "/pack.toml"));

in
stdenvNoCC.mkDerivation {
  inherit src manifest;

  pname = manifest.name;
  version = manifest.version;

  # This could be reworked to replace all .pw.toml files
  # everywhere with their downloaded equivalents. This
  # would fix the ongoing problem with not being able to
  # use packwiz mods in the config dir
  buildPhase = ''
    rm -r mods/*.pw.toml
    ${copyAllMods}
  '';

  installPhase = ''
    mkdir -p $out
    cp * -r $out/
  '';

  __structuredAttrs = true;
}
