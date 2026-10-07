{ pkgs ? import <nixpkgs> { } }:

let
  tools = pkgs.callPackage ./tools.nix {};
  inherit (tools) findKeyValue;

  nbsVersion = findKeyValue "^[[:space:]]+NIMBLE_COMMIT='([a-f0-9]+)'.*$" ../scripts/build_nim.sh;
  nimVersion = findKeyValue "^[[:space:]]+NimbleStableCommit = \"([a-f0-9]+)\".*$" ../vendor/Nim/koch.nim;
  # Use Nimble version defined in NBS or default to Nim one.
  rev = if nbsVersion != null then nbsVersion else nimVersion;
# fetchTree with type=github necessary for access-tokens auth to avoid GH throttling.
in builtins.fetchTree {
  type = "github";
  owner = "nim-lang";
  repo = "nimble";
  inherit rev;
  #submodules = true;
}
