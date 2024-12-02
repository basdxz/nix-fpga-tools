{ stdenv, lib, pkgs, callPackage, writeScript, makeDesktopItem }:

let
  buildFHSUserEnv = callPackage ./fhs.nix { };
  unwrapped = callPackage ./unwrapped.nix { };
  xilinx-jtag-fw = callPackage ./jtag-fw.nix { };
  motif3-compat = pkgs: stdenv.mkDerivation {
    name = "motif3-compat";
    phases = [ "installPhase" ];
    installPhase = ''
      mkdir -p $out/lib
      ln -s ${pkgs.motif}/lib/libXm.so.4 $out/lib/libXm.so.3
    '';
  };
in buildFHSUserEnv rec {
  name = "xilinx-ise";

  targetPkgs = pkgs: with pkgs; [
    fontconfig
    freetype
    glib
    iproute2
    (callPackage ./libstdc++/5.nix { })
    libusb-compat-0_1
    libusb1
    libuuid
    motif
    (motif3-compat pkgs)
    xilinx-jtag-fw
    xorg.libICE
    xorg.libSM
    xorg.libX11
    xorg.libXcursor
    xorg.libXext
    xorg.libXft
    xorg.libXi
    xorg.libXmu
    xorg.libXp
    xorg.libXrandr
    xorg.libXrender
    xorg.libXt
    xorg.libXtst
    zlib

    # Xilinx ISE expects QT3 but works fine with QT5.
    libsForQt5.qtbase
    libsForQt5.qtdeclarative
    libsForQt5.qtimageformats
    libsForQt5.qtsvg
    libsForQt5.qtx11extras
  ];

  multiPkgs = pkgs: with pkgs; [
    ncurses5
  ];

  # Network namespace required so that a dummy NIC with the required MAC can
  # be provided.
  unshareNet = true;

  extraBwrapArgs = [
    "--ro-bind ${unwrapped}/opt/Xilinx /opt/Xilinx"
    "--ro-bind ${unwrapped}/home/ise/.Xilinx/Xilinx.lic ~/.Xilinx/Xilinx.lic"
    "--cap-add CAP_NET_ADMIN"
  ];

  extraInstallCommands = let
    wrappers = import ./wrappers.nix;

    desktopItemSymlinks = lib.foldr (item: str:
    let
      desktopItem = makeDesktopItem {
        type = "Application";
        name = item.name;
        desktopName = item.name;
        comment = item.name;
        icon = "${unwrapped}/opt/Xilinx/14.7/ISE_DS/ISE/icons/${item.icon}";
        exec = "${name} ${item.exec}";
      };
    in
      str + "ln -s ${desktopItem}/share/applications/* $out/share/applications\n"
    ) "" wrappers.graphical;

    executables =
      (map (item: item.exec) wrappers.graphical) ++ wrappers.commandLine;
  in ''
    mkdir -p $out/share/applications
    ${desktopItemSymlinks}

    WRAPPER=$out/bin/${name}
    EXECUTABLES="${lib.concatStringsSep " " (executables)}"
    for executable in $EXECUTABLES; do
        echo "#!${stdenv.shell}" >> $out/$executable
        echo "$WRAPPER $executable \$@" >> $out/$executable
    done
    cd $out
    chmod +x $EXECUTABLES
    # link into $out/bin so executables become available on $PATH
    ln --symbolic --relative --target-directory $out/bin $EXECUTABLES
  '';

  runScript = writeScript "${name}-wrapper" ''
    # Create the eth0 interface required for the included license.
    ip link add eth0 type dummy
    ip link set dev eth0 address 08:00:27:68:C9:35

    # Configure the environment.
    source /opt/Xilinx/14.7/ISE_DS/common/.settings64.sh /opt/Xilinx/14.7/ISE_DS/common
    source /opt/Xilinx/14.7/ISE_DS/EDK/.settings64.sh /opt/Xilinx/14.7/ISE_DS/EDK
    source /opt/Xilinx/14.7/ISE_DS/PlanAhead/.settings64.sh /opt/Xilinx/14.7/ISE_DS/PlanAhead
    source /opt/Xilinx/14.7/ISE_DS/ISE/.settings64.sh /opt/Xilinx/14.7/ISE_DS/ISE

    # Required to use QT5 in place of QT6
    export LD_LIBRARY_PATH=${pkgs.libsForQt5.qtbase}/lib:$LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=${pkgs.libsForQt5.qtdeclarative}/lib:$LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=${pkgs.libsForQt5.qtimageformats}/lib:$LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=${pkgs.libsForQt5.qtsvg}/lib:$LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=${pkgs.libsForQt5.qtx11extras}/lib:$LD_LIBRARY_PATH

    export LD_LIBRARY_PATH=${pkgs.libusb-compat-0_1}/lib:$LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=${pkgs.libusb1}/lib:$LD_LIBRARY_PATH

    # Copied from the Arch Linux Wiki: https://wiki.archlinux.org/title/Xilinx_ISE_WebPACK#Running_Xilinx_tools_from_within_KDE
    unset QT_PLUGIN_PATH

    # Execute target.
    exec $@
  '';
}
