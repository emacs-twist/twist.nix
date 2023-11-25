updateFlakeLock=1
force=0
src='@lockSrcDir@'

function usage() {
  name=$(basename "$0")
  echo "Usage: $name [--no-update-flake-lock] [-f|--force] DIR"
  # TODO: Add descriptions of the options
}

function err() {
  echo >&2 "$*"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      usage
      exit
      ;;
    --no-update-flake-lock)
      updateFlakeLock=0
      shift
      ;;
    -f | --force)
      force=1
      shift
      ;;
    -*)
      echo >&2 "Unsupported option $1"
      exit 1
      ;;
    *)
      if [[ -v outDir ]] && [[ -n "$outDir" ]]; then
        err "Only one output directory is supported"
        exit 1
      fi
      outDir=$(realpath "$1")
      shift
      ;;
  esac
done

function checkSettings() {
  if ! [[ -v outDir ]] || [[ -z "$outDir" ]]; then
    err "You need to specify an output directory as an argument"
    usage
    exit 1
  fi

  if [[ -d "$outDir" ]] && [[ "$force" -ne 1 ]]; then
    err "Directory $outDir already exists."
    err "Set --force as an argument to run anyway"
    exit 1
  fi

  local parent
  parent=$(dirname "$outDir")
  if [[ $( cd "$parent" && git-rev-parse --is-inside-work-tree 2>/dev/null ) = true ]]; then
    err "Directory $outDir is not inside a Git working tree"
  fi
}

function copyFiles() {
  mkdir -p "$outDir"
  cd "$src"
  for f in *.*; do
    # The nix3 commands don't work locally if flake.nix isn't added to the Git
    # repository. Here, an empty file will be added if the file doesn't exist in
    # the Git index. The user can confirm the actual content of generated lock
    # files before committing to the repository.
    ( set -euo pipefail;
      cd "$outDir";
      if [[ -z $(git ls-files --cached "$f") ]]; then
        if [[ -e "$f" ]]; then
          err "File $f exists locally but not in the Git index."
          err "Aborting due to an unexpected state"
          exit 1
        else
          touch "$f"
          git add "$f"
        fi
      fi
    )

    if [[ -f "$outDir/$f" ]] && diff -q "$outDir/$f" "$f" >/dev/null; then
      echo >&2 "'$f': not changed"
      continue
    fi

    install -v -m 644 -t "$outDir" "$f"
  done
}

function runNix() {
  if [[ "$updateFlakeLock" = 1 ]]; then
    ( set -x; cd "$outDir" && nix flake update )
  else
    ( set -x; cd "$outDir" && nix flake lock )
  fi
}

checkSettings
copyFiles
runNix
