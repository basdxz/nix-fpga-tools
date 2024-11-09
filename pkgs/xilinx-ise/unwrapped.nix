{ stdenv, lib, pkgs, requireFile, callPackage }: stdenv.mkDerivation rec {
  pname = "xilinx-ise-unwrapped";
  version = "14.7";
  src = requireFile {
    name = "xilinx.tar.zstd";
    sha256 = "034fd6f6aa9927c527f0197ae9d9767c5f7e87d782bcba43d0599c87c777cae6";
    message = "Please check the README.md of the nix-fpga-tools repository for instructions on how to obtain and preprocess the Xilinx ISE zip.";
  };
  nativeBuildInputs = [ pkgs.zstd ];
  buildCommand = ''
    mkdir -p $out
    zstd -c -d $src | tar -xvf - -C $out
  '';
}
