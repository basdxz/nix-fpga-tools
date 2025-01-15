{
  description = "FPGA tools for Nix.";

  inputs.nixpkgs.url = "nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { nixpkgs, flake-utils, ... }:
    let
      # System types to support.
      systems = [ "x86_64-linux" ];
      outputs = flake-utils.lib.eachSystem systems (system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in rec {
        packages = {
          xilinx-ise = pkgs.callPackage ./pkgs/xilinx-ise { };
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
          packages = outputs.packages.${prev.system};
        in {
          xilinx-ise = packages.xilinx-ise;
          xilinx-udev-rules = packages.xilinx-udev-rules;
        };
    };
}
