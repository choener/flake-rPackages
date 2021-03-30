# flake-rPackages
experimental flake to repackage rPackages

## How to use

Below is an example ```flake.nix``` that uses the ```rPackages``` overlay. In the example, I want to
have a ```nix develop``` shell with ```R``` and ```CytoML``` enabled.

- ```rPackages``` needs to be integrated into ```inputs```
- we follow ```nixpkgs```
- ```flake-utils``` makes the use of ```outputs``` more convenient

```nix
{
  description = ''
    Usage example
  '';

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-20.09";
    flake-utils.url = "github:numtide/flake-utils";
    rPackages.url = "github:choener/flake-rPackages";
    rPackages.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, rPackages }:
    # provides "R" for all known system environments
    flake-utils.lib.eachDefaultSystem
      (system:
        let pkgs = import nixpkgs { inherit system; overlays = [ self.overlay rPackages.overlay ]; };
        in {
          devShell = pkgs.stdenv.mkDerivation {
            name = "testEnv";
            nativeBuildInputs = [
              (pkgs.rstudioWrapper.override {packages = [pkgs.rPackages.CytoML];})
              (pkgs.rWrapper.override {packages = [pkgs.rPackages.CytoML];})
            ];
          }; # devShell
        }
      ) //
    # provide Rstudio only for x86_64
    {
      studio = let pkgs = nixpkgs.legacyPackages.x86_64-linux;
               in  import ./studio.nix { nixpkgs = pkgs; };
    } //
    {
      overlay = final: prev: {};
    };
}
```

