{
  description = "AeroHints - keyboard shortcut overlay for AeroSpace";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
      version = "0.1.0";
    in
    {
      packages.${system}.default = pkgs.stdenvNoCC.mkDerivation {
        pname = "aerohints";
        inherit version;

        src = pkgs.fetchurl {
          url = "https://github.com/jackddouglas/AeroHints/releases/download/v${version}/AeroHints.zip";
          hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
        };

        nativeBuildInputs = [ pkgs.unzip ];
        sourceRoot = ".";

        installPhase = ''
          mkdir -p $out/bin
          cp AeroHints $out/bin/
          chmod +x $out/bin/AeroHints
        '';
      };
    };
}
