SHELL := bash # the shell used internally by "make"

# used inside the included makefiles
BUILD_SYSTEM_DIR := vendor/nimbus-build-system

# we don't want an error here, so we can handle things later, in the ".DEFAULT" target
-include $(BUILD_SYSTEM_DIR)/makefiles/variables.mk

.PHONY: \
	all \
	deps \
	update \
	foo \
	bar \
	clean

ifeq ($(NIM_PARAMS),)
# "variables.mk" was not included, so we update the submodules.
GIT_SUBMODULE_UPDATE := git submodule update --init --recursive
.DEFAULT:
	+@ echo -e "Git submodules not found. Running '$(GIT_SUBMODULE_UPDATE)'.\n"; \
		$(GIT_SUBMODULE_UPDATE) && \
		echo
# Now that the included *.mk files appeared, and are newer than this file, Make will restart itself:
# https://www.gnu.org/software/make/manual/make.html#Remaking-Makefiles
#
# After restarting, it will execute its original goal, so we don't have to start a child Make here
# with "$(MAKE) $(MAKECMDGOALS)". Isn't hidden control flow great?

else # "variables.mk" was included. Business as usual until the end of this file.

# default target, because it's the first one that doesn't start with '.'
all: | foo bar

# must be included after the default target
-include $(BUILD_SYSTEM_DIR)/makefiles/targets.mk

# add a default Nim compiler argument
NIM_PARAMS += -d:release

deps: | deps-common
	# Have custom deps? Add them above.

update: | update-common
	# Do you need to do something extra for this target?

# building Nim programs
foo bar: | build deps
	echo -e $(BUILD_MSG) "build/$@" && \
		$(ENV_SCRIPT) nim c -o:build/$@ $(NIM_PARAMS) "$@.nim"

clean: | clean-common
	rm -rf build/{foo,bar}

endif # "variables.mk" was not included

