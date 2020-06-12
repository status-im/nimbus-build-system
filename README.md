# Common parts of the build system used by Nimbus and related projects

We focus on building Nim software on multiple platforms without having to deal
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
# hide submodule work tree changes in `git diff`
git config -f .gitmodules submodule.vendor/nimbus-build-system.ignore dirty
```

Write your own top-level Makefile, taking our
"[Makefile.superproject.example](./Makefile.superproject.example)" as an...
example.

See also the Makefiles we wrote for
[Nimbus](https://github.com/status-im/nimbus/),
[nim-beacon-chain](https://github.com/status-im/nim-beacon-chain),
[Stratus](https://github.com/status-im/nim-stratus),
[nim-status-client](https://github.com/status-im/nim-status-client).

Instruct your users to run `make update` after cloning your project, after a
`git pull` or after switching branches.

## Make flags

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

## Make targets

### build

Internal target that creates the directory with the same name.

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

Windows-specific target. Downloads and unpacks in the "build" dir some DLLs we may not want to build ourselves (PCRE, RocksDB, libcurl, pdcurses, Snappy, SQLite3, SSLeay, etc.).

## License

Licensed and distributed under either of

* MIT license: [LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT

or

* Apache License, Version 2.0, ([LICENSE-APACHEv2](LICENSE-APACHEv2) or http://www.apache.org/licenses/LICENSE-2.0)

at your option. These files may not be copied, modified, or distributed except according to those terms.

