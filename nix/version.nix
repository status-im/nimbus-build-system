{ pkgs ? import <nixpkgs> { } }:

let
  findKeyValue = pkgs.callPackage ./findKeyValue.nix {};
  source = ../vendor/Nim/lib/system/compilation.nim;

  major = findKeyValue "  NimMajor\\* .*= ([0-9]+)$" source;
  minor = findKeyValue "  NimMinor\\* .*= ([0-9]+)$" source;
  build = findKeyValue "  NimPatch\\* .*= ([0-9]+)$" source;
in
  "${major}.${minor}.${build}"
