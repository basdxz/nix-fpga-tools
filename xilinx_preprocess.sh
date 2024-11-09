#!/bin/sh
echo Extracting vmdk from nested zip
7zz e -so Xilinx_ISE_14.7_Win10_14.7_VM_0213_1.zip ova/14.7_VM.ova | tar -xf - 14.7_VM-disk001.vmdk
echo Extracting disk image from VMDK
7zz e 14.7_VM-disk001.vmdk 0.img
echo Removing VMDK
rm 14.7_VM-disk001.vmdk
echo Extracting xilinx code from disk image
7zz x -snld -o./x_root 0.img opt/Xilinx home/ise
echo Removing disk image
rm 0.img
echo Creating program archive
tar --owner=0 --group=0 --numeric-owner --mtime='@0' --sort=name -cO -C ./x_root . | zstd -o xilinx.tar.zstd
echo Removing extracted code
rm -rf ./x_root
echo Finished
