
# We provide replacements for @rWrapper@, @rstudioWrapper@, and @rPackages@.

{ lib, config, pkgs, lndir, runCommand, makeWrapper, callPackage, R }: rec {

  # <https://discourse.mc-stan.org/t/rstan-on-nixos/17048/12>
  rWrapperNew = { runCommand, R, makeWrapper, lndir, recommendedPackages, packages }:
    runCommand (R.name + "-wrapper") {
      preferLocalBuild = true;
      allowSubstitutes = false;
      buildInputs = [R] ++ recommendedPackages ++ packages;
      nativeBuildInputs = [makeWrapper];
      # Make the list of recommended R packages accessible to other packages such as rpy2
      # (Same as in the original rWrapper)
      passthru = { inherit recommendedPackages; };
    }
    # Wrap a site lib, similar to symlinkJoin but without propagating buildInputs.
    ''
      mkdir -p $out/library
      for lib in $(echo -n $R_LIBS_SITE | sed -e 's/:/\n/g'); do
        ${lndir}/bin/lndir -silent $lib $out/library/
      done
      mkdir -p $out/bin
      cd ${R}/bin
      for exe in *; do
        makeWrapper ${R}/bin/$exe $out/bin/$exe \
          --prefix "R_LIBS_SITE" ":" "$out/library"
      done
    '';

  rWrapper = lib.makeOverridable rWrapperNew {
    inherit runCommand R makeWrapper lndir;
    recommendedPackages = with rPackages;
      [ boot class cluster codetools foreign KernSmooth lattice MASS
        Matrix mgcv nlme nnet rpart spatial survival
      ];
    packages = [];
  };

  rPackages = lib.dontRecurseIntoAttrs (callPackage ./r-modules {
    overrides = (config.rPackageOverrides or (p: {})) pkgs;
  });

}
