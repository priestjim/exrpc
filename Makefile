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
.PHONY: shell shell-slave

# Misc targets
.PHONY: clean testclean distclean tags rebar

custom_rules_file = $(wildcard custom.mk)
ifeq ($(custom_rules_file),custom.mk)
	include custom.mk
endif

# =============================================================================
# verify that the programs we need to run are installed on this system
# =============================================================================
ERL = $(shell which erl 2> /dev/null)
ELIXIR = $(shell which elixir 2> /dev/null)
MIX = $(shell which mix 2> /dev/null)
IEX = $(shell which iex 2> /dev/null)
DIALYXIR = $(shell mix help 2> /dev/null | grep dialyzer.plt)
DIALYXIR_URL = https://github.com/jeremyjh/dialyxir.git

ifeq ($(ERL),)
	$(error "Erlang is not available on this system")
endif

ifeq ($(ELIXIR),)
	$(error "Elixir is not available on this system")
endif

ifeq ($(IEX),)
	$(error "IEx is not available on this system")
endif

ifeq ($(IEX),)
	$(error "IEx is not available on this system")
endif
# Dialyzer
ERLANG_VERSION := $(shell $(ERL) -eval 'io:format("~s~n", [erlang:system_info(otp_release)]), halt().' -noshell)
ELIXIR_VERSION := $(shell $(ELIXIR) -v | cut -d\  -f2 | sed -e 's/-dev//')
PLT_FILE := _plt/otp-$(ERLANG_VERSION)_elixir-$(ELIXIR_VERSION).plt

# =============================================================================
# Build targets
# =============================================================================

all:
	@MIX_ENV=dev $(ELIXIR) -S mix c

test: epmd all
	@MIX_ENV=test $(ELIXIR) --name exrpc@127.0.0.1 --cookie exrpc --erl "-args_file config/vm.args" -S mix t

dialyzer: _plt/otp-$(ERLANG_VERSION)_elixir-$(ELIXIR_VERSION).plt all
	@MIX_ENV=dev $(ELIXIR) -S mix d | fgrep -v -f $(CURDIR)/dialyzer.ignore

$(PLT_FILE):
ifeq ($(DIALYXIR),)
	@echo "Dialyxir not found. Installing from source"
	@git clone $(DIALYXIR_URL) dialyxir && \
	  cd dialyxir && \
	  mix archive.build && \
	  mix archive.install --force && \
	  rm -fr dialyxir
endif
	@mkdir -p _plt
	@MIX_ENV=dev $(ELIXIR) -S mix dialyzer.plt

# =============================================================================
# Run targets
# =============================================================================

shell: epmd
	@MIX_ENV=dev $(IEX) --name exrpc@127.0.0.1 --cookie exrpc --erl "-args_file config/vm.args" -S mix

shell-slave: epmd
	@MIX_ENV=dev $(IEX) --name exrpc_slave@127.0.0.1 --cookie exrpc --erl "-args_file config/vm.args" -S mix

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
