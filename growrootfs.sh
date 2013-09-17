#!/bin/sh

# Environment variables that this script relies upon:
# - NEWROOT

. /lib/dracut-lib.sh

_info() {
	echo "growrootfs: $*"
}

_warning() {
	echo "growrootfs Warning: $*" >&2
}

# This will drop us into an emergency shell
_fatal() {
	echo "growrootfs Fatal: $*" >&2
	exit 1
}

# This runs right before exec of /sbin/init, the real root is already mounted
# at NEWROOT
_growrootfs()
{
	local out rootdev rootmnt rootfs opts unused rootdisk partnum

	# If a file indicates we should do nothing, then just return
	for file in /var/lib/cloud/instance/rootfs-grown /etc/growrootfs-disabled \
		/etc/growrootfs-grown ; do
		if [ -f "${NEWROOT}${file}" ] ; then
			_info "${file} exists, nothing to do"
			return
		fi
	done

	# Get the root device, root filesystem and mount options
	if ! out=$(awk '$2 == mt { print }' "mt=${NEWROOT}" < /proc/mounts) ; then
	_warning "${out}"
	return
	fi

	# Need to do it this way, can't use '<<< "${out}"' since RHEL6 doesn't
	# seem to understand it
	read rootdev rootmnt rootfs opts unused <<EOF
${out}
EOF
	if [ -z "{rootdev}" -o -z "${rootmnt}" -o -z "${rootfs}" -o \
		-z "${opts}" ] ; then
	_warning "${out}"
	return
	fi

	# There's something to do so unmount and grow.
	if ! umount "${NEWROOT}" ; then
		_warning "Failed to umount ${NEWROOT}"
		return
	fi

	e2fsck -f "${rootdev}"
	resize2fs "${rootdev}"

	# Remount the root filesystem
	mount -t "${rootfs}" -o "${opts}" "${rootdev}" "${NEWROOT}" || \
		_fatal "Failed to re-mount ${rootdev}, this is bad"

	# Write to /etc/growroot-grown, most likely this wont work (read-only)
	{
		date --utc > "${NEWROOT}/etc/growrootfs-grown"
	} >/dev/null 2>&1
}

_growrootfs

# vi: ts=4 noexpandtab
