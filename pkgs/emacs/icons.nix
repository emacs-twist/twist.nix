{ runCommandLocal, lndir, gtk3, emacs }:

runCommandLocal "emacs-icons" {
  buildInputs = [lndir];
  nativeBuildInputs = [ gtk3 ];
  propagatedBuildInputs = [emacs];

  inherit emacs;

  postInstall = ''
    gtk-update-icon-cache "''${out:?}/share/icons/hicolor
  '';
} ''
  mkdir -p ''${out:?}/share/icons
  lndir -silent $emacs/share/icons ''${out:?}/share/icons
''
