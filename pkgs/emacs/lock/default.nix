{
  lib,
  nix,
  nixfmt,
  jq,
  runCommandLocal,
  writeTextFile,
  writeShellScript,
  writeShellApplication,
  # Current version
  flakeLockFile ? null,
}: {
  emacsName,
  packageInputs,
  flakeNix ? false,
  archiveLock ? false,
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
  };

  passAsFile =
    lib.optional flakeNix "flakeNix"
    ++ lib.optional archiveLock "archiveLock";

  # HACK: Use sed to convert JSON to Nix
  #
  # It would be better to use either nix-eval or nix-instantiate to generate a
  # proper Nix, but it is troublesome to run a nested Nix during a build phase.
  generateFlakeNix = ''
    ${nixfmt}/bin/nixfmt < $flakeNixPath \
      | sed -e 's/<LAMBDA>/{ ... }: { }/' \
      > "$out/flake.nix"
  '';

  generateArchiveLock = ''
    ${jq}/bin/jq . "$archiveLockPath" > "$out/archive.lock"
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
    '';
in {
  asAppWritingToRelativeDir = outDir: {
    # This is an app, and not a derivation. See
    # https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-run.html#apps
    type = "app";
    program =
      (import ./write-lock-1.nix {inherit lib writeShellScript;} {
        inherit outDir src postCommand;
      })
      .outPath;
  };

  writerScript = {postCommandOnGeneratingLockDir}:
    writeShellApplication {
      name = "twist-write-lock-${emacsName}";
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
