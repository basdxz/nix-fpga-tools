{
  stdenv,
  lib,
  callPackage,
  buildFHSEnv,
  fetchFromGitHub,
  makeDesktopItem,
  runtimeShell,
  libsForQt5,
  libusb-compat-0_1,
  libusb1,
  passt,
}:
let
  unwrapped = callPackage ./unwrapped.nix { };
  xilinx-jtag-fw = callPackage ./jtag-fw.nix { };
  motif3-compat =
    pkgs:
    stdenv.mkDerivation {
      name = "motif3-compat";
      phases = [ "installPhase" ];
      installPhase = ''
        mkdir -p $out/lib
        ln -s ${pkgs.motif}/lib/libXm.so.4 $out/lib/libXm.so.3
      '';
    };
  libstdcxx5 =
    pkgs:
    (import (fetchFromGitHub {
      owner = "NixOS";
      repo = "nixpkgs";
      rev = "c8bb7b26f2c6ecc39be2c4ddde5f5d152e4abc65";
      hash = "sha256-8+rgprS5YWlEA4vILg/MBKqlgm+HPEdUAhlTFQO0Tmc=";

    }) { inherit (pkgs.stdenv.hostPlatform) system; }).libstdcxx5;

  # Applying the below fix as ise likely has the same LD_LIBRARY_PATH pollution problem.
  # https://github.com/NixOS/nixpkgs/blob/ec63f4b01f177b7d8c92e7002e2d9292f886b67c/pkgs/by-name/qu/quartus-prime-lite/package.nix#L35-L48
  xdgOpenWrapper =
    pkgs:
    pkgs.writeShellScriptBin "firefox" ''
      export LD_LIBRARY_PATH=$XILINX_ORIG_LIBPATH
      exec ${lib.getExe' pkgs.xdg-utils "xdg-open"} "$@"
    '';
in
buildFHSEnv rec {
  pname = "xilinx-ise";
  inherit (unwrapped) version;

  targetPkgs =
    pkgs: with pkgs; [
      (xdgOpenWrapper pkgs)
      # (libstdcxx5 pkgs)
      fontconfig
      freetype
      glib
      fxload
      iproute2
      libcxx
      libusb-compat-0_1
      libusb1
      libuuid
      motif
      (motif3-compat pkgs)
      xilinx-jtag-fw
      libice
      libsm
      libx11
      libxcursor
      libxext
      libxft
      libxi
      libxmu
      libxp
      libxrandr
      libxrender
      libxt
      libxtst
      zlib

      # Xilinx ISE expects QT3 but works fine with QT5.
      libsForQt5.qtbase
      libsForQt5.qtdeclarative
      libsForQt5.qtimageformats
      libsForQt5.qtsvg
      libsForQt5.qtx11extras
    ];

  multiPkgs =
    pkgs: with pkgs; [
      fxload
      ncurses5
    ];

  unshareUser = true;
  extraBwrapArgs = [
    "--ro-bind ${unwrapped}/opt/Xilinx /opt/Xilinx"
    "--ro-bind ${unwrapped}/home/ise/.Xilinx/Xilinx.lic ~/.Xilinx/Xilinx.lic"
    # Don't appear as root in the final environment
    "--uid $bwrap_uid"
    "--gid $bwrap_gid"
  ];

  # Rename the bwrap wrapper as we have an outer network wrapper
  executableName = "${pname}-bwrap";

  extraInstallCommands =
    let
      wrappers = import ./wrappers.nix;

      desktopItemSymlinks = lib.foldr (
        item: str:
        let
          desktopItem = makeDesktopItem {
            type = "Application";
            name = item.name;
            desktopName = item.name;
            comment = item.name;
            icon = "${unwrapped}/opt/Xilinx/14.7/ISE_DS/ISE/icons/${item.icon}";
            exec = "${item.exec}";
          };
        in
        str + "ln -s ${desktopItem}/share/applications/* $out/share/applications\n"
      ) "" wrappers.graphical;

      executables = (map (item: item.exec) wrappers.graphical) ++ wrappers.commandLine;
    in
    ''
      mkdir -p $out/share/applications
      ${desktopItemSymlinks}

      bubblewrap=$out/bin/${executableName}
      wrapper=$out/bin/${pname}
      cat > "$wrapper" <<EOT
      #!${runtimeShell}
      export bwrap_uid=\$(id -u)
      export bwrap_gid=\$(id -g)
      ${passt}/bin/pasta \
        --quiet \
        --runas \$(whoami) \
        --hostname \$(hostname) \
        --ns-mac-addr 08:00:27:68:C9:35 \
        --ns-ifname eth0 \
        --config-net \
        $bubblewrap "\$@"
      EOT
      chmod +x "$wrapper"

      EXECUTABLES="${lib.concatStringsSep " " executables}"
      for executable in $EXECUTABLES; do
      cat > "$out/$executable" <<EOT
      #!${runtimeShell}
      $wrapper $executable "\$@"
      EOT
      done
      cd $out
      chmod +x $EXECUTABLES
      # link into $out/bin so executables become available on $PATH
      ln --symbolic --relative --target-directory $out/bin $EXECUTABLES
    '';

  profile = ''
    export XILINX_ORIG_LIBPATH=LD_LIBRARY_PATH

    # Configure the environment.
    source /opt/Xilinx/14.7/ISE_DS/common/.settings64.sh /opt/Xilinx/14.7/ISE_DS/common
    source /opt/Xilinx/14.7/ISE_DS/EDK/.settings64.sh /opt/Xilinx/14.7/ISE_DS/EDK
    source /opt/Xilinx/14.7/ISE_DS/PlanAhead/.settings64.sh /opt/Xilinx/14.7/ISE_DS/PlanAhead
    source /opt/Xilinx/14.7/ISE_DS/ISE/.settings64.sh /opt/Xilinx/14.7/ISE_DS/ISE

    # Required to use QT5 in place of QT6
    export LD_LIBRARY_PATH=${libsForQt5.qtbase}/lib:$LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=${libsForQt5.qtdeclarative}/lib:$LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=${libsForQt5.qtimageformats}/lib:$LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=${libsForQt5.qtsvg}/lib:$LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=${libsForQt5.qtx11extras}/lib:$LD_LIBRARY_PATH

    export LD_LIBRARY_PATH=${libusb-compat-0_1}/lib:$LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=${libusb1}/lib:$LD_LIBRARY_PATH

    # Copied from the Arch Linux Wiki: https://wiki.archlinux.org/title/Xilinx_ISE_WebPACK#Running_Xilinx_tools_from_within_KDE
    unset QT_PLUGIN_PATH
  '';
  runScript = "";
}
