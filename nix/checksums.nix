{ pkgs ? import <nixpkgs> { } }:

let
  tools = pkgs.callPackage ./tools.nix {};
  sourceFile = ../vendor/Nim/koch.nim;

  commit = tools.findKeyValue "^ +ChecksumsStableCommit = \"([a-f0-9]+)\".*$" sourceFile;
in pkgs.fetchFromGitHub rec {
  name = "${owner}-${repo}-src-${rev}";
  owner = "nim-lang";
  repo = "checksums";
  rev = if commit != null then commit else throw "No checksums version in ${toString sourceFile}";
  # WARNING: Requires manual updates when Nim compiler version changes.
  hash = "sha256-xC11sD13OTMMUY4F5CrF1XxKSigLtIPt2XQCcQOFNdM=";
}
