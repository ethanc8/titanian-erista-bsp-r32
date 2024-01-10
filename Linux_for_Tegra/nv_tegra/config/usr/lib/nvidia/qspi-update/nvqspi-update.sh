#!/bin/bash

# Copyright (c) 2020, NVIDIA CORPORATION. All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

# This is a script to update MinSPI to MaxSPI.
# This will remove un-used partitions on SD card after update.

set -e

function usage()
{
	if [ -n "${1}" ]; then
		echo "${1}"
	fi

	echo "Usage:"
	echo "${script_name} [options]"
	echo ""
	echo "Available options are:"
	echo ""
	echo "  -h | --help"
	echo "          Show this usage"
	echo ""
	echo "  -c | --check"
	echo "          Check whether ${script_name} can be used on current platform"
	echo ""
	echo "  -u | --update"
	echo "          Update MinSPI to MaxSPI"
	echo ""
	echo "Example:"
	echo "${script_name} -u"
}

function version_lt() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" != "$1"; }

function check()
{
	support_update="false"

	CHIP="$(tr -d '\0' < /proc/device-tree/compatible)"
	BOOT_DEVICE="$(tr -d '\0' < /etc/nv_boot_control.conf)"
	if [[ "${CHIP}" =~ "tegra210" ]] && [[ "${BOOT_DEVICE}" =~ "mtdblock0" ]]; then
		if [ -e "${payload_updater_script}" ] && [ -e "${bootloader_config_script}" ]; then
			"${bootloader_config_script}" -c > "/dev/null" 2>&1
			VERINFO="$(${payload_updater_script} -v)"
			if [[ "${VERINFO}" =~ "NV1" ]]; then
				support_update="true"
			elif [[ "${VERINFO}" =~ "R32" ]]; then
				revision="$(echo "${VERINFO}" | grep "R32" | sed -n 's/.*'REVISION:\ '//p')"
				if version_lt "${revision}" "5.0"; then
					support_update="true"
				fi
			fi
		else
			echo "${script_name}: ERROR: Could not find script file." 1>&2
		fi
	fi

	if [ "${support_update}" = "false" ]; then
		echo "${script_name}: nvqspi_update doesn't support this platform." 1>&2
	fi

	echo "${support_update}"
}

function remove_unused_partitions()
{
	root_dev="$(sed -ne 's/.*\broot=\([^ ]*\)\b.*/\1/p' < /proc/cmdline)"

	if [[ "${root_dev}" == *UUID* ]]; then
		root_dev="$(/sbin/findfs ${root_dev})"
	fi

	if [[ "${root_dev}" == /dev/mmcblk* ]] || [[ "${root_dev}" == /dev/sd* ]]; then
		block_dev="$(/bin/lsblk -no pkname ${root_dev})"
		if [ "${block_dev}" != "" ]; then
			part_list="$(sgdisk -p /dev/${block_dev} | sed '1,10d')"
			while IFS= read -r line; do
				part_num=$(echo ${line} | awk '{print $1}')
				part_name=$(echo ${line} | awk '{print $7}')

				if [[ "${unused_partitions}" =~ ${part_name} ]]; then
					sgdisk -d "${part_num}" "/dev/${block_dev}"
				fi
			done < <(printf '%s\n' "${part_list}")
		fi
	fi
}

function update()
{
	if [ ! -e "${payload_updater_script}" ]; then
		echo "${script_name}: ERROR: Could not find QSPI updater."
		return 1;
	fi

	if [ ! -e "${bl_update_payload_file}" ]; then
		echo "${script_name}: ERROR: Could not find bootloader payload"
		return 1;
	fi

	if ! ${payload_updater_script} "${bl_update_payload_file}"; then
		echo "${script_name}: ERROR: Failed to update booloader in QSPI."
		return 1;
	fi

	remove_unused_partitions

	if [ ! -e "${xusb_update_payload_file}" ]; then
		echo "${script_name}: ERROR: Could not find xusb payload"
		return 1;
	fi

	if ! ${payload_updater_script} "${xusb_update_payload_file}"; then
		echo "${script_name}: ERROR: Failed to update xusb in QSPI."
		return 1;
	fi

	return 0
}

function parse_args()
{
	while [ -n "${1}" ]; do
		case "${1}" in
		-h | --help)
			usage
			exit 0
			;;
		-c | --check)
			check
			exit 0
			;;
		-u | --update)
			update
			exit 0
			;;
		*)
			usage "Unknown option: ${1}"
			exit 1
		;;
		esac
	done
}

payload_updater_script="/usr/sbin/l4t_payload_updater_t210"
bl_update_payload_file="/opt/ota_package/t21x/bl_update_payload"
xusb_update_payload_file="/opt/ota_package/t21x/xusb_only_payload"
bootloader_config_script="/opt/nvidia/l4t-bootloader-config/nv-l4t-bootloader-config.sh"
unused_partitions="TBC RP1 EBT WB0 BPF BPF-DTB FX TOS DTB LNX EKS BMP RP4"
script_name="$(basename "${0}")"
parse_args "${@}"
