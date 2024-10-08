{
  lib,
  nix,
  nixfmt-rfc-style,
  jq,
  coreutils,
  runCommandLocal,
  writeTextFile,
  writeShellScript,
  writeShellApplication,
  # Current version
  flakeLockFile ? null,
}: {
  packageInputs,
  flakeNix ? false,
  archiveLock ? false,
  metadataJson ? false,
  # Command run after writing the directory in asAppWritingToRelativeDir
  postCommand ? null,
}:
assert (flakeNix || archiveLock); let
  inherit (builtins) toJSON attrNames mapAttrs;

  archiveLockData = lib.pipe packageInputs [
    (lib.filterAttrs (_: attrs: attrs ? archive))
    (mapAttrs (_:
      lib.getAttrs [
        "version"
        "archive"
        "packageRequires"
        "inventory"
      ]))
  ];

  packageMetadata =
    mapAttrs (name: attrs: {
      inherit (attrs.src) narHash;
      inherit (attrs) version packageRequires meta;
      # There can be packages that lack Author header, so set null in that case.
      author =
        attrs.author
        or (builtins.trace "Warning: Package ${name} lacks Author header. This still works, but it is considered a bad practice." null);
    })
    packageInputs;

  data = {
    flakeNix = lib.toNix {
      description = "THIS IS AN AUTO-GENERATED FILE. PLEASE DON'T EDIT IT MANUALLY.";
      inputs = lib.pipe packageInputs [
        (lib.filterAttrs (_: attrs: attrs ? origin))
        (lib.mapAttrs (_: {origin, ...}: origin // {flake = false;}))
      ];
      outputs = {...}: {};
    };
    archiveLock = toJSON archiveLockData;
    metadataJson = toJSON packageMetadata;
  };

  passAsFile =
    lib.optional flakeNix "flakeNix"
    ++ lib.optional archiveLock "archiveLock"
    ++ lib.optional metadataJson "metadataJson";

  # HACK: Use sed to convert JSON to Nix
  #
  # It would be better to use either nix-eval or nix-instantiate to generate a
  # proper Nix, but it is troublesome to run a nested Nix during a build phase.
  generateFlakeNix = ''
    sed -e 's/<LAMBDA>/{ ... }: { }/' $flakeNixPath > "$out/flake.nix"
    ${nixfmt-rfc-style}/bin/nixfmt "$out/flake.nix"
  '';

  generateArchiveLock = ''
    ${jq}/bin/jq . "$archiveLockPath" > "$out/archive.lock"
  '';

  generateMetadataJson = ''
    ${jq}/bin/jq . "$metadataJsonPath" > "$out/metadata.json"
  '';

  src =
    runCommandLocal "emacs-twist-lock" ({
        inherit passAsFile;
      }
      // lib.getAttrs passAsFile data)
    ''
      mkdir -p $out

      ${lib.optionalString flakeNix generateFlakeNix}
      ${lib.optionalString archiveLock generateArchiveLock}
      ${lib.optionalString metadataJson generateMetadataJson}
    '';
in {
  asAppWritingToRelativeDir = outDir: {
    # This is an app, and not a derivation. See
    # https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-run.html#apps
    type = "app";
    program =
      (import ./write-lock-1.nix {inherit lib writeShellScript;} {
        inherit outDir src postCommand coreutils;
      })
      .outPath;
  };

  writerScript = {postCommandOnGeneratingLockDir}:
    writeShellApplication {
      name = "emacs-twist-write-lock";
      runtimeInputs = [ coreutils ];
      text =
        builtins.replaceStrings [
          "@lockSrcDir@"
          "@postCommand@"
        ] [
          src.outPath
          (lib.optionalString (builtins.isString postCommandOnGeneratingLockDir) ''
            ( cd "$outDir" && cd "$(git rev-parse --show-toplevel)" &&
              ( ${postCommandOnGeneratingLockDir} )
            )
          '')
        ]
        (builtins.readFile ./write-lock-2.bash);
    };
}
