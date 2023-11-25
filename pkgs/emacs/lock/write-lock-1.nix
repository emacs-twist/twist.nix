{writeShellScript}: {
  outDir,
  src,
  postCommand,
}:
writeShellScript "lock" ''
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
''
