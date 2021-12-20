{ git
, runCommandLocal
}:
file:
runCommandLocal "gitmodules-output" { } ''
  ${git}/bin/git --no-pager config --list -f ${file} > $out
''
