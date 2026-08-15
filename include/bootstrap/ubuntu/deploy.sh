#!/bin/sh
# Linux Deploy Component
# (c) Anton Skshidlevsky <meefik@gmail.com>, GPLv3

[ -n "${SUITE}" ] || SUITE="resolute"

if [ -z "${ARCH}" ]
then
    case "$(get_platform)" in
    x86) ARCH="i386" ;;
    x86_64) ARCH="amd64" ;;
    arm) ARCH="armhf" ;;
    arm_64) ARCH="arm64" ;;
    esac
fi

if [ -z "${SOURCE_PATH}" ]
then
    case "$(get_platform ${ARCH})" in
    x86*) SOURCE_PATH="http://archive.ubuntu.com/ubuntu/" ;;
    arm*) SOURCE_PATH="http://ports.ubuntu.com/" ;;
    esac
fi

ubuntu_base_url()
{
    # Official Ubuntu base rootfs tarball (https://cdimage.ubuntu.com/ubuntu-base/)
    local base_url="http://cdimage.ubuntu.com/ubuntu-base/releases/${SUITE}/release/"
    local tarball=$(wget -q -O - "${base_url}" | grep -oE 'ubuntu-base-[0-9.]+-base-'"${ARCH}"'\.tar\.gz' | sort -ru | head -n1)
    if [ -z "${tarball}" ]; then
        # fallback for known releases
        case "${SUITE}" in
        resolute) tarball="ubuntu-base-26.04-base-${ARCH}.tar.gz" ;;
        noble) tarball="ubuntu-base-24.04.4-base-${ARCH}.tar.gz" ;;
        jammy) tarball="ubuntu-base-22.04.5-base-${ARCH}.tar.gz" ;;
        bionic) tarball="ubuntu-base-18.04.5-base-${ARCH}.tar.gz" ;;
        esac
    fi
    echo "${base_url}${tarball}"
}

apt_repository()
{
    # Backup sources.list
    if [ -e "${CHROOT_DIR}/etc/apt/sources.list" ]; then
        cp "${CHROOT_DIR}/etc/apt/sources.list" "${CHROOT_DIR}/etc/apt/sources.list.bak"
    fi
    # Disable deb822 sources shipped in ubuntu-base rootfs
    if [ -e "${CHROOT_DIR}/etc/apt/sources.list.d/ubuntu.sources" ]; then
        mv "${CHROOT_DIR}/etc/apt/sources.list.d/ubuntu.sources" "${CHROOT_DIR}/etc/apt/sources.list.d/ubuntu.sources.bak"
    fi
    # Fix for resolv problem in xenial
    echo 'Debug::NoDropPrivs true;' > "${CHROOT_DIR}/etc/apt/apt.conf.d/00no-drop-privs"
    # Fix for seccomp policy
    echo 'apt::sandbox::seccomp "false";' > "${CHROOT_DIR}/etc/apt/apt.conf.d/999seccomp-off"
    # Update sources.list
    echo "deb ${SOURCE_PATH} ${SUITE} main universe multiverse" > "${CHROOT_DIR}/etc/apt/sources.list"
    echo "deb ${SOURCE_PATH} ${SUITE}-updates main universe multiverse" >> "${CHROOT_DIR}/etc/apt/sources.list"
    echo "deb ${SOURCE_PATH} ${SUITE}-security main universe multiverse" >> "${CHROOT_DIR}/etc/apt/sources.list"
    echo "deb-src ${SOURCE_PATH} ${SUITE} main universe multiverse" >> "${CHROOT_DIR}/etc/apt/sources.list"
    # Fix for upstart
    if [ -e "${CHROOT_DIR}/sbin/initctl" ]; then
        chroot_exec -u root dpkg-divert --local --rename --add /sbin/initctl
        ln -s /bin/true "${CHROOT_DIR}/sbin/initctl"
    fi
}

do_install()
{
    is_archive "${SOURCE_PATH}" && return 0

    msg ":: Installing ${COMPONENT} ... "

    # Use official ubuntu-base rootfs tarball instead of debootstrap,
    # since new releases have zstd-compressed packages.
    msg -n "Resolving rootfs archive ... "
    local rootfs_url=$(ubuntu_base_url)
    if [ -z "${rootfs_url}" ]; then
        msg "fail"
        msg "Unsupported version or architecture: ${SUITE}/${ARCH}"
        return 1
    fi
    msg "done"

    msg -n "Downloading rootfs archive ... "
    (set -e
        wget -q -O "${TEMP_DIR}/rootfs.tar.gz" "${rootfs_url}" || exit 1
    exit 0)
    is_ok "fail" "done" || return 1

    msg -n "Extracting rootfs archive ... "
    (set -e
        tar xzf "${TEMP_DIR}/rootfs.tar.gz" -C "${CHROOT_DIR}" || exit 1
    exit 0)
    is_ok "fail" "done" || return 1
    rm -f "${TEMP_DIR}/rootfs.tar.gz"

    component_exec core/emulator core/mnt core/net

    msg -n "Updating repository ... "
    apt_repository
    is_ok "fail" "done"

    msg "Installing base packages: "
    apt_install locales sudo man-db
    is_ok || return 1

    if [ -n "${EXTRA_PACKAGES}" ]; then
        msg "Installing extra packages: "
        apt_install ${EXTRA_PACKAGES}
        is_ok || return 1
    fi

    return 0
}

do_help()
{
cat <<EOF
   --arch="${ARCH}"
     Architecture of Linux distribution, supported "armel", "armhf", "arm64", "i386" and "amd64".

   --suite="${SUITE}"
     Version of Linux distribution, supported versions "bionic", "jammy", "noble" and "resolute".

   --source-path="${SOURCE_PATH}"
     Installation source, can specify address of the repository or path to the rootfs archive.

   --extra-packages="${EXTRA_PACKAGES}"
     List of optional installation packages, separated by spaces.

EOF
}
