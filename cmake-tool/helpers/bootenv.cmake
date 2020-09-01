#
# Copyright 2020, Data61, CSIRO (ABN 41 687 119 230)
# Copyright 2020, DornerWorks Ltd.
#
# SPDX-License-Identifier: BSD-2-Clause
#

set(configure_string "")

config_string(UbootPath UBOOT_PATH
    "U-Boot project location"
    DEFAULT ${project_dir}/tools/u-boot
)

config_string(UbootDefconfig UBOOT_DEFCONFIG
    "Specify the defconfig to use while building u-boot"
    DEFAULT "microchip_mpfs_icicle_defconfig"
    DEPENDS "UbootPath"
)

config_string(UbootKernelLoadAddr UBOOT_KERNEL_LOAD_ADDR
    "Specify the address where U-Boot loads the kernel image "
    DEFAULT "0x80000000"
    DEPENDS "UbootPath"
)


add_config_library(BootEnv "${configure_string}")


# This function allows the user to specify the bootloaders to build
# to achieve their desired boot sequence. This is done by adding the
# name of the desired bootloader to the boot environment string. This
# function then looks for the occurance of the specified bootloaders
# in the environment string and executes the build procedure if one
# found.
#
# To extend this functionality for additional bootloaders add an if
# statement with the specified bootloader name like so
#   if(${env_string} MATCHES ".*<name of bootloader>*")
#       # add boot procedure here
#       list(APPEND boot_files "${CMAKE_BINARY_DIR}/<bootloader_name>/<bootloader_image>")
#       set(boot_files ${boot_files} PARENT_SCOPE)
#   endif()
function(ConfigureBootEnv env_string)
    message("Configuring boot for ${env_string}")

    if(${env_string} MATCHES ".*u-boot*")
        if(("${PLATFORM}" STREQUAL "polarfire") OR ("${PLATFORM}" STREQUAL "hifive"))
            set(UbootArch "riscv")
        endif()

        set(UbootBootCmd "CONFIG_BOOTCOMMAND=\"")
        string(APPEND UbootBootCmd "setenv fileaddr 0x90000000\\\; ")
        string(APPEND UbootBootCmd "fatload mmc 0:2 $$\{fileaddr} uEnv.txt\\\; env import -t $$\{fileaddr} $$\{filesize}\\\; ")
        string(APPEND UbootBootCmd "run boot3")
        string(APPEND UbootBootCmd "\"")
        string(REGEX REPLACE "([][+.'*()^])" "\\\\\\1" UbootBootCmd ${UbootBootCmd})

        add_custom_command(
            OUTPUT "${CMAKE_BINARY_DIR}/u-boot/uEnv.txt"
            COMMAND mkdir -p ${CMAKE_BINARY_DIR}/u-boot && cd ${CMAKE_BINARY_DIR}/u-boot
            COMMAND touch uEnv.txt
            COMMAND echo \"boot3=fatload mmc 0:2 ${UbootKernelLoadAddr} ${rootservername}-image-${KernelArch}-${KernelPlatform}\\; go ${UbootKernelLoadAddr}\" >> uEnv.txt
        )

        add_custom_command(
            OUTPUT "${CMAKE_BINARY_DIR}/u-boot/u-boot.bin"
            COMMAND mkdir -p ${CMAKE_BINARY_DIR}/u-boot
            COMMAND cd ${UbootPath} && make O=${CMAKE_BINARY_DIR}/u-boot mrproper
            COMMAND make O=${CMAKE_BINARY_DIR}/u-boot ARCH=${UbootArch} ${UbootDefconfig}
            COMMAND sed -i 's/^CONFIG_BOOTCOMMAND.*/${UbootBootCmd}/' ${CMAKE_BINARY_DIR}/u-boot/.config
            COMMAND make O=${CMAKE_BINARY_DIR}/u-boot ARCH=${UbootArch} CROSS_COMPILE=${CROSS_COMPILER_PREFIX}
            COMMAND mkdir -p ${CMAKE_BINARY_DIR}/images &&
                    cp ${CMAKE_BINARY_DIR}/u-boot/u-boot.bin ${CMAKE_BINARY_DIR}/u-boot/uEnv.txt ${CMAKE_BINARY_DIR}/images
            DEPENDS ${CMAKE_BINARY_DIR}/u-boot/uEnv.txt
        )
        list(APPEND boot_files "${CMAKE_BINARY_DIR}/u-boot/u-boot.bin")
        set(boot_files ${boot_files} PARENT_SCOPE)
    endif()

    if(${env_string} MATCHES ".*bbl*")
        set(BBL_PATH ${CMAKE_SOURCE_DIR}/tools/riscv-pk CACHE STRING "BBL Folder location")
        mark_as_advanced(FORCE BBL_PATH)

        # Package up our final elf image into the Berkeley boot loader.
        # The host string is extracted from the cross compiler setting
        # minus the trailing '-'
        if("${CROSS_COMPILER_PREFIX}" STREQUAL "")
            message(FATAL_ERROR "CROSS_COMPILER_PREFIX not set.")
        endif()

        string(
            REGEX
            REPLACE
                "^(.*)-$"
                "\\1"
                host
                "${CROSS_COMPILER_PREFIX}"
        )
        get_filename_component(host ${host} NAME)
        file(GLOB_RECURSE deps)
        add_custom_command(
            OUTPUT "${CMAKE_BINARY_DIR}/bbl/bbl"
            COMMAND mkdir -p ${CMAKE_BINARY_DIR}/bbl
            COMMAND
                cd ${CMAKE_BINARY_DIR}/bbl && ${BBL_PATH}/configure
                --quiet
                --host=${host}
                --with-arch=${march}
                --with-payload=${elf_target_file}
                    && make -s clean && make -s > /dev/null
            DEPENDS ${elf_target_file} elfloader ${USES_TERMINAL_DEBUG}
        )
        set(elf_target_file "${CMAKE_BINARY_DIR}/bbl/bbl" PARENT_SCOPE)
    endif()
endfunction(ConfigureBootEnv)
