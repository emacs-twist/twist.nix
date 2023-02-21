{
  writeShellApplication,
  emacs,
}:
writeShellApplication {
  name = "emacs-interactive";

  runtimeInputs = [
    emacs
  ];

  text = ''
    tmpdir=$(mktemp -d twist-test-XXX)
    cleanup() {
      echo "Clean up"
      rm -rf "$tmpdir"
    }
    trap cleanup EXIT ERR
    [[ -f init.el ]] && [[ -f early-init.el ]]
    cp init.el early-init.el "$tmpdir"
    echo "The init directory is $tmpdir"
    emacs --init-directory="$tmpdir" "$@"
  '';
}
