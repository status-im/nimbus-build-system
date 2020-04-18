# Copyright (c) 2018-2019 Status Research & Development GmbH. Licensed under
# either of:
# - Apache License, version 2.0
# - MIT license
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

SHELL := bash # the shell used internally by "make"

CC := gcc
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
  HANDLE_OUTPUT := &>/dev/null
  SILENT_TARGET_PREFIX :=
endif

# Chronicles log level
LOG_LEVEL :=
ifdef LOG_LEVEL
  NIM_PARAMS := $(NIM_PARAMS) -d:chronicles_log_level=$(LOG_LEVEL)
endif

# avoid a "libpcre.so.3: cannot open shared object file: No such file or directory" message, where possible
ifneq ($(OS), Windows_NT)
  NIM_PARAMS := $(NIM_PARAMS) -d:usePcreHeader --passL:\"-lpcre\"
endif

# guess who does parsing before variable expansion
COMMA := ,
EMPTY :=
SPACE := $(EMPTY) $(EMPTY)

# coloured messages
BUILD_MSG := "\\e[92mBuilding:\\e[39m"

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
else
  PWD := pwd
endif
ifeq ($(BUILD_SYSTEM_DIR),)
  $(error You need to define BUILD_SYSTEM_DIR before including this file)
endif
# we want a "recursively expanded" (delayed interpolation) variable here, so we can set CMD in rule recipes
RUN_CMD_IN_ALL_REPOS = git submodule foreach --recursive --quiet 'echo -e "\n\e[32m$$name:\e[39m"; $(CMD)'; echo -e "\n\e[32m$$($(PWD)):\e[39m"; $(CMD)
# absolute path, since it will be run at various subdirectory depths
ENV_SCRIPT := "$(CURDIR)/$(BUILD_SYSTEM_DIR)/scripts/env.sh"
# duplicated in "env.sh" to prepend NIM_DIR/bin to PATH
NIM_DIR := $(BUILD_SYSTEM_DIR)/vendor/Nim

ifeq ($(OS), Windows_NT)
  EXE_SUFFIX := .exe
else
  EXE_SUFFIX :=
endif
NIM_BINARY := $(NIM_DIR)/bin/nim$(EXE_SUFFIX)
# md5sum - macOS is a special case
ifeq ($(shell uname), Darwin)
  MD5SUM := md5 -r
else
  MD5SUM := md5sum
endif
# AppVeyor/Travis cache of $(NIM_DIR)/bin
CI_CACHE :=

# bypassing the shipped Nim, usually for testing new Nim devel versions
USE_SYSTEM_NIM := 0

