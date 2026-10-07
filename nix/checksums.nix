{ pkgs ? import <nixpkgs> { } }:

let
  tools = pkgs.callPackage ./tools.nix {};
  sourceFile = ../vendor/Nim/koch.nim;

  commit = tools.findKeyValue "^ +ChecksumsStableCommit = \"([a-f0-9]+)\".*$" sourceFile;
# fetchTree with type=github necessary for access-tokens auth to avoid GH throttling.
in builtins.fetchTree {
  type = "github";
  owner = "nim-lang";
  repo = "checksums";
  rev = if commit != null then commit else throw "No checksums version in ${toString sourceFile}";
}
