{
  description = "Experimental Nix flake to re-package rPackages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-20.09";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }: let

    overlay = final: prev: let
      rDev = prev.callPackage (import ./default.nix) {};
    in {
      inherit (rDev) rWrapper rstudioWrapper;
      rPackages = rDev.rPackages;
    };
    # each system
    eachSystem = system: let

      pkgs = import nixpkgs {
        inherit system;
        config = {};
        overlays = [ self.overlay ];
      };

      #rDev = pkgs.callPackage (import ./default.nix) {};
      generate-r-packages = pkgs.rWrapper.override { packages = [ pkgs.rPackages.data_table ]; };
      #grp = {};

    in rec {
      devShell = pkgs.stdenv.mkDerivation {
        name = "testEnv";
        nativeBuildInputs = [
          (pkgs.rstudioWrapper.override {packages = [pkgs.rPackages.CytoML];})
          (pkgs.rWrapper.override {packages = [pkgs.rPackages.CytoML];})
        ];
      }; # devShell
      #packages = { inherit (rDev) rWrapper rstudioWrapper; rPackages = rDev.rPackages; };
      #apps.generate-r-packages = flake-utils.lib.mkApp { drv = grp; };
    }; # eachSystem

  in
    flake-utils.lib.eachDefaultSystem eachSystem // { inherit overlay; };
}

