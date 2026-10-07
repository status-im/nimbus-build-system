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

When `vendor/Nim` is updated, or `NIMBLE_COMMIT` changed in `scripts/build_nim.sh`, it is necessary to update the corresponding pinned inputs in `flake.nix` and run `nix flake lock` for following inputs:

- `checksums`
- `csources`
- `nimble`

Running flake check verifies input revisions against commit hashes parsed from Nim sources and `scripts/build_nim.sh`:
```sh
nix flake check -L '.?submodules=1'
```
