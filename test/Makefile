SYSTEM = $(shell nix eval --raw --impure --expr builtins.currentSystem)
NIX := nix
NIX_OPTIONS := --override-input twist path:$(PWD)/..

build:
	$(NIX) build .#emacs $(NIX_OPTIONS) --update-input twist $(ARGS)
.PHONY: build

lock:
	$(NIX) eval .#packages.$(SYSTEM).emacs.flakeNix $(NIX_OPTIONS) --impure >/dev/null
.PHONY: lock

sync:
	$(NIX) eval .#packages.$(SYSTEM).emacs.flakeLock $(NIX_OPTIONS) --json --impure >/dev/null
.PHONY: sync
