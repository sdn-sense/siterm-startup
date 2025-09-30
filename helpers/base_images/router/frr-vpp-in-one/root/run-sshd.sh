#!/bin/bash
if [ -z "$SSH_PORT" ]; then
    echo "ERROR: SSH_PORT is not set!"
    exit 1
fi

SSHD_CONFIG="/etc/ssh/sshd_config"

if grep -q "^Port" $SSHD_CONFIG; then
    sed -i "s/^Port.*/Port ${SSH_PORT}/" $SSHD_CONFIG
else
    echo "Port ${SSH_PORT}" >> $SSHD_CONFIG
fi

# If neither SSH_LISTEN_ADDRESS nor SSH_LISTEN6_ADDRESS is set, do nothing
if [ -z "$SSH_LISTEN_ADDRESS" ] && [ -z "$SSH_LISTEN6_ADDRESS" ]; then
    echo "No SSH_LISTEN_ADDRESS or SSH_LISTEN6_ADDRESS set, will not start sshd."
    exit 0
fi

# if SSH_LISTEN_ADDRESS is set, add ListenAddress
if [ -n "$SSH_LISTEN_ADDRESS" ]; then
    echo "ListenAddress $SSH_LISTEN_ADDRESS" >> $SSHD_CONFIG
fi
# if SSH_LISTEN6_ADDRESS is set, add ListenAddress
if [ -n "$SSH_LISTEN6_ADDRESS" ]; then
    echo "ListenAddress $SSH_LISTEN6_ADDRESS" >> $SSHD_CONFIG
fi

sed -i "s/^#PasswordAuthentication.*/PasswordAuthentication no/" $SSHD_CONFIG || true
sed -i "s/^PasswordAuthentication.*/PasswordAuthentication no/" $SSHD_CONFIG || true
sed -i "s/^#PermitRootLogin.*/PermitRootLogin prohibit-password/" $SSHD_CONFIG || true
sed -i "s/^#X11Forwarding.*/X11Forwarding no/" $SSHD_CONFIG || true
sed -i "s/^X11Forwarding.*/X11Forwarding no/" $SSHD_CONFIG || true
sed -i "s/^#LogLevel.*/LogLevel VERBOSE/" $SSHD_CONFIG || true

ssh-keygen -A

exec /usr/sbin/sshd -D -e