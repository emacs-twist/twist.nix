{
  lib,
  nix,
  nixfmt,
  jq,
  runCommandLocal,
  writeTextFile,
  writeShellScript,
  # Current version
  flakeLockFile ? null,
}: {
  packageInputs,
  flakeNix ? false,
  flakeLock ? false,
  archiveLock ? false,
  # Command run after writing the directory in asAppWritingToRelativeDir
  postCommand ? null,
}:
assert (flakeNix || flakeLock || archiveLock); let
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
    flakeLock = toJSON (import ./flake-lock.nix {
      inherit lib flakeLockFile packageInputs;
    });
    archiveLock = toJSON archiveLockData;
  };

  passAsFile =
    lib.optional flakeNix "flakeNix"
    ++ lib.optional flakeLock "flakeLock"
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

  generateFlakeLock = ''
    ${jq}/bin/jq . "$flakeLockPath" > "$out/flake.lock"
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
      ${lib.optionalString flakeLock generateFlakeLock}
      ${lib.optionalString archiveLock generateArchiveLock}
    '';
in {
  asAppWritingToRelativeDir = outDir: {
    # This is an app, and not a derivation. See
    # https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-run.html#apps
    type = "app";
    program =
      (import ./write-lock-1.nix {inherit writeShellScript;} {
        inherit outDir src postCommand;
      })
      .outPath;
  };
}
