#!/bin/bash
# empty-device-trash.sh
# this one is the bash shell script counterpart of .desktop Solid action
# of the same name used for developing and testing
# sample usage:
# $ empty-device-trash.sh '/dev/sdd2' '/media/christian/TOSHIBA EXT4'

block_device="$1"
mount_point="$2"
user_id=$UID

typeset -a udisksctl_out
spacer="          "
separator="————————————————————"

function error_exit {
	kdialog --error "$1" 1>/dev/null 2>&1; exit 1
}

# https://www.baeldung.com/linux/decoding-encoded-urls
function decode_url
{
	path="$1"
	(IFS="+"; echo -e ${path//%/\\x}"")
}

function collect_pathes
{
	trash_dir="$1"
	cd "$trash_dir"
	for if in "${trash_dir}"/info/*.trashinfo; do
		orig_path=$(grep '^Path=' "$if")
		orig_path=${orig_path#Path=}
		orig_path=$(decode_url "$orig_path")
 		printf '%s\n' "$orig_path"
	done
}

# by definition in a KDE Solid device action, there will be no mismatch between
# the given device' mountpount and the given mount pount, but might happen on command line
device_mount_point="$(findmnt --noheadings --output TARGET $block_device 2>/dev/null)"
test "$device_mount_point" == "$mount_point"
mount_point_check=$?
test $mount_point_check -eq 0 || error_exit "Device '$block_device' real mount point '$device_mount_point' does not match given mount point '$mount_point'"

# mostly the same is true for the given mount point, that shall be a valid mount point
mountpoint "$mount_point" 1>/dev/null 2>&1
mount_point_check=$?
test $mount_point_check -eq 0 || error_exit "Nothing mounted at given mount point '$mount_point'"

udisksctl_out=($(command udisksctl info --block-device $block_device | grep 'IdLabel:'))
unset udisksctl_out[0]
block_device_label="${udisksctl_out[@]}"

files_count=$(cd "${mount_point}/.Trash-${user_id}/info/"; command ls -1 | command wc -l)
sorry_message="It seems as if there are no files or directories to delete in the Trash on: ${block_device_label}${spacer}"
test $files_count -eq 0 && kdialog --title "No File(s) to Delete" --ok-label "Dismiss" --sorry "$sorry_message" 1>/dev/null 2>&1 && exit 1

warning_message="Delete following $files_count file(s) permanently from trash on: ${block_device_label}?${spacer}\n\n${separator}\n$(collect_pathes "${mount_point}/.Trash-${user_id}")\n${separator}\n\nTHIS ACTION CANNOT BE UNDONE.\n\n"
kdialog --title "Confirm Delete Permanently" --yes-label "Delete Permanently" --no-label "Cancel" --warningyesno "$warning_message" 1>/dev/null 2>&1; kdialog_return_value=$?

test $kdialog_return_value -eq 0 && command rm -rf "${mount_point}/.Trash-${user_id}"/files/* && command rm -rf "${mount_point}/.Trash-${user_id}"/info/*;
