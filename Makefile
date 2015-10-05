#
# Copyright 2015 Panagiotis Papadomitsos. All Rights Reserved.
#
# Build targets:
#
# all:          Compiles the project
# shell:        Compiles the project and drops in IEx
# clean:        Cleans build artifacts
# distclean:    Cleans build artifacts, including generated data
# test:         Runs the ExUnit test suite
# dialyzer:     Runs dialyzer
# epmd:         Runs the Erlang port mapper daemon, required for running the app and tests
#

# .DEFAULT_GOAL can be overridden in custom.mk if "all" is not the desired
# default

.DEFAULT_GOAL := all

# Build targets
.PHONY: all test dialyzer xref spec dist

# Run targets
.PHONY: shell

# Misc targets
.PHONY: clean testclean distclean tags rebar

PROJ = $(shell ls -1 src/*.src | sed -e 's/src//' | sed -e 's/\.app\.src//' | tr -d '/')

custom_rules_file = $(wildcard custom.mk)
ifeq ($(custom_rules_file),custom.mk)
	include custom.mk
endif

# =============================================================================
# verify that the programs we need to run are installed on this system
# =============================================================================
ELIXIR = $(shell which elixir)

ifeq ($(ELIXIR),)
	$(error "Elixir is not available on this system")
endif

# =============================================================================
# Build targets
# =============================================================================

all:
	@MIX_ENV=dev $(ELIXIR) -S mix c

test: epmd
	@MIX_ENV=test $(ELIXIR) --name exrpc@127.0.0.1 -S mix t

dialyzer:
	@MIX_ENV=test $(ELIXIR) -S mix dialyzer | fgrep -v -f $(CURDIR)/dialyzer.ignore

# =============================================================================
# Run targets
# =============================================================================

shell: epmd
	@MIX_ENV=dev iex --name exrpc@127.0.0.1 -S mix

# =============================================================================
# Misc targets
# =============================================================================

clean:
	@$(ELIXIR) -S mix clean --deps

distclean:
	@rm -rf _build _plt .rebar Mnesia* mnesia* log/ data/ temp-data/ rebar.lock
	@find . -name erl_crash.dump -type f -delete
	@$(ELIXIR) -S mix clean --deps

epmd:
	@pgrep epmd 2> /dev/null > /dev/null || epmd -daemon || true
