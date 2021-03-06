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
  postCommand ? null,
}: outDir:
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

  writeToDir = writeShellScript "lock" ''
    outDir="${outDir}"

    if [[ ! -d "$outDir" ]]
    then
      echo >&2 "Error: Directory $outDir does not exist"
      echo >&2 "Did you run the script from outside the source repository?"
      echo >&2 "If this is what you intended, you should create the directory in advance."
      echo >&2 "Aborting"
      exit 1
    fi

    for file in "$outDir/flake.nix" "$outDir/archive.lock"
    do
      if [[ ! -f "$file" ]]
      then
        touch "$file"
        git add "$file"
      fi
    done

    install -m 644 -t "$outDir" ${src}/*.*

    ${lib.optionalString (postCommand != null) ''
      cd "$outDir"
      ${postCommand}
    ''}
  '';
in
  # This is an app, and not a derivation. See
  # https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-run.html#apps
  {
    type = "app";
    program = writeToDir.outPath;
  }
