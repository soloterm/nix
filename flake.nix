{
  description = "Solo for Nix: the Linux release published on soloterm.com";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      # Solo is commercial (unfree). Allow exactly this package so `nix run`
      # works without --impure or a global allowUnfree.
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg: nixpkgs.lib.getName pkg == "solo";
      };
    in
    {
      packages.${system} = rec {
        solo = pkgs.callPackage ./package.nix { };
        default = solo;
      };

      apps.${system}.default = {
        type = "app";
        program = "${self.packages.${system}.solo}/bin/Solo";
      };

      # For use with your own nixpkgs, which must allow the unfree `solo` package.
      overlays.default = final: _prev: {
        solo = final.callPackage ./package.nix { };
      };

      checks.${system} = {
        solo = self.packages.${system}.solo;
        launch = pkgs.testers.runNixOSTest (import ./ci/launch-test.nix self.packages.${system}.solo);
      };
    };
}
