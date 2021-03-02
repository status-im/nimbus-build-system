# Common parts of the build system used by Nimbus and related projects

We focus on building Nim software on multiple platforms, without having to deal
with language-specific package managers.

We care about dependencies specified with commit-level accuracy (including the
Nim compiler), reproducible builds, bisectable Git histories and self-contained
projects that don't create dirs/files outside their main directory.

We try to minimise complexity, but we will trade implementation complexity
increases for a simpler user experience.

## Prerequisites

GNU Make, Bash and the usual POSIX utilities.

## Usage

Add this repository to your project as a Git submodule. You can use our handy shell script:

```bash
curl -OLs https://raw.githubusercontent.com/status-im/nimbus-build-system/master/scripts/add_submodule.sh
less add_submodule.sh # you do read random Internet scripts before running them, right?
chmod 755 add_submodule.sh
./add_submodule.sh status-im/nimbus-build-system
```

Or you can do it by hand:

```bash
git submodule add https://github.com/status-im/nimbus-build-system.git vendor/nimbus-build-system
# specify a branch
git config -f .gitmodules submodule.vendor/nimbus-build-system.branch master
# hide submodule working tree changes in `git diff`
git config -f .gitmodules submodule.vendor/nimbus-build-system.ignore dirty
```

Write your own top-level Makefile, taking our
"[Makefile.superproject.example](./Makefile.superproject.example)" as an...
example.

See also the Makefiles we wrote for
[Nimbus-eth1](https://github.com/status-im/nimbus-eth1),
[Nimbus-eth2](https://github.com/status-im/nimbus-eth2),
[nim-waku](https://github.com/status-im/nim-waku),
[Stratus](https://github.com/status-im/nim-stratus),
[nim-status-client](https://github.com/status-im/nim-status-client).

Instruct your users to run `make update` after cloning your project, after a
`git pull` or after switching branches.

## Make variables

### V

Control the verbosity level. Defaults to 0 for a nice, quiet build.

```bash
make V=1 # verbose
make V=2 test # even more verbose
```

### LOG_LEVEL

Set the [Chronicles log
level](https://github.com/status-im/nim-chronicles#chronicles_log_level) to one
of: TRACE, DEBUG, INFO, NOTICE, WARN, ERROR, FATAL, NONE.

This Make variable is unset by default, which means that Chronicles' default
kicks in (DEBUG in debug builds and INFO in release mode) or some
application-specific default takes precedence.

Note that this sets the compile-time log level. If runtime log level selection
is implemented (which cannot have larger values than what was set at compile
time), additional steps need to be taken to pass the proper command line
argument to your binary.

```bash
make LOG_LEVEL=DEBUG foo # this is the default
make LOG_LEVEL=TRACE bar # log everything
```

### NIMFLAGS

Pass arbitrary parameters to the Nim compiler. Uses an internal `NIM_PARAMS`
variable that should not be overridden by the user.

```bash
make NIMFLAGS="-d:release"
```

Defaults to Nim parameters mirroring the selected verbosity and log level:

```bash
make V=0 # NIMFLAGS="--verbosity:0 --hints:off"
make V=1 LOG_LEVEL=TRACE # NIMFLAGS="--verbosity:1 -d:chronicles_log_level=TRACE"
make V=2 # NIMFLAGS="--verbosity:2"
```

Projects using this build system may choose to add other default flags like
`-d:release` in their Makefiles (usually those that can't be placed in a
top-level "config.nims" or "nim.cfg"). This will be done by appending to the
internal variable:

```make
NIM_PARAMS += -d:release
```

### CI_CACHE

Specify a directory where Nim compiler binaries should be cached, in a CI service like AppVeyor:

```yml
build_script:
  # the 32-bit build is done on a 64-bit image, so we need to override the architecture
  - mingw32-make -j2 ARCH_OVERRIDE=%PLATFORM% CI_CACHE=NimBinaries update
```

### USE_SYSTEM_NIM

Use the system Nim instead of our shipped version (usually for testing Nim
devel versions). Defaults to 0. Setting it to 1 means you're on your own, when
it comes to support.

`make USE_SYSTEM_NIM=1 test`

### PARTIAL_STATIC_LINKING

Statically link some libraries (currently libgcc\_s and libpcre). Defaults to 0.

This is useful when you can't statically link Glibc because you use NSS functions.

`make PARTIAL_STATIC_LINKING=1 beacon_node`

### LINK_PCRE

Link PCRE, defaults to 1.

`make LINK_PCRE=0`

### QUICK_AND_DIRTY_COMPILER

Skip some Nim compiler bootstrap iterations and tool building. Useful in
CI. Defaults to 0.

`make QUICK_AND_DIRTY_COMPILER=1 build-nim`

### NIM_COMMIT

Build and use a different Nim compiler version than the default one.

Possible values: (partial) commit hashes, tags, branches and anything else recognised by `git checkout ...`.

`make -j8 NIM_COMMIT="v1.2.6" build-nim`

You also need to specify it when using this non-default Nim compiler version:

`make -j8 NIM_COMMIT="v1.2.6" nimbus_beacon_node`

## Make targets

### build

Internal target that creates the directory with the same name.

### sanity-checks

Internal target used to check that a C compiler is installed.

### warn-update

Internal target that checks if `make update` was executed for the current Git commit.

### warn-jobs

Internal target that checks if Make's parallelism was enabled by specifying the number of jobs.

### deps-common

Internal target that needs to be a dependency for a custom "deps" target which,
in turn, will be a dependency for various compilation targets.

The superproject's Makefile would look like this:

```make
deps: | deps-common
	# Have custom deps? Add them above.

# building Nim programs
foo bar: | build deps
	echo -e $(BUILD_MSG) "build/$@" && \
		$(ENV_SCRIPT) nim c -o:build/$@ $(NIM_PARAMS) "$@.nim"
```

The user should never have to run `make deps` directly.

### build-nim

Internal target that builds the Nim compiler if it's not built yet or if the
corresponding submodule points to a newer commit than the existing binary.

It's being executed as part of "update-common" and "$(NIM\_BINARY)" targets. It
may be executed directly, rarely, when testing new Nim versions.

### update-common

Internal target that needs to become the dependency of a custom "update" target.

```make
update: | update-common
	# Do you need to do something extra for this target?
```

Initialises and updates all Git submodules, with various ugly hacks to account
for corner cases like submodules changing URLs or being replaced with regularly
committed files.

Tell your users to run `make update` after cloning the superproject, after a
`git pull` and after changing branches or checking out older commits.

### update-remote

Dangerous target that updates all submodules to their latest remote commit.

As you may imagine, it's usually necessary to roll back one or two of these
automatic bumps. You do it like this:

```bash
git submodule update --recursive vendor/news
```

### clean-cross

Confusingly named target that deletes libnatpmp and miniupnp objects and static
libraries. Useful when you're cross-compiling and don't want to `make clean`
and have to rebuild the compiler.

### clean-common

Internal target that needs to be a dependency for a custom "clean" target that
deletes any additional build artefacts:

```make
clean: | clean-common
	rm -rf build/{foo,bar}
```

Don't run `make clean` if you don't really need to, since it also deletes the Nim compiler.

Unlike C/C++ projects, we always recompile our Nim targets (because it's too
hard to tell Make what are all the files involved in the build process), so
there's no need to delete them to force a recompilation.

### mrproper

Dangerous target that, in addition to depending on "clean", deletes the
"vendor" directory and any not-yet-pushed modification you may have in there.
Don't use it.

### github-ssh

Changes submodule URLs, without affecting .gitmodules, so you connect to GitHub
using your SSH key - very useful when you have write access to some submodule
repos and you want to work on them without cloning them separately.

### status

Run `git status` in all your submodules and in your superproject.

### ctags

Run [Universal Ctags](https://github.com/universal-ctags/ctags) with a bunch of Nim-specific options.

### show-deps

List all Git submodules, including the nested ones.

### fetch-dlls

Windows-specific target. Downloads and unpacks in the "build" dir some DLLs we may not want to build ourselves (PCRE, RocksDB, libcurl, pdcurses, SQLite3, OpenSSL, zlib, etc.).

### nat-libs

Build "libminiupnpc.a" and "libnatpmp.a" from [nim-nat-traversal](https://github.com/status-im/nim-nat-traversal)'s submodules - not included in this repo.

## Scripts

### add_submodule.sh

Add a new Git submodule to your superproject, setting the branch to "master"
and hiding submodule working tree changes in `git diff`.

Usage: `./add_submodule.sh some/repo [destdir]` # "destdir" defaults to "vendor/repo"

Examples:

`./add_submodule.sh status-im/nimbus-build-system`

`./vendor/nimbus-build-system/scripts/add_submodule.sh status-im/nim-nat-traversal`

### build_nim.sh

Build the Nim compiler and some associated tools, parallelising the
bootstrap-from-C phase, with binary caching and conditional recompilation
support (based on the timestamp of the latest commit in the Nim repo).

Usage: `./build_nim.sh nim_dir csources_dir nimble_dir ci_cache_dir`

This script is not usually used directly, but through the `update` target
(which depends on `update-common` which runs `build-nim`).

Our `build-nim` target uses it like this:

```make
build-nim: | sanity-checks
	+ NIM_BUILD_MSG="$(BUILD_MSG) Nim compiler" \
		V=$(V) \
		CC=$(CC) \
		MAKE=$(MAKE) \
		ARCH_OVERRIDE=$(ARCH_OVERRIDE) \
		"$(CURDIR)/$(BUILD_SYSTEM_DIR)/scripts/build_nim.sh" "$(NIM_DIR)" ../Nim-csources ../nimble "$(CI_CACHE)"
```

Other Nim projects that don't use this build system use the script directly in their CI. From a ".travis.yml":

```yaml
install:
  - curl -O -L -s -S https://raw.githubusercontent.com/status-im/nimbus-build-system/master/scripts/build_nim.sh
  - env MAKE="make -j${NPROC}" bash build_nim.sh Nim csources dist/nimble NimBinaries
  - export PATH="$PWD/Nim/bin:$PATH"
```

Or an ".appveyor.yml":

```yaml
install:
  # [...]
  - curl -O -L -s -S https://raw.githubusercontent.com/status-im/nimbus-build-system/master/scripts/build_nim.sh
  - env MAKE="mingw32-make -j2" ARCH_OVERRIDE=%PLATFORM% bash build_nim.sh Nim csources dist/nimble NimBinaries
  - SET PATH=%CD%\Nim\bin;%PATH%
```

Notice how the number of Make jobs is set through the "MAKE" env var.

### build_p2pd.sh

Builds the "p2pd" Go daemon. No longer used by a Make target, but needed by
other projects that run it directly in their CI config files, like this:

```yaml
install:
  # [...]
  # install and build go-libp2p-daemon
  - curl -O -L -s -S https://raw.githubusercontent.com/status-im/nimbus-build-system/master/scripts/build_p2pd.sh
  - bash build_p2pd.sh p2pdCache v0.2.1
```

### build_rocksdb.sh

Builds RocksDB. No longer used.

Usage: `./build_rocksdb.sh ci_cache_dir`

### create_nimble_link.sh

Cheeky little script used to fake a Nimble package repository in the
`$(NIMBLE_DIR)` target (a dependency of `deps-common` which is a dependency of
`deps`):

```make
$(NIMBLE_DIR):
	mkdir -p $(NIMBLE_DIR)/pkgs
	NIMBLE_DIR="$(CURDIR)/$(NIMBLE_DIR)" PWD_CMD="$(PWD)" \
		git submodule foreach --quiet '$(CURDIR)/$(BUILD_SYSTEM_DIR)/scripts/create_nimble_link.sh "$$sm_path"'
```

That's how the Nim compiler knows how to find all these Nim packages we have in
our submodules: we set the "NIMBLE\_DIR" env var to the path of this fake
Nimble package repo.

### env.sh

Script responsible for setting up environment variables and shell aliases
necessary for using this build system. It's being sourced by a script with the
same name in the superproject's top directory:

```bash
#!/usr/bin/env bash

# We use ${BASH_SOURCE[0]} instead of $0 to allow sourcing this file
# and we fall back to a Zsh-specific special var to also support Zsh.
REL_PATH="$(dirname ${BASH_SOURCE[0]:-${(%):-%x}})"
ABS_PATH="$(cd ${REL_PATH}; pwd)"
source ${ABS_PATH}/vendor/nimbus-build-system/scripts/env.sh
```

Supported usage: `./env.sh nim --version`

Unsupported usage: `source env.sh; nim --version`

An interesting alias is `nimble` which calls the "nimble.sh" script which pretends to be Nimble:

```bash
cd vendor/nim-metrics
../../env.sh nimble test
```

In order to get autocompletion and code navigation functionality working
properly in your text editor, you need the environment variables set by this script:

```bash
./env.sh vim
```

### nimble.sh

Simple script that symlinks the first \*.nimble file it finds to \*.nims and
runs it using `nim`. Easier to access using the `nimble` alias in "env.sh".

Of very limited use, it can execute \*.nimble targets, as long as there are no
"before install:" blocks that the real Nimble strips before doing the same thing we do.

If you need the real Nimble, it's in "vendor/nimbus-build-system/vendor/Nim/bin/nimble".

## License

Licensed and distributed under either of

* MIT license: [LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT

or

* Apache License, Version 2.0, ([LICENSE-APACHEv2](LICENSE-APACHEv2) or http://www.apache.org/licenses/LICENSE-2.0)

at your option. These files may not be copied, modified, or distributed except according to those terms.

