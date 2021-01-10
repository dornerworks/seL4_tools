#!/usr/bin/env python3
# -*- coding: utf-8 -*-

#
# Copyright 2020, DornerWorks Ltd.
#
# SPDX-License-Identifier: MIT
#

from pathlib import Path
import argparse, subprocess, re, tempfile, os, sys

# This should get changed by sed:
kernel_image = "@SEL4IMAGE@"

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
    df_process = subprocess.run(df_cmd,
                                shell=True,
                                check=False,
                                stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE)

    if df_process.returncode != 0:
        print('!! Error Running DF !!')
        print(df_process.stderr.decode())
        sys.exit(1)

    output = df_process.stdout.decode('ascii').split()

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
                umount_process = subprocess.run(umount_cmd,
                                                shell=True,
                                                check=False,
                                                stderr=subprocess.PIPE)
                if umount_process.returncode != 0:
                    print('!! Error unmounting {}'.format(output[n]))
                    print(umount_process.stderr.decode())

    images_dir = os.path.join(os.getcwd(), "images")

    payload_size = os.path.getsize(os.path.join(images_dir, "payload.bin"))
    sector_size = 2048
    part1_start = sector_size
    part1_end = part1_start + (((part1_start + payload_size)%sector_size) * sector_size)
    part2_start = part1_end + sector_size
    part2_end = part2_start + (((part2_start + 8396)%sector_size) * sector_size)

    # Format the SD card
    create_parts = ("sgdisk -Zo "
                   "--new=1:{}:{} --change-name=1:payload "
                   "--typecode=1:21686148-6449-6E6F-744E-656564454649 "
                   "--new=2:{}:{} --change-name=2:kernel "
                    "--typecode=2:0FC63DAF-8483-4772-8E79-3D69D8477DE4 {}".format(part1_start,
                                                                                  part1_end,
                                                                                  part2_start,
                                                                                  part2_end,
                                                                                  args.device))

    create_parts_process = subprocess.run(create_parts,
                                          shell=True,
                                          check=False,
                                          stderr=subprocess.PIPE)
    if create_parts_process.returncode != 0:
        print('!! Error Creating Partitions !!')
        print(create_parts_process.stderr.decode())
        sys.exit(1)

    print("Configuring the device's partition table")

    payload_part = "1"
    kernel_part = "2"

    # Write payload.bin to uboot partition
    dd_cmd = ("dd if=" + images_dir + "/" + "payload.bin" + " " + "of=" + args.device
             + payload_part)
    print("Writing " + images_dir + "/" + "payload.bin" + " to " + args.device + kernel_part)
    dd_process = subprocess.run(dd_cmd,
                                shell=True,
                                check=False,
                                stderr=subprocess.PIPE)
    if dd_process.returncode != 0:
        print('!! Error Running DD !!')
        print(dd_process.stderr.decode())
        sys.exit(1)

    # Format kernel partition
    format_cmd = "mkfs.vfat -F16" + " " + args.device + kernel_part
    print("Formatting " + args.device + kernel_part + " to " + "FAT16")
    format_process = subprocess.run(format_cmd,
                                    shell=True,
                                    check=False,
                                    stderr=subprocess.PIPE)
    if format_process.returncode != 0:
        print('!! Error Formatting SD Card !!')
        print(format_process.stderr.decode())
        sys.exit(1)

    # Mount the kernel partition
    mount_point = tempfile.mkdtemp(prefix="polarfire-sd-")

    mount_cmd = "mount" + " " + args.device + kernel_part + " " + mount_point
    print("Mounting " + args.device + kernel_part + " to " + mount_point)
    mount_process = subprocess.run(mount_cmd,
                                   shell=True,
                                   check=False,
                                   stderr=subprocess.PIPE)
    if mount_process.returncode !=0:
        print('!! Error Mounting SD Card Partition !!')
        print(mount_process.stderr.decode())
        sys.exit(1)

    # Copy images to kernel partition

    files_to_copy = [f for f in os.listdir(images_dir) if 'payload.bin' not in f]

    for f in files_to_copy:
        src_f = os.path.join(images_dir, f)
        dst_f = os.path.join(mount_point, f)
        copy_cmd = 'cp {} {}'.format(src_f, dst_f)
        copy_process = subprocess.run(copy_cmd,
                                      shell=True,
                                      check=False,
                                      stderr=subprocess.PIPE)
        if copy_process.returncode != 0:
            print('!! Error Copying {} !!'.format(src_f))
            print(copy_process.stderr.decode())
            sys.exit(1)

    # Unmount the partition
    umount_cmd = "umount" + " " + mount_point
    print("Unmounting " + mount_point)
    umount_process = subprocess.run(umount_cmd,
                                    shell=True,
                                    check=False,
                                    stderr=subprocess.PIPE)
    if umount_process.returncode != 0:
        print('!! Error unmounting SD Card partition !!')
        print(umount_process.stderr.decode())
        sys.exit(1)

    print("Deleting " + mount_point)
    os.rmdir(mount_point)

    print("Success!")

if __name__ == "__main__":
    main()
