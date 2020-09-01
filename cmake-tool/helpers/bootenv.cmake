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

config_string(HssPath HSS_PATH
    "Hart Software Services project location"
    DEFAULT ${project_dir}/tools/hart-software-services
)

config_string(U54-1EntryPoint B2C_U54_1_ENTRY_POINT
    "Entry point address for U54 1 used in bin2chunks tool"
    DEFAULT 0x80200000
    DEPENDS "HssPath"
)

config_string(U54-2EntryPoint B2C_U54_2_ENTRY_POINT
    "Entry point address for U54 2 used in bin2chunks tool"
    DEFAULT 0x80200000
    DEPENDS "HssPath"
)

config_string(U54-3EntryPoint U54_3_ENTRY_POINT
    "Entry point address for U54 3 used in bin2chunks tool"
    DEFAULT 0x80200000
    DEPENDS "HssPath"
)

config_string(U54-4EntryPoint U54_4_ENTRY_POINT
    "Entry point address for U54 4 used in bin2chunks tool"
    DEFAULT 0x80200000
    DEPENDS "HssPath"
)

config_string(B2cChunkSize B2C_CHUNK_SIZE
    "Specify bin2chunks tool chunk size"
    DEFAULT 32768
    DEPENDS "HssPath"
)

config_string(B2cOwnerHart B2C_OWNER_HART
    "Specify the owner hart used in bin2chunks tool"
    DEFAULT 1
    DEPENDS "HssPath"
)

config_string(B2cOwnerHartPrivMode B2C_OWNER_HART_PRIV_MODE
    "Specify the owner hart's privilege mode used in bin2chunks tool (0 - User, 1 - Supervisor)"
    DEFAULT 1
    DEPENDS "HssPath"
)

config_string(B2cOwnerHartPayload B2C_OWNER_HART_PAYLOAD
    "Specify the owner hart's binary payload used in bin2chunks tool"
    DEFAULT ${CMAKE_BINARY_DIR}/u-boot/u-boot.bin
    DEPENDS "HssPath"
)

config_string(B2cOwnerHartExecAddr B2C_OWNER_HART_EXEC_ADDR
    "Specify the owner hart's execution address"
    DEFAULT 0x80200000
    DEPENDS "HssPath"
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

    if(${env_string} MATCHES ".*hss*")
        # Build bin2chunks tool
        add_custom_command(
            OUTPUT "${CMAKE_BINARY_DIR}/hart-software-services/bin2chunks"
            COMMAND cd ${HssPath}
            COMMAND make -C ${HssPath}/tools/bin2chunks
            COMMAND cp ${HssPath}/tools/bin2chunks/bin2chunks ${CMAKE_BINARY_DIR}/hart-software-services
            COMMAND make -C ${HssPath}/tools/bin2chunks clean
        )

        # Build payload.bin
        add_custom_command(
            OUTPUT "${CMAKE_BINARY_DIR}/hart-software-services/payload.bin"
            COMMAND cd ${CMAKE_BINARY_DIR}/hart-software-services
            COMMAND ./bin2chunks ${U54-1EntryPoint} ${U54-2EntryPoint} ${U54-3EntryPoint} ${U54-4EntryPoint} ${B2cChunkSize} ./payload.bin ${B2cOwnerHart} ${B2cOwnerHartPrivMode} ${B2cOwnerHartPayload} ${B2cOwnerHartExecAddr}
            COMMAND mkdir -p ${CMAKE_BINARY_DIR}/images &&
                    cp ${CMAKE_BINARY_DIR}/hart-software-services/payload.bin ${CMAKE_BINARY_DIR}/images
            DEPENDS ${CMAKE_BINARY_DIR}/hart-software-services/bin2chunks ${B2cOwnerHartPayload}
        )
        list(APPEND boot_files "${CMAKE_BINARY_DIR}/hart-software-services/payload.bin")

        # Build HSS
        add_custom_command(
            OUTPUT "${CMAKE_BINARY_DIR}/hart-software-services/hss.bin"
            COMMAND mkdir -p ${CMAKE_BINARY_DIR}/hart-software-services
            COMMAND cd ${HssPath} && ./thirdparty/helper_scripts/do_build
                --out-dir ${CMAKE_BINARY_DIR}/hart-software-services
                --cross-compiler ${CROSS_COMPILER_PREFIX}
            COMMAND find . -name '*.o' -exec cp --parents '{}' ${CMAKE_BINARY_DIR}/hart-software-services \\\;
            COMMAND cp *.bin *.elf *.hex *.sym ${CMAKE_BINARY_DIR}/hart-software-services
            COMMAND make BOARD=icicle-kit-es clean
            COMMAND mkdir -p ${CMAKE_BINARY_DIR}/images &&
                    cp ${CMAKE_BINARY_DIR}/hart-software-services/hss.bin ${CMAKE_BINARY_DIR}/images
            DEPENDS ${CMAKE_BINARY_DIR}/hart-software-services/payload.bin
        )
        list(APPEND boot_files "${CMAKE_BINARY_DIR}/hart-software-services/hss.bin")
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
