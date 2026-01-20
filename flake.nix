{
  description = "nimbus-build-system";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs?rev=ff0dbd94265ac470dda06a657d5fe49de93b4599";

  outputs = { self, nixpkgs }:
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
    in rec {
      packages = forAllSystems (system: let
        buildTarget = pkgsFor.${system}.callPackage ./nix/default.nix {
          inherit stableSystems; src = self;
        };
        build = targets: buildTarget.override { inherit targets; };
      in rec {
        nim = build ["build-nim"];

        default = nim;
      });
    };
}
