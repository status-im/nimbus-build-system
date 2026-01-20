{ pkgs ? import <nixpkgs> { } }:

let
  tools = pkgs.callPackage ./tools.nix {};
  inherit (tools) findKeyValue;

  nbsVersion = findKeyValue "^ +NIMBLE_COMMIT='([a-f0-9]+)'.*$" ../scripts/build_nim.sh;
  nimVersion = findKeyValue "^ +NimbleStableCommit = \"([a-f0-9]+)\".*$" ../vendor/Nim/koch.nim;
in pkgs.fetchFromGitHub rec {
  name = "${owner}-${repo}-src{rev}";
  owner = "nim-lang";
  repo = "nimble";
  fetchSubmodules = true;
  # Use Nimbsle verson defined in NBS or default to Nim one.
  rev = if nbsVersion != null then nbsVersion else nimVersion;
  # WARNING: Requires manual updates when Nim compiler version changes.
  hash = "sha256-DV/cheAoG0UviYEYqfaonhrAl4MgjDwFqbbKx7jUnKE=";
}
