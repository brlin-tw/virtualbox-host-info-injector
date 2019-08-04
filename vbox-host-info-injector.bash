#!/usr/bin/env bash
# Emulate host machine by injecting host machine's information to a VirtualBox VM
# 林博仁 <Buo.Ren.Lin@gmail.com> © 2019

## Makes debuggers' life easier - Unofficial Bash Strict Mode
## BASHDOC: Shell Builtin Commands - Modifying Shell Behavior - The Set Builtin
set \
    -o errexit \
    -o errtrace \
    -o nounset \
    -o pipefail

## Runtime Dependencies Checking
declare\
    runtime_dependency_checking_result=still-pass \
    required_software

for required_command in \
    awk \
    basename \
    cut \
    dirname \
    dmidecode \
    realpath \
    VBoxManage; do
    if ! command -v "${required_command}" &>/dev/null; then
        runtime_dependency_checking_result=fail

        case "${required_command}" in
            awk)
                required_software='Gawk'
            ;;
            basename \
            |cut \
            |dirname \
            |realpath)
                required_software='GNU Coreutils'
            ;;
            dmidecode)
                required_software='Dmidecode'
            ;;
            VBoxManage)
                required_software='Oracle VirtualBox'
            ;;
            *)
                required_software="${required_command}"
            ;;
        esac

        printf -- \
            'Error: This program requires "%s" to be installed and its executables in the executable searching PATHs.\n' \
            "${required_software}" \
            1>&2
        unset required_software
    fi
done; unset required_command required_software

if [ "${runtime_dependency_checking_result}" = fail ]; then
    printf -- \
        'Error: Runtime dependency checking failed.\n' \
        1>&2
    exit 1
fi; unset runtime_dependency_checking_result

## init function: entrypoint of main program
## This function is called near the end of the file
## with the script's command-line parameters as arguments
init(){
    local \
        vm_name \
        firmware_type
    
    if ! process_commandline_arguments \
            vm_name \
            "${@}"; then
        printf -- \
            'Error: Invalid command-line arguments\n' \
            1>&2

        printf '\n' # separate error message and help message
        print_help
        exit 1
    fi

    if ! test -v vm_name; then
        print_help
        exit 0
    fi

    local firmware_type_detected
    firmware_type_detected="$(
        VBoxManage showvminfo \
            --machinereadable \
            "${vm_name}" \
            | grep ^firmware= \
            | cut \
                --delimiter='"' \
                --fields=2
    )"

    case "${firmware_type_detected}" in
        BIOS)
            firmware_type=bios
        ;;
        EFI)
            firmware_type=uefi
        ;;
        *)
            printf -- \
                'Error: Unsupported firmware type %s.\n' \
                "${firmware_type_detected}" \
                1>&2
            exit 1
        ;;
    esac

    fetch_and_inject_data_to_vm \
        "${firmware_type}"

    exit 0
}; declare -fr init

fetch_and_inject_data_to_vm(){
    local firmware_type="${1}"

    local vbox_firmware_type

    case "${firmware_type}" in
        bios)
            vbox_firmware_type=pcbios
        ;;
        uefi)
            vbox_firmware_type=efi
        ;;
        *)
            printf -- \
                '%s: Error: Unsupported firmware type: %s' \
                "${FUNCNAME[0]}" \
                "${firmware_type}" \
                1>&2
            return 1
        ;;
    esac

    # Allow locale modification only in the sub-shell environment
    (
        # Hardcode locale to make output parsing more reliable
        LANGUAGE=en
        LC_MESSAGES=C
        LANG=C
        export LANGUAGE LC_MESSAGES LANG

        # DMI BIOS information (type 0) 
        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiBIOSVendor \
            "$(sudo dmidecode --string bios-vendor)"

        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiBIOSVersion \
            "$(sudo dmidecode --string bios-version)"

        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiBIOSReleaseDate \
            "$(sudo dmidecode --string bios-release-date)"

        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiBIOSReleaseMajor \
            "$(
                sudo dmidecode \
                    --type 0 \
                | awk \
                    '/BIOS Revision:/ {print $NF}' \
                | cut \
                    --delimiter=. \
                    --fields=1
            )"

        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiBIOSReleaseMinor \
            "$(
                sudo dmidecode \
                    --type 0 \
                | awk \
                    '/BIOS Revision:/ {print $NF}' \
                | cut \
                    --delimiter=. \
                    --fields=2
            )"

        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiBIOSFirmwareMajor \
            "$(
                sudo dmidecode \
                    --type 0 \
                | awk \
                    '/Firmware Revision:/ {print $NF}' \
                | cut \
                    --delimiter=. \
                    --fields=1
            )"

        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiBIOSFirmwareMinor \
            "$(
                sudo dmidecode \
                    --type 0 \
                | awk \
                    '/Firmware Revision:/ {print $NF}' \
                | cut \
                    --delimiter=. \
                    --fields=2
            )"

        # DMI system information (type 1)
        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiSystemVendor \
            "$(sudo dmidecode --string system-manufacturer)"
        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiSystemProduct \
            "$(sudo dmidecode --string system-product-name)"
        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiSystemVersion \
            "$(sudo dmidecode --string system-version)"
        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiSystemSerial \
            "$(sudo dmidecode --string system-serial-number)"
        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiSystemSKU \
            "$(
                sudo dmidecode \
                    --type 1 \
                | grep \
                    --fixed-strings \
                    'SKU Number: ' \
                | cut \
                    --delimiter=: \
                    --fields=2 \
                | sed \
                    's/^ //'
            )"
        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiSystemFamily \
            "$(
                sudo dmidecode \
                    --type 1 \
                | grep \
                    --fixed-strings \
                    'Family: ' \
                | cut \
                    --delimiter=: \
                    --fields=2 \
                | sed \
                    's/^ //'
            )"
        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiSystemUuid \
            "$(sudo dmidecode --string system-uuid)"

        # DMI board information (type 2)
        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiBoardVendor \
            "$(sudo dmidecode --string baseboard-manufacturer)"
        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiBoardProduct \
            "$(sudo dmidecode --string baseboard-product-name)"
        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiBoardVersion \
            "$(sudo dmidecode --string baseboard-version)"
        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiBoardSerial \
            "$(sudo dmidecode --string baseboard-serial-number)"
        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiBoardAssetTag \
            "$(sudo dmidecode --string baseboard-asset-tag)"
        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiBoardLocInChass \
            "$(
                sudo dmidecode \
                    --type 2 \
                | grep \
                    --fixed-strings \
                    'Location In Chassis: ' \
                | cut \
                    --delimiter=: \
                    --fields=2 \
                | sed \
                    's/^ //'
            )"
        local -A map_baseboard_type_to_code=()
        local baseboard_type
        # Code starts from 1
        local -i i=1
        # Stealed from dmidecode 3.1
        for baseboard_type in \
            "Unknown" \
            "Other" \
            "Server Blade" \
            "Connectivity Switch" \
            "System Management Module" \
            "Processor Module" \
            "I/O Module" \
            "Memory Module" \
            "Daughter Board" \
            "Motherboard" \
            "Processor+Memory Module" \
            "Processor+I/O Module" \
            "Interconnect Board"; do
            map_baseboard_type_to_code["${baseboard_type}"]="${i}"
            (( i += 1 ))
        done
        unset \
            baseboard_type \
            i
        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiBoardBoardType \
            "${map_baseboard_type_to_code["$(
                sudo dmidecode \
                    --type 2 \
                    | grep \
                        --fixed-strings \
                        'Type: ' \
                    | cut \
                        --delimiter=: \
                        --fields=2 \
                    | sed \
                        's/^ //'
            )"]}"
        unset map_baseboard_type_to_code

        # DMI system enclosure or chassis (type 3) 
        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiChassisVendor \
            "$(sudo dmidecode --string chassis-manufacturer)"
        local -A map_chassis_type_to_code=()
        local chassis_type
        # Code starts from 1
        local -i i=1
        # Stealed from dmidecode 3.1
        for chassis_type in \
            "Other" \
            "Unknown" \
            "Desktop" \
            "Low Profile Desktop" \
            "Pizza Box" \
            "Mini Tower" \
            "Tower" \
            "Portable" \
            "Laptop" \
            "Notebook" \
            "Hand Held" \
            "Docking Station" \
            "All In One" \
            "Sub Notebook" \
            "Space-saving" \
            "Lunch Box" \
            "Main Server Chassis" \
            "Expansion Chassis" \
            "Sub Chassis" \
            "Bus Expansion Chassis" \
            "Peripheral Chassis" \
            "RAID Chassis" \
            "Rack Mount Chassis" \
            "Sealed-case PC" \
            "Multi-system" \
            "CompactPCI" \
            "AdvancedTCA" \
            "Blade" \
            "Blade Enclosing" \
            "Tablet" \
            "Convertible" \
            "Detachable" \
            "IoT Gateway" \
            "Embedded PC" \
            "Mini PC" \
            "Stick PC"; do
            map_chassis_type_to_code["${chassis_type}"]="${i}"
            (( i += 1 ))
        done
        unset \
            chassis_type \
            i
        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiChassisType \
            "${map_chassis_type_to_code["$(sudo dmidecode --string chassis-type)"]}"
        unset map_chassis_type_to_code
        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiChassisVersion \
            "$(sudo dmidecode --string chassis-version)"
        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiChassisSerial \
            "$(sudo dmidecode --string chassis-serial-number)"
        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiChassisAssetTag \
            "$(sudo dmidecode --string chassis-asset-tag)"

        # DMI processor information (type 4)
        # (May not be neccessary as host CPU information is available in guest
        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiProcManufacturer \
            "$(sudo dmidecode --string processor-manufacturer)"
        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiProcVersion \
            "$(sudo dmidecode --string processor-version)"

        # DMI OEM strings (type 11)
        # Junk default VirtualBox OEM strings
        # FIXME: No way to emulate these... \
        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiOEMVBoxVer \
            'OEM String'
        VBoxManage setextradata \
            "${vm_name}" \
            VBoxInternal/Devices/"${vbox_firmware_type}"/0/Config/DmiOEMVBoxRev \
            'OEM String'
    )
}

print_help(){
    # Backticks in help message is Markdown's <code> markup
    # shellcheck disable=SC2016
    {
        printf '# Help Information for %s #\n' \
            "${RUNTIME_COMMANDLINE_BASECOMMAND}"
        printf '## SYNOPSIS ##\n'
        printf '* `"%s" _command-line_options_ _vm_name_`\n\n' \
            "${RUNTIME_COMMANDLINE_BASECOMMAND}"

        printf '## COMMAND-LINE OPTIONS ##\n'
        printf '### `-d` / `--debug` ###\n'
        printf 'Enable script debugging\n\n'

        printf '### `-h` / `--help` ###\n'
        printf 'Print this message\n\n'
    }
    return 0
}; declare -fr print_help;

process_commandline_arguments() {
    local -n vm_name_ref="${1}"; shift 1

    # Modifyable parameters for parsing by consuming
    local -a parameters=("${@}")

    if [ "${#parameters[@]}" -eq 0 ]; then
        return 0
    fi

    # Normally we won't want debug traces to appear during parameter parsing \
    local enable_debug=false

    local flag_vm_name_specified=false

    while true; do
        if [ "${#parameters[@]}" -eq 0 ]; then
            break
        else
            case "${parameters[0]}" in
                --debug \
                |-d)
                    enable_debug=true
                ;;
                --help \
                |-h)
                    print_help
                    exit 0
                ;;
                *)
                    if test "${flag_vm_name_specified}" = true; then
                        printf -- \
                            '%s: Error: This program only accepts one non-option argument.\n' \
                            "${FUNCNAME[0]}" \
                            1>&2
                        return 1
                    fi
                    # name references are use indirectly
                    # shellcheck disable=SC2034
                    vm_name_ref="${parameters[0]}"
                    flag_vm_name_specified=true
                ;;
            esac
            shift_array parameters 1
        fi
    done

    if [ "${enable_debug}" = true ]; then
        trap 'trap_return "${FUNCNAME[0]}"' RETURN
        set -o xtrace
    fi
    return 0
}; declare -fr process_commandline_arguments

shift_array(){
    local -n array="${1}"; shift 1
    local -i times=1
    if test $# -eq 2; then
        times="${1}"; shift 1
    fi

    local -i i=0

    while test "${i}" -ne "${times}"; do
        unset 'array[0]'
        if test "${#array[@]}" -ne 0; then
            array=("${array[@]}")
        fi
        (( i += 1 ))
    done
}

## Traps: Functions that are triggered when certain condition occurred
## Shell Builtin Commands » Bourne Shell Builtins » trap
trap_errexit(){
    printf \
        'An error occurred and the script is prematurely aborted\n' \
        1>&2
    return 0
}; declare -fr trap_errexit; trap trap_errexit ERR

trap_exit(){
    return 0
}; declare -fr trap_exit; trap trap_exit EXIT

trap_return(){
    local returning_function="${1}"

    printf \
        'DEBUG: %s: returning from %s\n' \
        "${FUNCNAME[0]}" \
        "${returning_function}" \
        1>&2
}; declare -fr trap_return

trap_interrupt(){
    printf '\n' # Separate previous output
    printf \
        'Recieved SIGINT, the script is interrupted\n' \
        1>&2
    return 1
}; declare -fr trap_interrupt; trap trap_interrupt INT

if test "${#}" -eq 0; then
    init
else
    init "${@}"
fi
