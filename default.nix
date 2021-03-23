
# We provide replacements for @rWrapper@, @rstudioWrapper@, and @rPackages@.

{ lib, config, pkgs, lndir, runCommand, makeWrapper, callPackage
, R, rstudio, qt5 }: rec {



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



  rStudioWrapperNew = { lib, runCommand, rstudio, wrapQtAppsHook, recommendedPackages, packages, qtbase }:
    let
      qtVersion = with lib.versions; "${major qtbase.version}.${minor qtbase.version}";
      Rwrapped = rWrapper.override { packages = recommendedPackages ++ packages; };
    in
    runCommand (rstudio.name + "-wrapper") {
      preferLocalBuild = true;
      allowSubstitutes = false;

      nativeBuildInputs = [wrapQtAppsHook];
      dontWrapQtApps = true;

      buildInputs = [Rwrapped rstudio]; # ++ recommendedPackages ++ packages;

      # rWrapper points R to a specific set of packages by using a wrapper
      # (as in https://nixos.org/nixpkgs/manual/#r-packages) which sets
      # R_LIBS_SITE.  Ordinarily, it would be possible to make RStudio use
      # this same set of packages by simply overriding its version of R
      # with the wrapped one, however, RStudio internally overrides
      # R_LIBS_SITE.  The below works around this by turning R_LIBS_SITE
      # into an R file (fixLibsR) which achieves the same effect, then
      # uses R_PROFILE_USER to load this code at startup in RStudio.
      fixLibsR = "fix_libs.R";
    }
    ''
    R_LIBS_SITE=${Rwrapped}/library
    mkdir $out
    ln -s ${rstudio}/share $out
    echo "# Autogenerated by wrapper-rstudio.nix from R_LIBS_SITE" > $out/$fixLibsR
    echo -n ".libPaths(c(.libPaths(), \"" >> $out/$fixLibsR
    echo -n $R_LIBS_SITE | sed -e 's/:/", "/g' >> $out/$fixLibsR
    echo -n "\"))" >> $out/$fixLibsR
    echo >> $out/$fixLibsR
    makeQtWrapper ${rstudio}/bin/rstudio $out/bin/rstudio \
      --set R_PROFILE_USER $out/$fixLibsR
    cp ${Rwrapped}/bin/R $out/bin/
    ln -s ${Rwrapped}/library $out/library
    echo "$R_LIBS_SITE"
    '';

  rstudioWrapper = lib.makeOverridable rStudioWrapperNew {
    inherit runCommand lib rstudio;
    wrapQtAppsHook = qt5.wrapQtAppsHook;
    qtbase = qt5.qtbase;
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
