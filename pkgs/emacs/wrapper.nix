{
  lib,
  stdenv,
  runCommandLocal,
  makeWrapper,
  writeText,
  writeShellScript,
  buildEnv,
  emacs,
  lndir,
  texinfo,
  packageNames,
  elispPackages,
  executablePackages,
  extraOutputsToInstall,
  exportManifest,
  configurationRevision,
  extraSiteStartElisp,
}: let
  inherit (builtins) length;

  elispInputs = lib.attrVals packageNames elispPackages;

  nativeComp = emacs.withNativeCompilation or emacs.nativeComp or false;

  # Use a symlink farm for specifying subdirectory names inside site-lisp.
  packageEnv = buildEnv {
    name = "elisp-packages";
    paths = elispInputs;
    pathsToLink =
      [
        "/share/info"
      ]
      ++ lib.optional nativeComp "/share/emacs/native-lisp";
    inherit extraOutputsToInstall;
    buildInputs = [
      texinfo
    ];
    postBuild = ''
      if [[ -w $out/share/info ]]
      then
        shopt -s nullglob
        for i in $out/share/info/*.info $out/share/info/*.info.gz; do
          install-info $i $out/share/info/dir
        done
      fi
    '';
  };

  selfInfo = builtins.path {
    name = "emacs-twist.info";
    path = ../../doc/emacs-twist.info;
  };

  wrap = open: end: body: open + body + end;

  lispList = strings:
    wrap "'(" ")"
    (lib.concatMapStringsSep " " (wrap "\"" "\"") strings);

  nativeLoadPath = "${packageEnv}/share/emacs/native-lisp/";

  infoPath = "${packageEnv}/share/info";

  elispManifest = writeText "elisp-digest.json" (builtins.toJSON {
    inherit configurationRevision;
    emacsPath = emacs.outPath;
    inherit nativeLoadPath infoPath;
    elispPackages = lib.genAttrs packageNames (
      name: "${elispPackages.${name}}/share/emacs/site-lisp/"
    );
    executablePackages = map (pkg: "${pkg}/bin") executablePackages;
  });

  macosAppLauncher = writeShellScript "emacs-launcher" ''
    SCRIPT_DIR="$( cd "$( dirname "''${BASH_SOURCE[0]}" )" && pwd )"
    APP_CONTENTS="$(dirname "$SCRIPT_DIR")"
    APP_RESOURCES="$APP_CONTENTS/Resources"

    # Use a login shell to source the Nix environment
    # This ensures we get the same environment
    exec -l "$SHELL" -c '
      if [[ -d "'$APP_RESOURCES'/site-lisp" ]]; then
        export EMACSLOADPATH="'$APP_RESOURCES'/site-lisp:"
      fi

      if [[ -d "'$APP_RESOURCES'/info" ]]; then
        export INFOPATH="'$APP_RESOURCES'/info:${emacs}/share/info''${INFOPATH:+:$INFOPATH}"
      fi

      ${lib.optionalString nativeComp ''
      if [[ -d "'$APP_RESOURCES'/native-lisp" ]]; then
        export EMACSNATIVELOADPATH="'$APP_RESOURCES'/native-lisp:${packageEnv}/share/emacs/native-lisp:"
      fi
      ''}

      if [[ -d "'$APP_RESOURCES'/bin" ]]; then
        export PATH="'$APP_RESOURCES'/bin:$PATH"
      fi

      exec "'$SCRIPT_DIR'/_Emacs" "$@"
    ' emacs-launcher "$@"
  '';
in
  runCommandLocal "emacs"
  {
    buildInputs = [lndir texinfo];
    propagatedBuildInputs = [emacs packageEnv] ++ executablePackages;
    nativeBuildInputs = [makeWrapper];
    # Support for nix run
    meta.mainProgram = "emacs";

    passAsFile = ["subdirs" "siteStartExtra"];

    nativeLoadPath = "${nativeLoadPath}:${emacs}/share/emacs/native-lisp/:";

    subdirs = ''
      (setq load-path (append ${
        lispList (map (pkg: "${pkg}/share/emacs/site-lisp/") elispInputs)
      } load-path))
    '';

    siteStartExtra = ''
      (when init-file-user
        ${lib.optionalString exportManifest ''
        (defconst twist-running-emacs "${emacs.outPath}")
        (defconst twist-current-manifest-file "${elispManifest}")
      ''}
        ${lib.optionalString (configurationRevision != null) ''
          (defvar twist-configuration-revision "${configurationRevision}")
        ''}
        ${
        lib.concatMapStrings (pkg: ''
          (load "${pkg}/share/emacs/site-lisp/${pkg.ename}-autoloads.el" t t)
        '')
        elispInputs
        })
      ${extraSiteStartElisp}
    '';

    elispManifestPath =
      if exportManifest
      then elispManifest.outPath
      else null;
  }
  ''
    mkdir -p $out/bin
    lndir -silent ${emacs}/bin $out/bin

    mkdir -p $out/share
    for dir in applications icons
    do
      ln -s ${emacs}/share/$dir $out/share/$dir
    done

    if [[ $(${emacs}/bin/emacs --version) =~ GNU\ Emacs\ ([[:digit:]]+((\.[[:digit:]]+)+)) ]]
    then
      version=''${BASH_REMATCH[1]}
    else
      echo "Error: Failed to parse the version of Emacs. See the output below" >&2
      ${emacs}/bin/emacs --version
      exit 1
    fi

    mkdir -p $out/share/emacs
    ln -s ${emacs}/share/emacs/$version $out/share/emacs/$version

    siteLisp=$out/share/emacs/site-lisp
    mkdir -p $siteLisp
    if [[ -e $subdirsPath ]]
    then
      install -m 444 $subdirsPath $siteLisp/subdirs.el
    else
      echo -n "$subdirs" > $siteLisp/subdirs.el
    fi

    # Append autoloads to the site-start.el provided by nixpkgs
    origSiteStart="${emacs}/share/emacs/site-lisp/site-start.el"
    if [[ -f "$origSiteStart" ]]
    then
      install -m 644 "$origSiteStart" $siteLisp/site-start.el
    else
      touch $siteLisp/site-start.el
    fi
    if [[ -e $siteStartExtraPath ]]
    then
      cat $siteStartExtraPath >> $siteLisp/site-start.el
    else
      echo -n "$siteStartExtra" >> $siteLisp/site-start.el
    fi

    cd $siteLisp
    ${emacs}/bin/emacs --batch -f batch-byte-compile site-start.el
    ${lib.optionalString nativeComp ''
      # Work around preloaded native lisp.
      ln -t $out -s ${emacs}/lib/emacs/$version/native-lisp

      nativeLisp=$out/share/emacs/native-lisp
      emacs --batch \
        --eval "(push \"$nativeLisp/\" native-comp-eln-load-path)" \
        --eval "(setq native-compile-target-directory \"$nativeLisp/\")" \
        -f batch-native-compile "$siteLisp/site-start.el"
    ''}

    mkdir -p $out/share/info
    install ${selfInfo} $out/share/info/emacs-twist.info
    install-info $out/share/info/emacs-twist.info $out/share/info/dir

    for bin in $out/bin/*
    do
      if [[ $(basename $bin) = emacs-* ]]
      then
      wrapProgram $bin \
        ${lib.optionalString (length executablePackages > 0) "--prefix PATH : ${lib.escapeShellArg (lib.makeBinPath executablePackages)}"} \
        --prefix INFOPATH : ${emacs}/share/info:$out/share/info:${infoPath} \
        ${
      lib.optionalString nativeComp "--prefix EMACSNATIVELOADPATH : $nativeLisp:$nativeLoadPath"
    } \
        --set EMACSLOADPATH "$siteLisp:"
      fi
    done

    ${lib.optionalString stdenv.hostPlatform.isDarwin ''
      if [[ -d "${emacs}/Applications" ]]; then
        mkdir -p $out/Applications
        cp -R ${emacs}/Applications/Emacs.app $out/Applications/
        chmod -R u+w $out/Applications/Emacs.app || true

        mv $out/Applications/Emacs.app/Contents/MacOS/Emacs $out/Applications/Emacs.app/Contents/MacOS/_Emacs

        mkdir -p $out/Applications/Emacs.app/Contents/Resources
        ln -s $siteLisp $out/Applications/Emacs.app/Contents/Resources/site-lisp
        ln -s $out/share/info $out/Applications/Emacs.app/Contents/Resources/info
        ${lib.optionalString nativeComp ''
          ln -s $nativeLisp $out/Applications/Emacs.app/Contents/Resources/native-lisp
        ''}
        ${lib.optionalString (length executablePackages > 0) ''
          mkdir -p $out/Applications/Emacs.app/Contents/Resources/bin
          for pkg in ${lib.escapeShellArg (lib.concatStringsSep " " executablePackages)}; do
            if [[ -d "$pkg/bin" ]]; then
              for exe in $pkg/bin/*; do
                if [[ -x "$exe"  ]]; then
                  ln -s "$exe" $out/Applications/Emacs.app/Contents/Resources/bin/
                fi
              done
            fi
          done
        ''}

        install -m 755 ${macosAppLauncher} $out/Applications/Emacs.app/Contents/MacOS/Emacs
      fi
    ''}
  ''
