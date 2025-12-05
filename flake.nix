{
  description = "FPGA tools for Nix.";

  inputs.nixpkgs.url = "nixpkgs/nixpkgs-unstable";
  inputs.nixpkgs_libstdcxx5.url = "nixpkgs/c8bb7b26f2c6ecc39be2c4ddde5f5d152e4abc65";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { nixpkgs, nixpkgs_libstdcxx5, flake-utils, ... }:
    let
      # System types to support.
      systems = [ "x86_64-linux" ];
      outputs = flake-utils.lib.eachSystem systems (system: let
        pkgs = nixpkgs.legacyPackages.${system};
        pkgs_old = nixpkgs_libstdcxx5.legacyPackages.${system};
      in rec {
        packages = {
          xilinx-ise = pkgs.callPackage ./pkgs/xilinx-ise { libstdcxx5 = pkgs_old.libstdcxx5; };
          xilinx-udev-rules = pkgs.callPackage ./pkgs/xilinx-ise/udev-rules.nix { };
        };
        apps = {
          xilinx-ise = {
            type = "app";
            program = "${packages.xilinx-ise}/bin/xilinx-ise";
          };
        };
      });
    in outputs // {
        overlays.default = final: prev: let
          packages = outputs.packages.${prev.stdenv.hostPlatform.system};
        in {
          xilinx-ise = packages.xilinx-ise;
          xilinx-udev-rules = packages.xilinx-udev-rules;
        };
    };
}
