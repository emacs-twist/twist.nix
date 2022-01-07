SYSTEM := $(shell nix eval --raw --impure --expr builtins.currentSystem)
NIX := nix
NIX_OPTIONS := --override-input twist path:$(PWD)/..
NIX_EVAL = $(NIX) eval .#packages.$(SYSTEM).emacs.$(NIX_ATTR)

build:
	$(NIX) build .#emacs $(NIX_OPTIONS) $(ARGS)
.PHONY: build

lock:
	$(NIX) run .#lock -- $(NIX_OPTIONS)
.PHONY: lock

sync:
	$(NIX) run .#sync -- $(NIX_OPTIONS)
.PHONY: sync

update-elpa:
	$(NIX) run .#update-elpa -- $(NIX_OPTIONS)
.PHONY: update-elpa

clean:
	rm -f repos/flake.nix repos/flake.lock repos/archive.lock
.PHONY: clean

eval:
	$(NIX_EVAL) $(NIX_OPTIONS) $(ARGS)
.PHONY: eval

eval-checks:
	$(MAKE) eval NIX_ATTR=initFiles ARGS="--json"
	$(MAKE) eval NIX_ATTR=packageInputs ARGS="--json"
	$(MAKE) eval NIX_ATTR=elispPackages.magit ARGS="--json"
.PHONY: eval-checks
