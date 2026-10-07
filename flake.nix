{
  description = "nimbus-build-system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?rev=2a777ace4b722f2714cc06d596f2476ee628c04a";
    # WARNING: These commit hashes need updating to match vendor changes.
    nimble = {
      url = "git+https://github.com/nim-lang/nimble?rev=42ef70c2102a942c46f13eb76872326edd525cec&submodules=1&shallow=1";
      flake = false;
    };
    checksums = {
      url = "github:nim-lang/checksums?rev=5c132cd332cce5d64a0da9ac3e4c9664313dccb4";
      flake = false;
    };
    csources = {
      url = "github:nim-lang/csources_v3?rev=eeab3ac46e93f10efda8e58c4db02b9438319d71";
      flake = false;
    };
    # WARNING: Does not work with 'github:' schema URLs.
    # https://github.com/NixOS/nix/issues/14982
    self.submodules = true;
  };

  outputs = { self, nixpkgs, checksums, csources, nimble }:
    let
      stableSystems = [
        "x86_64-linux" "aarch64-linux" "armv7a-linux"
        "x86_64-darwin" "aarch64-darwin"
        "x86_64-windows"
      ];
      forEach = nixpkgs.lib.genAttrs;
      forAllSystems = forEach stableSystems;
      pkgsFor = forEach stableSystems (
        system: import nixpkgs { inherit system; }
      );
    in {
      packages = forAllSystems (system: let
        buildTarget = pkgsFor.${system}.callPackage ./nix/default.nix {
          src = self;
          inherit checksums csources nimble stableSystems;
        };
        build = targets: buildTarget.override { inherit targets; };
      in rec {
        nim = build ["build-nim"];

        default = nim;
      });

      checks = forAllSystems (system: let
        pkgs = pkgsFor.${system};
        findKeyValue = pkgs.callPackage ./nix/findKeyValue.nix {};
        expected = {
          checksums = findKeyValue "^ +ChecksumsStableCommit = \"([a-f0-9]+)\".*$" ./vendor/Nim/koch.nim;
          csources = findKeyValue "^nim_csourcesHash=([a-f0-9]+)$" ./vendor/Nim/config/build_config.txt;
          nimble = findKeyValue "^[[:space:]]+NIMBLE_COMMIT='([a-f0-9]+)'.*$" ./scripts/build_nim.sh;
        };
      in {
        input-commits =
          assert pkgs.lib.assertMsg (checksums.rev == expected.checksums)
            "checksums flake input rev ${checksums.rev} does not match ChecksumsStableCommit ${expected.checksums}";
          assert pkgs.lib.assertMsg (csources.rev == expected.csources)
            "csources flake input rev ${csources.rev} does not match nim_csourcesHash ${expected.csources}";
          assert pkgs.lib.assertMsg (nimble.rev == expected.nimble)
            "nimble flake input rev ${nimble.rev} does not match NIMBLE_COMMIT ${expected.nimble}";
        pkgs.runCommand "verify-flake-input-commits" {} ''
          touch $out
        '';
      });
    };
}
