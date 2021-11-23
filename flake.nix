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
    }; # default overlay
    overlays = {
      # flow cytometry overlay
      flowCytometry = import ./flowCytometry.nix;
    };
    # each system
    eachSystem = system: let

      pkgs = import nixpkgs {
        inherit system;
        config = {};
        overlays = [ self.overlay self.overlays.flowCytometry ];
      };

      generate-r-packages = pkgs.rWrapper.override { packages = [ pkgs.rPackages.data_table ]; };

    in rec {
      devShell = pkgs.stdenv.mkDerivation {
        name = "testEnv";
        nativeBuildInputs = [
          (pkgs.rstudioWrapper.override {packages = [pkgs.rPackages.CytoML];})
          (pkgs.rWrapper.override {packages = [pkgs.rPackages.CytoML];})
          #(pkgs.rWrapper.override {packages = [pkgs.rPackages.Rhdf5lib];})
        ];
      }; # devShell
      #packages = pkgs.rPackages;
    }; # eachSystem

  in
    flake-utils.lib.eachDefaultSystem eachSystem // { inherit overlay overlays; };
}

