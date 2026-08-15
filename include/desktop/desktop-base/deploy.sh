#!/bin/sh
# Linux Deploy Component
# (c) Anton Skshidlevsky <meefik@gmail.com>, GPLv3

do_configure()
{
    msg ":: Configuring ${COMPONENT} ... "
    local xinitrc="$(user_home ${USER_NAME})/.xinitrc"
    local xsession="$(user_home ${USER_NAME})/.xsession"
    local xinitrc_chroot="${CHROOT_DIR}${xinitrc}"
    local xsession_chroot="${CHROOT_DIR}${xsession}"
    # Workaround for Android kernels without a working close_range syscall:
    # preload a shim so GLib/dbus can spawn child processes. Using
    # /etc/ld.so.preload covers all processes (also sudo and ssh sessions),
    # since sudo strips the LD_PRELOAD environment variable.
    if [ -e "${ENV_DIR}/bin/close_range.so" ]; then
        [ -e "${CHROOT_DIR}/usr/local/lib" ] || mkdir -p "${CHROOT_DIR}/usr/local/lib"
        cp "${ENV_DIR}/bin/close_range.so" "${CHROOT_DIR}/usr/local/lib/close_range.so"
        chmod 644 "${CHROOT_DIR}/usr/local/lib/close_range.so"
        if ! grep -q "close_range.so" "${CHROOT_DIR}/etc/ld.so.preload" 2>/dev/null; then
            echo "/usr/local/lib/close_range.so" >> "${CHROOT_DIR}/etc/ld.so.preload"
        fi
    fi
    # Disable the glycin image loader sandbox: bwrap cannot create namespaces
    # inside a container, which breaks icon loading in GTK applications.
    # Replace it with a stub that fails with a recognized error, so glycin
    # falls back to running loaders without a sandbox.
    if [ -e "${CHROOT_DIR}/usr/bin/bwrap" ] && [ ! -e "${CHROOT_DIR}/usr/bin/bwrap.real" ]; then
        mv "${CHROOT_DIR}/usr/bin/bwrap" "${CHROOT_DIR}/usr/bin/bwrap.real"
        cat > "${CHROOT_DIR}/usr/bin/bwrap" << 'EOF'
#!/bin/sh
# stub: force glycin to run image loaders without a sandbox
echo "bwrap: setting up uid map: Permission denied" >&2
exit 1
EOF
        chmod 755 "${CHROOT_DIR}/usr/bin/bwrap"
    fi
    rm -f "${xinitrc_chroot}"
    echo 'XAUTHORITY=$HOME/.Xauthority' > "${xinitrc_chroot}"
    echo 'export XAUTHORITY' >> "${xinitrc_chroot}"
    echo "LANG=$LOCALE" >> "${xinitrc_chroot}"
    echo 'export LANG' >> "${xinitrc_chroot}"
    echo 'echo $$ > /tmp/xsession.pid' >> "${xinitrc_chroot}"
    echo '. $HOME/.xsession' >> "${xinitrc_chroot}"
    chmod 755 "${xinitrc_chroot}"
    chroot_exec -u root chown ${USER_NAME}:${USER_NAME} "${xinitrc}"
    touch "${xsession_chroot}"
    chmod 644 "${xsession_chroot}"
    chroot_exec -u root chown ${USER_NAME}:${USER_NAME} "${xsession}"
    return 0
}
