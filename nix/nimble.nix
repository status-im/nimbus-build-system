{ pkgs ? import <nixpkgs> { } }:

let
  tools = pkgs.callPackage ./tools.nix {};
  inherit (tools) findKeyValue;

  nbsVersion = findKeyValue "^[[:space:]]+NIMBLE_COMMIT='([a-f0-9]+)'.*$" ../scripts/build_nim.sh;
  nimVersion = findKeyValue "^[[:space:]]+NimbleStableCommit = \"([a-f0-9]+)\".*$" ../vendor/Nim/koch.nim;
  # Use Nimble version defined in NBS or default to Nim one.
  rev = if nbsVersion != null then nbsVersion else nimVersion;
# Fetched by the evaluator because Anonymous Git fetches from
# GitHub get throttled on CI hosts.
in builtins.fetchGit {
  name = "nim-lang-nimble-src-${rev}";
  url = "https://github.com/nim-lang/nimble.git";
  inherit rev;
  submodules = true;
  allRefs = true;
  # WARNING: Requires manual updates when Nim compiler version changes.
  narHash = "sha256-d9Ezmmz6QKPgx/21u/aUBx7GgXaJzDuFu/gxtj6OVE8=";
}
