{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.05";
    esp-r-src = {
      url = "https://www.esru.strath.ac.uk/Downloads/esp-r/ESP-r_V13.3.14_Src.tar.gz";
      flake = false;
    };
    rad5r-src = {
      url = "github:NREL/Radiance/2fcca99ace2f2435f32a09525ad31f2b3be3c1bc";
      flake = false;
    };
  };
  outputs = { self, nixpkgs, esp-r-src, rad5r-src }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      realCsh = pkgs.writeShellScriptBin "csh"
        ''${pkgs.tcsh}/bin/tcsh "$@"'';
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
          '';
        };
        esp-r = pkgs.stdenv.mkDerivation {
          name = "esp-r";
          src = esp-r-src;
          buildInputs = with pkgs; [ makeWrapper gtk2 libxslt libxml2 ];
          nativeBuildInputs = with pkgs; [ pkg-config gfortran which xterm ];
          installPhase = "true";
          buildPhase = ''
            export HOME=$TMP
            patchShebangs ./Install
            patchShebangs ./modish/*

            substituteInPlace ./src/epdf/newnet.F \
              --replace ")                                      '" ")"

            substituteInPlace ./Install \
              --replace /usr/lib/X11 ${pkgs.xorg.libX11}/lib \
              --replace /usr/include/X11 ${pkgs.xorg.xorgproto}/include/X11 \
              --replace 'mode="interactive"' 'mode="silent"' \
              --replace '-mcmodel=medium' '-mcmodel=medium -ffixed-line-length-none -ffree-line-length-none'

            for i in $(grep -rl '/opt/esp-r' ./src)
            do
              substituteInPlace $i \
                --replace /opt/esp-r $out
            done

            ./Install -d $out

            wrapProgram $out/bin/esp-r \
              --prefix PATH : $out/bin

            wrapProgram $out/bin/esp-r \
              --prefix PATH : ${nixpkgs.lib.makeBinPath [ self.packages.x86_64-linux.rad5r pkgs.xterm pkgs.imagemagick pkgs.xfig pkgs.fig2dev pkgs.xorg.libXft.dev ]}
          '';
        };
      };
    };
}
