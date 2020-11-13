#!/usr/bin/env python3
# -*- coding: utf-8 -*-

#
# Copyright 2020, DornerWorks Ltd.
#
# SPDX-License-Identifier: MIT
#

from pathlib import Path
import argparse, subprocess, re, tempfile, os

# This should get changed by sed:
kernel_image = "SEL4IMAGE"

def main():
    parser = argparse.ArgumentParser(prog='make_polarfire_sd_card.py',
                                     usage='%(prog)s --device DEVICE [options]',
                                     description='Builds a bootable SD card')

    parser.add_argument('-d', '--device', dest='device', action='store',
                        required=True, help='The SD card to format')

    args = parser.parse_args()

    if(re.match(r'/dev/sd[a-zA-Z]\d', args.device)):
        print("ERROR: A partition was specified but should be a device")
        exit(0)

    p = Path(args.device)
    if(not p.is_block_device()):
        print("ERROR: The specified device is not a block device")
        exit(0)

    if(args.device == "/dev/sda"):
        answer = input("WARNING: /dev/sda is commonly your system drive. Are "
                       "you sure you want to format that device? ")
        if((answer == "y") or (answer == "yes")):
            pass
        else:
            print("Received {}, exiting...".format(answer))
            exit(0)

    # Find mounted partitions
    df_cmd = "df -h"
    process = subprocess.run(df_cmd, shell=True, check=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)

    output = process.stdout.decode('ascii').split()

    protected_mounts = ["/bin",
                        "/boot",
                        "/dev",
                        "/etc",
                        "/home",
                        "/lib",
                        "/lost+found",
                        "/opt",
                        "/proc",
                        "/root",
                        "/run",
                        "/sbin",
                        "/srv",
                        "/sys",
                        "/tmp",
                        "/usr",
                        "/var"
                        ]

    for n in range(len(output)):
        if(args.device in output[n]):
            if((output[n+5] == '/') or (output[n+5] == '/home')):
                print("WARNING: " + args.device + " is your system drive. Exiting...")
                exit(0)
            else:
                for protected_mount in protected_mounts:
                    if(output[n+5] == protected_mount):
                        answer = input("WARNING: " + args.device
                                       + " is mounted on " + protected_mount +
                                       ". Are you sure you want to format that device? ")
                        if((answer == "y") or (answer == "yes")):
                            pass
                        else:
                            exit(0)

                # Unmount device partition if mounted
                umount_cmd = "umount" + " " + output[n]
                print("Unmounting " + output[n])
                process = subprocess.run(umount_cmd, shell=True, stderr=subprocess.STDOUT)

    # Format the SD card
    create_parts = ("sgdisk -Zo "
                   "--new=1:2048:3248 --change-name=1:uboot "
                   "--typecode=1:21686148-6449-6E6F-744E-656564454649 "
                   "--new=2:4096:88063 --change-name=2:kernel "
                   "--typecode=2:0FC63DAF-8483-4772-8E79-3D69D8477DE4 "
                   + str(args.device))

    print("Configuring the device's partition table")
    process = subprocess.run(create_parts, shell=True, check=True, stderr=subprocess.STDOUT)

    images_dir = "images"

    payload_part = "1"
    kernel_part = "2"

    # Write payload.bin to uboot partition
    dd_cmd = ("dd if=" + images_dir + "/" + "payload.bin" + " " + "of=" + args.device
             + payload_part)
    print("Writing " + images_dir + "/" + "payload.bin" + " to " + args.device + kernel_part)
    process = subprocess.run(dd_cmd, shell=True, check=True, stderr=subprocess.STDOUT)

    # Format kernel partition
    format_cmd = "mkfs.vfat -F16" + " " + args.device + kernel_part
    print("Formatting " + args.device + kernel_part + " to " + "FAT16")
    process = subprocess.run(format_cmd, shell=True, check=True, stderr=subprocess.STDOUT)

    # Mount the kernel partition
    mount_point = tempfile.mkdtemp(prefix="polarfire-sd-")

    mount_cmd = "mount" + " " + args.device + kernel_part + " " + mount_point
    print("Mounting " + args.device + kernel_part + " to " + mount_point)
    process = subprocess.run(mount_cmd, shell=True, check=True, stderr=subprocess.STDOUT)

    # Copy images to kernel partition

    uEnv_file = "uEnv.txt"
    copy_images_cmd = ("cp" + " "
                       + images_dir + "/" + kernel_image + " "
                       + images_dir + "/" + uEnv_file + " "
                       + mount_point)
    print("Copying " + images_dir + "/" + kernel_image + " to " + mount_point)
    process = subprocess.run(copy_images_cmd, shell=True, check=True, stderr=subprocess.STDOUT)

    # Unmount the partition
    umount_cmd = "umount" + " " + mount_point
    print("Unmounting " + mount_point)
    process = subprocess.run(umount_cmd, shell=True, check=True, stderr=subprocess.STDOUT)

    print("Deleting " + mount_point)
    os.rmdir(mount_point)

    print("Success!")

if __name__ == "__main__":
    main()
