#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
  printf '%s\n' 'Run this installer as root.' >&2
  exit 1
fi

root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
install -m 0755 "$root/bin/server-login-dashboard" /usr/local/sbin/server-login-dashboard
install -m 0644 "$root/profile.d/server-login-dashboard.sh" /etc/profile.d/server-login-dashboard.sh

if [ ! -e /etc/server-login-dashboard.conf ]; then
  install -m 0644 "$root/etc/server-login-dashboard.conf.example" /etc/server-login-dashboard.conf
  printf '%s\n' 'Created /etc/server-login-dashboard.conf; customize it for this server.'
else
  printf '%s\n' 'Preserved existing /etc/server-login-dashboard.conf.'
fi

# Suppress Ubuntu's verbose dynamic MOTD for the configured root login.
touch /root/.hushlogin
printf '%s\n' 'Installed. Start a new interactive SSH session to verify it.'
