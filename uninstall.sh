#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
  printf '%s\n' 'Run this uninstaller as root.' >&2
  exit 1
fi

rm -f /usr/local/sbin/server-login-dashboard /etc/profile.d/server-login-dashboard.sh
printf '%s\n' 'Removed dashboard code. Configuration and /root/.hushlogin were preserved.'
