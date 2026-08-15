#!/bin/sh
# Linux Deploy Component
# (c) Anton Skshidlevsky <meefik@gmail.com>, GPLv3

do_install()
{
    msg ":: Installing ${COMPONENT} ... "
    local packages=""
    case "${DISTRIB}:${ARCH}:${SUITE}" in
    debian:*|ubuntu:*|kali:*)
        packages="desktop-base dbus-x11 x11-xserver-utils xfonts-base xfonts-utils xfonts-75dpi xfonts-100dpi lxde lxde-common lxde-icon-theme menu-xdg hicolor-icon-theme gtk2-engines fonts-dejavu-core fonts-wqy-microhei"
        apt_install ${packages}
    ;;
    archlinux:*)
        packages="xorg-xauth xorg-fonts-misc ttf-dejavu lxde gtk-engines"
        pacman_install ${packages}
    ;;
    fedora:*)
        packages="xorg-x11-server-utils xorg-x11-fonts-misc dejavu-* @lxde-desktop-environment"
        dnf_install ${packages}
    ;;
    esac
}

do_configure()
{
    msg ":: Configuring ${COMPONENT} ... "
    local xsession="${CHROOT_DIR}$(user_home ${USER_NAME})/.xsession"
    # lxsession cannot spawn children on some Android kernels
    # (close_range syscall issue), so launch the desktop components directly.
    cat > "${xsession}" << 'EOF'
exec dbus-launch --exit-with-session sh -c 'xsetroot -solid "#3a6ea5"; lxpanel & pcmanfm --desktop & openbox'
EOF
    # Seed default panel configuration; lxpanel fails to generate it
    # on first run with glib >= 2.80 (GFileInfo API hardening)
    local panel_conf="${CHROOT_DIR}$(user_home ${USER_NAME})/.config/lxpanel/LXDE/panels/panel"
    if [ ! -e "${panel_conf}" ]; then
        [ -e "${panel_conf%/*}" ] || mkdir -p "${panel_conf%/*}"
        cat > "${panel_conf}" << 'EOF'
# lxpanel <profile> config file
Global {
    edge=bottom
    allign=left
    margin=0
    widthtype=percent
    width=100
    height=26
    transparent=0
    tintcolor=#000000
    alpha=0
    setdocktype=1
    setpartialstrut=1
    usefontcolor=1
    fontcolor=#ffffff
    background=0
    backgroundfile=/usr/share/lxpanel/images/background.png
    iconsize=24
}
Plugin {
    type=space
    Config {
        Size=4
    }
}
Plugin {
    type=menu
    Config {
        image=/usr/share/lxpanel/images/my-computer.png
        system {
        }
        separator {
        }
        item {
            command=run
        }
        separator {
        }
        item {
            image=gnome-logout
            command=logout
        }
    }
}
Plugin {
    type=launchbar
    Config {
        Button {
            id=pcmanfm.desktop
        }
    }
}
Plugin {
    type=space
    Config {
        Size=4
    }
}
Plugin {
    type=taskbar
    expand=1
    Config {
        tooltips=1
        IconsOnly=0
        AcceptSkipPager=1
        ShowIconified=1
        ShowMapped=1
        ShowAllDesks=0
        UseMouseWheel=1
        UseUrgencyHint=1
        FlatButton=0
        MaxTaskWidth=200
        spacing=1
    }
}
Plugin {
    type=tray
}
Plugin {
    type=clock
    Config {
        ClockFmt=%R
        TooltipFmt=%A %x
        BoldFont=0
    }
}
EOF
        chroot_exec -u root chown -R ${USER_NAME}:${USER_NAME} "$(user_home ${USER_NAME})/.config/lxpanel"
    fi
    # fix error "No session for pid"
    if [ -e "${CHROOT_DIR}/etc/xdg/autostart/lxpolkit.desktop" ]; then
        rm "${CHROOT_DIR}/etc/xdg/autostart/lxpolkit.desktop"
    fi
    if [ -e "${CHROOT_DIR}/usr/bin/lxpolkit" ]; then
        mv "${CHROOT_DIR}/usr/bin/lxpolkit" "${CHROOT_DIR}/usr/bin/lxpolkit.bak"
    fi
    return 0
}
