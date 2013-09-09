#TESTFLAGS=-only-test "OUnit:1"

default: test

# OASIS_START
# DO NOT EDIT (digest: bc1e05bfc8b39b664f29dae8dbd3ebbb)

SETUP = ocaml setup.ml

build: setup.data
	$(SETUP) -build $(BUILDFLAGS)

doc: setup.data build
	$(SETUP) -doc $(DOCFLAGS)

test: setup.data build
	$(SETUP) -test $(TESTFLAGS)

all: 
	$(SETUP) -all $(ALLFLAGS)

install: setup.data
	$(SETUP) -install $(INSTALLFLAGS)

uninstall: setup.data
	$(SETUP) -uninstall $(UNINSTALLFLAGS)

reinstall: setup.data
	$(SETUP) -reinstall $(REINSTALLFLAGS)

clean: 
	$(SETUP) -clean $(CLEANFLAGS)

distclean: 
	$(SETUP) -distclean $(DISTCLEANFLAGS)

setup.data:
	$(SETUP) -configure $(CONFIGUREFLAGS)

.PHONY: build doc test all install uninstall reinstall clean distclean configure

# OASIS_STOP

doc-test: doc
	 ocamldoc -g ../ocaml-tmp/odoc-extract-code/odoc_extract_code.cmo \
	   -load _build/src/oUnit.odoc -intro doc/manual.txt > _build/src/tmp.ml;
	 ocamlc -c -I _build/src/ _build/src/tmp.ml

PRECOMMIT_ARGS= \
	    --exclude log-html \
	    --exclude myocamlbuild.ml \
	    --exclude setup.ml \
	    --exclude README.txt \
	    --exclude INSTALL.txt \
	    --exclude Makefile \
	    --exclude configure \
	    --exclude _tags

precommit:
	 @if command -v OCamlPrecommit > /dev/null; then \
	   OCamlPrecommit $(PRECOMMIT_ARGS); \
	 else \
	   echo "Skipping precommit checks.";\
	 fi

test: precommit

.PHONY: precommit

doc-dev-dist: doc fix-perms
	./doc-dist.sh --version dev

.PHONY: doc-dev-dist

deploy: doc fix-perms
	./doc-dist.sh --version $(shell oasis query version)

.PHONY: deploy

fix-perms:
	chmod +x doc-dist.sh

.PHONY: fix-perms
