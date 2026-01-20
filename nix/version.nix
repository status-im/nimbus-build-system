{ pkgs ? import <nixpkgs> { } }:

let
  tools = pkgs.callPackage ./tools.nix {};
  source = ../vendor/Nim/lib/system/compilation.nim;

  major = tools.findKeyValue "  NimMajor\\* .*= ([0-9]+)$" source;
  minor = tools.findKeyValue "  NimMinor\\* .*= ([0-9]+)$" source;
  build = tools.findKeyValue "  NimPatch\\* .*= ([0-9]+)$" source;
in
  "${major}.${minor}.${build}"
