{ pkgs ? import <nixpkgs> { } }:

let
  tools = pkgs.callPackage ./tools.nix {};
  sourceFile = ../vendor/Nim/config/build_config.txt;

  repo = tools.findKeyValue "^nim_csourcesDir=([a-z0-9_]+)$" sourceFile;
  commit = tools.findKeyValue "^nim_csourcesHash=([a-f0-9]+)$" sourceFile;
# fetchTree with type=github necessary for access-tokens auth to avoid GH throttling.
in builtins.fetchTree {
  type = "github";
  owner = "nim-lang";
  inherit repo;
  rev = if commit != null then commit else throw "No csources version in ${toString sourceFile}";
} // {
  # Necessary due to potential for repo name change.
  inherit repo;
}
