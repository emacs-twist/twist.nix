s:
with builtins; let
  matchResult = match ".*[^[:space:]]([[:space:]]+)" s;
in
  if matchResult == null
  then s
  else substring 0 (stringLength s - (stringLength (head matchResult))) s
