{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.05";
    esp-r-src = {
      url = "https://www.esru.strath.ac.uk/Downloads/esp-r/ESP-r_V13.3.14_Src.tar.gz";
      flake = false;
    };
    rad5r-src = {
      url = "https://floyd.lbl.gov/radiance/dist/rad5R2all.tar.gz";
      flake = false;
    };
  };
  outputs = { self, nixpkgs, esp-r-src, rad5r-src }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      packages.x86_64-linux = {
        rad5r = pkgs.stdenv.mkDerivation {
          name = "rad5r";
          src = rad5r-src;
          buildInputs = with pkgs; [ libGLU qt512.full libtiff ];
          nativeBuildInputs = with pkgs; [ cmake ];
          cmakeFlags = [
            "-DBUILD_HEADLESS=1"
          ];
          prePatch = ''
            substituteInPlace CMakeLists.txt \
              --replace resources cmake_tests
          '';
        };
        esp-r = pkgs.stdenv.mkDerivation {
          name = "esp-r";
          src = esp-r-src;
          buildInputs = with pkgs; [ makeWrapper gtk2 libxslt libxml2 ];
          nativeBuildInputs = with pkgs; [ pkg-config gfortran ];
          installPhase = "true";
          buildPhase = ''
            patchShebangs ./Install
            substituteInPlace ./Install \
              --replace /usr/lib/X11 ${pkgs.xorg.libX11}/lib \
              --replace /usr/include/X11 ${pkgs.xorg.xorgproto}/include/X11

            ./Install -d $out

            wrapProgram $out/bin/esp-r \
              --prefix PATH : $out/bin

            wrapProgram $out/bin/esp-r \
              --prefix PATH : ${nixpkgs.lib.makeBinPath [ self.packages.x86_64-linux.rad5r pkgs.xterm ]}
          '';
        };
      };
    };
}
