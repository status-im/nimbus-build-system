# Copyright (c) 2018-2019 Status Research & Development GmbH. Licensed under
# either of:
# - Apache License, version 2.0
# - MIT license
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

SHELL := bash # the shell used internally by "make"

CC ?= gcc
LD := $(CC)

#- extra parameters for the Nim compiler
#- NIMFLAGS should come from the environment or make's command line
NIM_PARAMS := $(NIMFLAGS)

# verbosity level
V := 0
NIM_PARAMS := $(NIM_PARAMS) --verbosity:$(V)
HANDLE_OUTPUT :=
SILENT_TARGET_PREFIX := disabled
ifeq ($(V), 0)
  NIM_PARAMS := $(NIM_PARAMS) --hints:off
  # don't swallow stderr, in case it's important
  HANDLE_OUTPUT := >/dev/null
  SILENT_TARGET_PREFIX :=
endif

# Chronicles log level
ifdef LOG_LEVEL
  NIM_PARAMS := $(NIM_PARAMS) -d:chronicles_log_level="$(LOG_LEVEL)"
endif

# statically link everything but libc
PARTIAL_STATIC_LINKING := 0
ifeq ($(PARTIAL_STATIC_LINKING), 1)
  NIM_PARAMS := $(NIM_PARAMS) --passL:-static-libgcc
endif

# avoid a "libpcre.so.3: cannot open shared object file: No such file or directory" message, where possible
LINK_PCRE ?= 1
ifeq ($(LINK_PCRE), 1)
  ifneq ($(OS), Windows_NT)
    ifneq ($(strip $(shell uname)), Darwin)
      ifeq ($(PARTIAL_STATIC_LINKING), 1)
        NIM_PARAMS := $(NIM_PARAMS) -d:usePcreHeader --passL:-l:libpcre.a
      else
        NIM_PARAMS := $(NIM_PARAMS) -d:usePcreHeader --passL:-lpcre
endif
    endif
  endif
endif

# guess who does parsing before variable expansion
COMMA := ,
EMPTY :=
SPACE := $(EMPTY) $(EMPTY)

# coloured messages
BUILD_MSG := "\\x1B[92mBuilding:\\x1B[39m"

GIT_CLONE := git clone --quiet --recurse-submodules
GIT_PULL := git pull --recurse-submodules
GIT_STATUS := git status
#- the Nimble dir can't be "[...]/vendor", or Nimble will start looking for
#  version numbers in repo dirs (because those would be in its subdirectories)
#- duplicated in "env.sh" for the env var with the same name
NIMBLE_DIR := vendor/.nimble
REPOS_DIR := vendor

ifeq ($(OS), Windows_NT)
  PWD := pwd -W
  EXE_SUFFIX := .exe
  # available since Git 2.9.4
  GIT_TIMESTAMP_ARG := --date=unix
else
  PWD := pwd
  EXE_SUFFIX :=
  # available since Git 2.7.0
  GIT_TIMESTAMP_ARG := --date=format-local:%s
endif

ifeq ($(shell uname), Darwin)
  # md5sum - macOS is a special case
  MD5SUM := md5 -r
  NPROC_CMD := sysctl -n hw.logicalcpu
else
  MD5SUM := md5sum
  NPROC_CMD := nproc
endif

GET_CURRENT_COMMIT_TIMESTAMP := git log --pretty=format:%cd -n 1 $(GIT_TIMESTAMP_ARG)
UPDATE_TIMESTAMP := .update.timestamp

ifeq ($(BUILD_SYSTEM_DIR),)
  $(error You need to define BUILD_SYSTEM_DIR before including this file)
endif

# we want a "recursively expanded" (delayed interpolation) variable here, so we can set CMD in rule recipes
RUN_CMD_IN_ALL_REPOS = git submodule foreach --recursive --quiet 'echo -e "\n\x1B[32m$$name:\x1B[39m"; $(CMD)'; echo -e "\n\x1B[32m$$($(PWD)):\x1B[39m"; $(CMD)

# absolute path, since it will be run at various subdirectory depths
ENV_SCRIPT := "$(CURDIR)/$(BUILD_SYSTEM_DIR)/scripts/env.sh"

# duplicated in "env.sh" to prepend NIM_DIR/bin to PATH
NIM_DIR := $(BUILD_SYSTEM_DIR)/vendor/Nim

NIM_BINARY := $(NIM_DIR)/bin/nim$(EXE_SUFFIX)

# AppVeyor/Travis cache of $(NIM_DIR)/bin
CI_CACHE :=

# bypassing the shipped Nim, usually for testing new Nim devel versions
USE_SYSTEM_NIM := 0

# Skip multiple bootstrap iterations and tool building.
QUICK_AND_DIRTY_COMPILER := 0

# Override local submodule changes during `make update`. On by default. Turned off in `make update-dev`.
OVERRIDE := 1
