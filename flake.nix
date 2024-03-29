{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.05";
    rad5r-missingFiles = {
      url = "https://github.com/MatthewCroughan/esp-r-nix/releases/download/v13.3.14/rad5r-missingFiles.tar.zst";
      flake = false;
    };
    esp-r-src = {
      url = "https://github.com/matthewcroughan/esp-r-nix/releases/download/v13.3.14/ESP-r_V13.3.14_Src-repacked.tar.zst";
      flake = false;
    };
    rad5r-src = {
      url = "https://github.com/MatthewCroughan/esp-r-nix/releases/download/v13.3.14/rad5r-src.tar.zst";
      flake = false;
    };
  };
  outputs = { self, nixpkgs, esp-r-src, rad5r-src, rad5r-missingFiles }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      realCsh = pkgs.writeShellScriptBin "csh"
        ''${pkgs.tcsh}/bin/tcsh "$@"'';
      realCp = pkgs.writeShellScriptBin "cp"
        ''${pkgs.coreutils}/bin/cp --no-preserve=mode "$@"'';
    in
    {
      packages.x86_64-linux = {
#        modish = pkgs.perlPackages.buildPerlPackage {
#          pname = "Modish";
#          version = "0.669";
#          src = builtins.fetchurl {
#            url = "https://cpan.metacpan.org/authors/id/G/GL/GLBRUNE/Sim-OPT-0.669.tar.gz";
#            sha256 = "1q35bayvkwrggia5jvjrrjg8shsp0snna1xy75v191qlhbi5ycc9";
#          };
#        };
        rad5r = pkgs.stdenv.mkDerivation {
          name = "rad5r";
          src = rad5r-src;
          buildInputs = with pkgs; [ libGLU qt5.full libtiff realCsh tk ];
          nativeBuildInputs = with pkgs; [ cmake ];
          prePatch = ''
            sed -i '/fixup_bundle/d' InstallRules/dependencies.cmake.in

            # The font 8x13 seems to be used, but I cannot figure out how to get
            # this into the closure for this package. But it seems like the font
            # 6x13 is always available on all X servers, so this patch makes the
            # code use that instead. This is still impure, and should be fixed,
            # no pun intended. "The "6x13" font is usually also available under
            # the alias "fixed", a font name that is expected to be available on
            # every X server. "
            # https://en.wikipedia.org/wiki/Fixed_(typeface)
            for i in $(grep -rl '8x13')
            do
              substituteInPlace $i \
                --replace 8x13 6x13
            done
          '';
          # Some files are missing from the latest radiance, that shouldn't
          # have been deleted by the authors. But they never tested their code.
          # https://github.com/NREL/Radiance/issues/15
          postFixup = ''
            cp ${rad5r-missingFiles}/lib/adobe.cal $out/lib
            cp ${rad5r-missingFiles}/lib/dirt.cal $out/lib
            cp ${rad5r-missingFiles}/lib/picture.cal $out/lib
          '';
        };
        esp-r = pkgs.symlinkJoin {
          name = "esp-r";
          paths = [ self.packages.x86_64-linux.esp-r-unwrapped ];
          buildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/esp-r \
              --prefix PATH : $out/bin

            wrapProgram $out/bin/esp-r \
              --prefix PATH : ${nixpkgs.lib.makeBinPath [ self.packages.x86_64-linux.rad5r pkgs.xterm pkgs.imagemagick pkgs.xfig pkgs.fig2dev pkgs.nedit realCp ]} \
              --set RAYPATH "${self.packages.x86_64-linux.rad5r}/lib"
          '';
        };
        esp-r-unwrapped = pkgs.stdenv.mkDerivation {
          name = "esp-r";
          src = esp-r-src;
          buildInputs = with pkgs; [ makeWrapper gtk2 libxslt libxml2 ];
          nativeBuildInputs = with pkgs; [ pkg-config gfortran which xterm ];
          installPhase = "true";
          buildPhase = ''
            export HOME=$TMP
            patchShebangs ./Install
            patchShebangs ./modish/*

            substituteInPlace ./src/eprj/cadio.F \
              --replace 'cfg*144,cfg_path*84,cfg_root*72,doc_file*96' 'cfg*4096,cfg_path*4096,cfg_root*4096,doc_file*4096'

            substituteInPlace ./src/epdf/newnet.F \
              --replace ")                                      '" ")"

            substituteInPlace ./Install \
              --replace /usr/lib/X11 ${pkgs.xorg.libX11}/lib \
              --replace /usr/include/libxml2 ${pkgs.libxml2.dev}/include/libxml2 \
              --replace /usr/include/X11 ${pkgs.xorg.xorgproto}/include/X11 \
              --replace 'mode="interactive"' 'mode="silent"' \
              --replace '-mcmodel=medium' '-mcmodel=medium -ffixed-line-length-none -ffree-line-length-none'

            for i in $(grep -rl '/opt/esp-r' ./src)
            do
              substituteInPlace $i \
                --replace /opt/esp-r $out
            done

            ./Install -d $out
          '';
        };
      };
    };
}
