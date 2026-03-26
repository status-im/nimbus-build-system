# Usage

## Shell

A development shell can be started using:
```sh
nix develop '.?submodules=1#'
```

## Building

To build Nim compiler and Nimble you can use:
```sh
nix build '.?submodules=1#'
```
The `?submodules=1#` part should eventually not be necessary.
For more details see:
https://github.com/NixOS/nix/issues/4423

It can be also done without even cloning the repo:
```sh
nix build 'git+https://github.com/status-im/nimbus-build-system?submodules=1#'
```
The trailing `#` is required due to [URI parsing bug in Nix](https://github.com/NixOS/nix/issues/6633).

## Running

```sh
nix run 'git+https://github.com/status-im/nimbus-build-system?submodules=1#'
```

## Updating

When `vendor/Nim` is updated, or `NIMBLE_COMMIT` changed in `scripts/build_nim.sh` the hashes in following files might need updating:

- `checksums.nix`
- `csources.nix`
- `nimble.nix`

The tricky part is that in order to force a hash check you need to use use `pkgs.lib.fakeHash` or just make an intentional typo and rebuild.
