{ stdenv, lib, pkgs, requireFile, callPackage }: stdenv.mkDerivation rec {
  pname = "xilinx-ise-unwrapped";
  version = "14.7";
  src = requireFile {
    name = "xilinx.tar.zstd";
    hash = "sha256-AmkIejhTqnBcZWUh6Z8gAzSGW+gx2+hbw6FnrbAR5fM=";
    message = "Please check the README.md of the nix-fpga-tools repository for instructions on how to obtain and preprocess the Xilinx ISE zip.";
  };
  nativeBuildInputs = [ pkgs.zstd ];
  buildCommand = ''
    mkdir -p $out
    zstd -c -d $src | tar -xvf - -C $out
  '';
}
