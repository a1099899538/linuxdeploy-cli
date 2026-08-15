#!/bin/sh
# Linux Deploy Component
# (c) Anton Skshidlevsky <meefik@gmail.com>, GPLv3

do_install()
{
    msg ":: Installing ${COMPONENT} ... "
    local packages=""
    case "${DISTRIB}:${ARCH}:${SUITE}" in
    debian:*|ubuntu:*|kali:*)
        packages="desktop-base dbus-x11 x11-xserver-utils xfonts-base xfonts-utils xfonts-75dpi xfonts-100dpi xfce4 xfce4-terminal tango-icon-theme hicolor-icon-theme pm-utils fonts-dejavu-core fonts-wqy-microhei tigervnc-tools eog gvfs"
        apt_install ${packages}
    ;;
    archlinux:*)
        packages="xorg-xauth xorg-fonts-misc ttf-dejavu xfce4"
        pacman_install ${packages}
    ;;
    fedora:*)
        packages="xorg-x11-server-utils xorg-x11-fonts-misc dejavu-* @xfce-desktop-environment"
        dnf_install ${packages}
    ;;
    esac
}

do_configure()
{
    msg ":: Configuring ${COMPONENT} ... "
    local xsession="${CHROOT_DIR}$(user_home ${USER_NAME})/.xsession"
    # xfce4-session cannot spawn children on some Android kernels
    # (close_range syscall issue), so launch the desktop components directly.
    cat > "${xsession}" << 'EOF'
exec dbus-launch --exit-with-session sh -c 'xfsettingsd & xfce4-panel & xfdesktop & xfwm4'
EOF
    return 0
}
