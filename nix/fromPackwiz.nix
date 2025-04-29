# Modified from https://github.com/getchoo/packwiz2nix/blob/1c9c0ef2e40fbd1a921b446d8fe5884e645e4308/lib/default.nix#L67
# Original file MIT Licensed, MIT License, Copyright 2022 seth

let
  inherit (builtins)
    attrNames
    baseNameOf
    listToAttrs
    mapAttrs
    readFile
    replaceStrings
    fromTOML
    filter
    ;

  tomlFiles =
    pkgs: dir: pkgs.lib.fileset.toList (pkgs.lib.fileset.fileFilter (file: file.hasExt "toml") dir);
  jarFiles =
    pkgs: dir: pkgs.lib.fileset.toList (pkgs.lib.fileset.fileFilter (file: file.hasExt "jar") dir);

  # loads data from a toml json given
  # the directory (dir) and filename (name)
  # string -> string -> attrset
  fromMod = path: fromTOML (readFile path);

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
  # list -> attrset
  fetchMods = pkgs: mapAttrs (fetchMod pkgs);

  # get store paths for all external mods
  # `pkgs` is an instance of nixpkgs for your system,
  # must at least contain `fetchurl`.
  #
  # `dir` is a directory containing the packwiz mod.pw.toml files
  #
  # attrset -> path -> attrset
  mkPackwizPackages = pkgs: dir: fetchMods pkgs (mkModAttrset pkgs dir);

  # attrset -> boolean
  isServerMod = mod: mod.value.side == "server" || mod.value.side == "both";

  # `dir` is a path to the folder containing your .pw.toml files
  # files for mods. make sure they are the only files in the folder

  mkModAttrset =
    pkgs: dir:
    listToAttrs (
      filter isServerMod (
        map (path: {
          name = baseNameOf path;
          value = fromMod path;
        }) (tomlFiles pkgs dir)
      )
    );

  # this creates an attrset value for
  # minecraft-servers.servers.<server>.symlinks
  # This function takes external mods (from packwiz mod.pw.toml files) and local jar paths.
  mkModLinks =
    fetchedMods: localJars:
    let
      # Symlinks for fetched mods
      fetchedLinks = map (name: {
        name = "mods/" + fixupName name;
        value = fetchedMods.${name};
      }) (attrNames fetchedMods);

      # Symlinks for local jars
      localLinks = map (localJarPath: {
        name = "mods/" + (baseNameOf localJarPath); # Get filename from path
        value = localJarPath; # Use the path directly
      }) localJars;
    in
    listToAttrs (fetchedLinks ++ localLinks); # Combine both lists

in
{
  inherit mkPackwizPackages mkModAttrset;

  package =
    pkgs: src:
    let
      manifest = fromTOML (readFile (src + "/pack.toml"));
      #  Fetch the mods defined in .pw.toml files within src/mods
      fetchedMods = mkPackwizPackages pkgs (src + "/mods");
      # Find the local .jar files directly within src/mods at evaluation time
      localJars = jarFiles pkgs (src + "/mods");
    in
    pkgs.stdenvNoCC.mkDerivation {
      inherit src;

      pname = manifest.name;
      version = manifest.version;

      # it might be good to validate hashes
      # but this should mostly be handled by flake.lock

      installPhase = ''
        mkdir -p $out/config
        cp -r ./config/* $out/config/ || true # Copy config if it exists
      '';

      passthru = {
        inherit manifest;
        modLinks = mkModLinks fetchedMods localJars;
      };
    };
}
