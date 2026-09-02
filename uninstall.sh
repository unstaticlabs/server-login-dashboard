#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ] && [ "${SLD_ALLOW_NON_ROOT:-0}" != 1 ]; then
  printf '%s\n' 'Run this uninstaller as root.' >&2
  exit 1
fi

prefix=${SLD_ROOT:-}
if [ -z "$prefix" ] && [ "${SLD_SKIP_SYSTEMD:-0}" != 1 ]; then
  systemctl disable --now server-login-dashboard-update.timer 2>/dev/null || true
fi
rm -f "$prefix/usr/local/sbin/server-login-dashboard" \
  "$prefix/usr/local/sbin/server-login-dashboard-update" \
  "$prefix/etc/profile.d/server-login-dashboard.sh" \
  "$prefix/etc/systemd/system/server-login-dashboard-update.service" \
  "$prefix/etc/systemd/system/server-login-dashboard-update.timer"
if [ -z "$prefix" ] && [ "${SLD_SKIP_SYSTEMD:-0}" != 1 ]; then systemctl daemon-reload; fi
printf '%s\n' 'Removed dashboard code and timer. Configuration, state, and .hushlogin were preserved.'
