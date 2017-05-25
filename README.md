# d71/d81writer
A 1541 Ultimate 2 write tool
============================

Written by Ernoman and WdW.

Introduction
============

This C64 tool will enable you to use your 1541 Ultimate 2 cartridge (U2) to
write .D71 and .D81 images to a physical drive.

The C64 version uses the standard kernal calls, so operation is slow. A C128
version using burst write commands is in the works.

Preparations
============

Set your physical drive to another id than the emulated U2 drive, because having
two drives with the same device id on the serial bus is asking for trouble.

The diskette must be formatted before you can use it. It does not need
to be empty.  In order to get a 1:1 copy it's best to format the diskette with
the index option, as the copy tool will not write empty sectors.

Enther the U2 cartridge and enable the command interface and the REU with at
least 1MB of memory.

Disable any cartridge in the U2 interface. Some cartridges, like the Retro
Replay, do not play nice and will cause the command interface to fail.

Put your image files somewhere on a USB or Micro SD card and insert it into the
U2.

When the tools starts, double check if you see the ultimate dos version appear
under the header. If this does not happen, re-check your U2 settings.


Usage
=====

1) Enter the type of image you want to write.
2) Enter the path to the folder containing the images files.
3) Type in the name of the image file.
4) Enter the destination drive device ID and watch the counter until it reaches
   track 80 (for a D81 image) or 70 (for a D71 image)
