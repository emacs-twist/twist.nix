s:
with builtins; let
  githubMatch = match "https://github.com/(.+)/(.+)" s;
in
  if githubMatch != null
  then {
    type = "github";
    owner = elemAt githubMatch 0;
    repo = elemAt githubMatch 1;
  }
  else throw "Git url does not match any pattern: ${s}"
