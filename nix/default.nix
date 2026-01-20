{
  pkgs ? import <nixpkgs> { },
  # Source code of this repo.
  src ? ../.,
  # Options: nimbus_light_client, nimbus_validator_client, nimbus_signing_node, all
  targets ? ["build-nim"],
  # Options: 0,1,2
  verbosity ? 1,
  # Perform 2-stage bootstrap instead of 3-stage to save time.
  quickAndDirty ? true,
  # These are the only platforms tested in CI and considered stable.
  stableSystems ? [
    "x86_64-linux" "aarch64-linux" "armv7a-linux"
    "x86_64-darwin" "aarch64-darwin"
    "x86_64-windows"
  ],
}:

# The 'or' is to handle src fallback to ../. which lack submodules attribue.
assert pkgs.lib.assertMsg ((src.submodules or true) == true)
  "Unable to build without submodules. Append '?submodules=1#' to the URI.";

let
  inherit (pkgs) stdenv lib writeScriptBin callPackage;

  nimble = callPackage ./nimble.nix {};
  checksums = callPackage ./checksums.nix {};
  csources = callPackage ./csources.nix {};

  revision = lib.substring 0 8 (src.rev or src.dirtyRev or "unknown");
in stdenv.mkDerivation rec {
  pname = "nbs-nim";
  version = "${callPackage ./version.nix {}}-${revision}";

  inherit src;

  buildInputs = with pkgs; [ openssl ];
  nativeBuildInputs = let
    # Two versions but ne fake git.
    fakeGit = writeScriptBin "git" ''
      [[ $PWD =~ ^.*/Nim$ ]]       && echo ${revision}
      [[ $PWD =~ ^.*/nimblepkg$ ]] && echo ${nimble.rev} || echo unknown
    '';
  in with pkgs; [
    which makeWrapper fakeGit
  ] ++ lib.optionals stdenv.isDarwin [
    pkgs.darwin.cctools
    darwin.apple_sdk.frameworks.Security
  ];

  enableParallelBuilding = true;

  # Avoid Nim cache permission errors.
  XDG_CACHE_HOME = "/tmp";
  NIMBLE_DIR = "/tmp";

  makeFlags = targets ++ [
    "V=${toString verbosity}"
    "QUICK_AND_DIRTY_COMPILER=${if quickAndDirty then "1" else "0"}"
    "QUICK_AND_DIRTY_NIMBLE=${if quickAndDirty then "1" else "0"}"
  ];

  # Generate the nimbus-build-system.paths file.
  patchPhase = ''
    patchShebangs scripts
    make nimbus-build-system-paths
    # Force build of Nimble from dist/nimble source.
    export NIMBLE_COMMIT=""
  '';

  # Avoid nimbus-build-system invoking `git clone` to build Nim.
  preBuild = ''
    pushd vendor/Nim
    cp ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt bin/cacert.pem
    mkdir dist
    cp -r ${nimble}    dist/nimble
    cp -r ${checksums} dist/checksums
    cp -r ${csources}  ${csources.repo}
    chmod 777 -R dist/nimble csources_v2
    popd
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp vendor/Nim/bin/{nim,nimble} $out/bin
    cp -r vendor/Nim/{compiler,config,lib,tools} $out/
  '';

  postFixup = ''
    wrapProgram $out/bin/nimble --prefix LD_LIBRARY_PATH : ${pkgs.openssl.out}/lib
  '';

  # Avoid invalid signature errors on MacOS.
  dontStrip = stdenv.isDarwin;
  # Verify Nix patching did not break codesigning on MacOS.
  doInstallCheck = true;
  installCheckPhase = (lib.optionalString stdenv.isDarwin ''
    /usr/bin/codesign --verify $out/bin/nim
  '') + ''
    $out/bin/nim --version
    $out/bin/nimble --version
  '';

  meta = with lib; {
    homepage = "https://nimbus.guide/";
    description = "Common parts of the build system used by Nimbus and related projects";
    longDescription = ''
      We focus on building Nim software on multiple platforms, without having to deal
      with language-specific package managers.
    '';
    license = with licenses; [asl20 mit];
    mainProgram = "nim";
    platforms = stableSystems;
  };
}
