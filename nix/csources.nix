{ pkgs ? import <nixpkgs> { } }:

let
  tools = pkgs.callPackage ./tools.nix {};
  sourceFile = ../vendor/Nim/config/build_config.txt;

  repo = tools.findKeyValue "^nim_csourcesDir=([a-z0-9_]+)$" sourceFile;
  commit = tools.findKeyValue "^nim_csourcesHash=([a-f0-9]+)$" sourceFile;
in pkgs.fetchFromGitHub rec {
  name = "${owner}-${repo}-src-${rev}";
  owner = "nim-lang";
  inherit repo;
  rev = if commit != null then commit else throw "No csources version in ${toString sourceFile}";
  # WARNING: Requires manual updates when Nim compiler version changes.
  # Newer versions of Nim depend on different csources repository.
  hash = {
    csources_v2 = "sha256-UCLtoxOcGYjBdvHx7A47x6FjLMi6VZqpSs65MN7fpBs=";
    csources_v3 = "sha256-pTcm2y+HDOuTol8DyoJMOMHsUA6QrgwGdfcOu1NX4PU=";
  }.${repo};
}
