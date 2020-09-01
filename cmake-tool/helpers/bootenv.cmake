#
# Copyright 2020, Data61, CSIRO (ABN 41 687 119 230)
# Copyright 2020, DornerWorks Ltd.
#
# SPDX-License-Identifier: BSD-2-Clause
#

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
#   endif()
function(ConfigureBootEnv env_string)
    message("Configuring boot for ${env_string}")
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
