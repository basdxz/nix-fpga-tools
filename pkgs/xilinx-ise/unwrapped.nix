{ stdenv, lib, pkgs, requireFile, callPackage }: stdenv.mkDerivation rec {
  pname = "xilinx-ise-unwrapped";
  version = "14.7";
  src = requireFile {
    name = "xilinx.tar.zstd";
    hash = "sha256-A0/W9qqZJ8Un8Bl66dl2fF9+h9eCvLpD0Fmch8d3yuY=";
    message = "Please check the README.md of the nix-fpga-tools repository for instructions on how to obtain and preprocess the Xilinx ISE zip.";
  };
  nativeBuildInputs = [ pkgs.zstd ];
  buildCommand = ''
    mkdir -p $out
    zstd -c -d $src | tar -xvf - -C $out
  '';
}
