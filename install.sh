#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
prefix=${SLD_ROOT:-}
config=${SLD_CONFIG:-$prefix/etc/server-login-dashboard.conf}
noninteractive=0
command_name=''

for argument in "$@"; do
  case $argument in
    --non-interactive) noninteractive=1 ;;
    install|configure|validate|update|status|uninstall) command_name=$argument ;;
    *) printf 'Unknown argument: %s\n' "$argument" >&2; exit 2 ;;
  esac
done

if [ "$(id -u)" -ne 0 ] && [ "${SLD_ALLOW_NON_ROOT:-0}" != 1 ]; then
  printf '%s\n' 'Run this command as root.' >&2
  exit 1
fi

target() { printf '%s%s' "$prefix" "$1"; }
is_debian() {
  [ "${SLD_SKIP_PLATFORM_CHECK:-0}" = 1 ] && return 0
  os_release=$(target /etc/os-release)
  [ -r "$os_release" ] || os_release=/etc/os-release
  [ -r "$os_release" ] || return 1
  ID='' ID_LIKE=''
  # shellcheck disable=SC1090
  . "$os_release"
  [ "${ID:-}" = debian ] || [ "${ID:-}" = ubuntu ] || printf '%s' "${ID_LIKE:-}" | grep -qw debian
}
check_dependencies() {
  missing=''
  for item in git awk sed grep ps df free systemctl journalctl ssh-keygen flock mktemp install; do
    command -v "$item" >/dev/null 2>&1 || missing="$missing $item"
  done
  [ -z "$missing" ] && return 0
  printf 'Missing required commands:%s\n' "$missing" >&2
  if [ "$noninteractive" -eq 0 ] && [ -t 0 ]; then
    printf 'Install the required Debian packages now? [y/N] '
    read -r answer
    case $answer in
      y|Y|yes|YES) apt-get update && apt-get install -y git procps iproute2 openssh-client util-linux coreutils systemd ;;
      *) return 1 ;;
    esac
  else
    printf '%s\n' 'Install: git procps iproute2 openssh-client util-linux coreutils systemd' >&2
    return 1
  fi
}
load_defaults() {
  # shellcheck disable=SC1090
  [ -r "$config" ] && . "$config"
  : "${SLD_ENVIRONMENT:=PRODUCTION}"
  : "${SLD_STACK:=SERVER}"
  : "${SLD_WARNING:=Changes here may affect live users and data.}"
  : "${SLD_CONFIRMATION:=Confirm your target before running any command.}"
  : "${SLD_ONLY_USER:=root}"
  : "${SLD_DISK_WARN_PERCENT:=80}"
  : "${SLD_MEMORY_WARN_PERCENT:=85}"
  : "${SLD_SWAP_WARN_PERCENT:=50}"
  : "${SLD_TAILSCALE:=auto}"
  : "${SLD_APT_UPDATES:=auto}"
  : "${SLD_SSH_SERVICE:=ssh.service}"
  : "${SLD_AUTHORIZED_KEYS:=%h/.ssh/authorized_keys}"
  : "${SLD_AUTO_UPDATE:=1}"
  : "${SLD_UPDATE_REPO:=$root}"
  : "${SLD_UPDATE_REMOTE:=origin}"
  : "${SLD_UPDATE_BRANCH:=main}"
  : "${SLD_UPDATE_STATE_DIR:=/var/lib/server-login-dashboard}"
}
prompt_value() {
  label=$1 current=$2
  printf '%s [%s]: ' "$label" "$current"
  read -r prompt_result
  [ -n "$prompt_result" ] || prompt_result=$current
}
quote_value() {
  printf '%s' "$1" | sed "s/'/'\\\\''/g"
}
write_config() {
  mkdir -p "$(dirname -- "$config")"
  tmp="$config.$$"
  umask 022
  {
    printf "SLD_ENVIRONMENT='%s'\n" "$(quote_value "$SLD_ENVIRONMENT")"
    printf "SLD_STACK='%s'\n" "$(quote_value "$SLD_STACK")"
    printf "SLD_WARNING='%s'\n" "$(quote_value "$SLD_WARNING")"
    printf "SLD_CONFIRMATION='%s'\n" "$(quote_value "$SLD_CONFIRMATION")"
    printf "SLD_ONLY_USER='%s'\n" "$(quote_value "$SLD_ONLY_USER")"
    printf 'SLD_DISK_WARN_PERCENT=%s\n' "$SLD_DISK_WARN_PERCENT"
    printf 'SLD_MEMORY_WARN_PERCENT=%s\n' "$SLD_MEMORY_WARN_PERCENT"
    printf 'SLD_SWAP_WARN_PERCENT=%s\n' "$SLD_SWAP_WARN_PERCENT"
    printf "SLD_TAILSCALE='%s'\n" "$(quote_value "$SLD_TAILSCALE")"
    printf "SLD_APT_UPDATES='%s'\n" "$(quote_value "$SLD_APT_UPDATES")"
    printf "SLD_SSH_SERVICE='%s'\n" "$(quote_value "$SLD_SSH_SERVICE")"
    printf "SLD_AUTHORIZED_KEYS='%s'\n" "$(quote_value "$SLD_AUTHORIZED_KEYS")"
    printf 'SLD_AUTO_UPDATE=%s\n' "$SLD_AUTO_UPDATE"
    printf "SLD_UPDATE_REPO='%s'\n" "$(quote_value "$SLD_UPDATE_REPO")"
    printf "SLD_UPDATE_REMOTE='%s'\n" "$(quote_value "$SLD_UPDATE_REMOTE")"
    printf "SLD_UPDATE_BRANCH='%s'\n" "$(quote_value "$SLD_UPDATE_BRANCH")"
    printf "SLD_UPDATE_STATE_DIR='%s'\n" "$(quote_value "$SLD_UPDATE_STATE_DIR")"
  } > "$tmp"
  chmod 0644 "$tmp"
  mv -f "$tmp" "$config"
}
configure() {
  if [ "$noninteractive" -ne 0 ] || [ ! -t 0 ]; then
    printf '%s\n' 'Configuration requires an interactive terminal.' >&2
    exit 1
  fi
  load_defaults
  prompt_value 'Environment label' "$SLD_ENVIRONMENT"; SLD_ENVIRONMENT=$prompt_result
  prompt_value 'Stack label' "$SLD_STACK"; SLD_STACK=$prompt_result
  prompt_value 'Warning text' "$SLD_WARNING"; SLD_WARNING=$prompt_result
  prompt_value 'Confirmation text' "$SLD_CONFIRMATION"; SLD_CONFIRMATION=$prompt_result
  prompt_value 'Login user' "$SLD_ONLY_USER"; SLD_ONLY_USER=$prompt_result
  prompt_value 'Disk warning percent' "$SLD_DISK_WARN_PERCENT"; SLD_DISK_WARN_PERCENT=$prompt_result
  prompt_value 'Memory warning percent' "$SLD_MEMORY_WARN_PERCENT"; SLD_MEMORY_WARN_PERCENT=$prompt_result
  prompt_value 'Swap warning percent' "$SLD_SWAP_WARN_PERCENT"; SLD_SWAP_WARN_PERCENT=$prompt_result
  prompt_value 'Tailscale integration (auto/0/1)' "$SLD_TAILSCALE"; SLD_TAILSCALE=$prompt_result
  prompt_value 'APT update integration (auto/0/1)' "$SLD_APT_UPDATES"; SLD_APT_UPDATES=$prompt_result
  prompt_value 'SSH systemd service' "$SLD_SSH_SERVICE"; SLD_SSH_SERVICE=$prompt_result
  prompt_value 'Authorized keys path' "$SLD_AUTHORIZED_KEYS"; SLD_AUTHORIZED_KEYS=$prompt_result
  prompt_value 'Git checkout path' "$SLD_UPDATE_REPO"; SLD_UPDATE_REPO=$prompt_result
  prompt_value 'Git remote' "$SLD_UPDATE_REMOTE"; SLD_UPDATE_REMOTE=$prompt_result
  prompt_value 'Git branch' "$SLD_UPDATE_BRANCH"; SLD_UPDATE_BRANCH=$prompt_result
  prompt_value 'Automatic updates (0/1)' "$SLD_AUTO_UPDATE"; SLD_AUTO_UPDATE=$prompt_result
  write_config
  printf 'Saved %s.\n' "$config"
}
validate() {
  is_debian || { printf '%s\n' 'Only Debian-family systems are supported.' >&2; return 1; }
  check_dependencies
  [ -r "$config" ] || { printf 'Configuration not found: %s\n' "$config" >&2; return 1; }
  sh -n "$config"
  load_defaults
  case $SLD_AUTO_UPDATE in 0|1) ;; *) printf '%s\n' 'SLD_AUTO_UPDATE must be 0 or 1.' >&2; return 1;; esac
  for value in "$SLD_DISK_WARN_PERCENT" "$SLD_MEMORY_WARN_PERCENT" "$SLD_SWAP_WARN_PERCENT"; do
    case $value in ''|*[!0-9]*) printf '%s\n' 'Warning thresholds must be integers.' >&2; return 1;; esac
  done
  [ -d "$SLD_UPDATE_REPO/.git" ] || { printf 'Not a Git checkout: %s\n' "$SLD_UPDATE_REPO" >&2; return 1; }
  git -C "$SLD_UPDATE_REPO" remote get-url "$SLD_UPDATE_REMOTE" >/dev/null
  "$root/bin/server-login-dashboard-validate" "$root" >/dev/null
  if [ -z "$prefix" ] && [ -e "$config" ]; then
    owner=$(stat -c %u "$config")
    [ "$owner" -eq 0 ] || { printf '%s\n' 'Configuration must be owned by root.' >&2; return 1; }
  fi
  printf '%s\n' 'Installation validation passed.'
}
install_files() {
  is_debian || { printf '%s\n' 'Only Debian-family systems are supported.' >&2; exit 1; }
  check_dependencies
  if [ ! -e "$config" ]; then
    if [ "$noninteractive" -eq 0 ] && [ -t 0 ]; then configure
    else
      mkdir -p "$(dirname -- "$config")"
      install -m 0644 "$root/etc/server-login-dashboard.conf.example" "$config"
      sed "s|SLD_UPDATE_REPO='/opt/server-login-dashboard'|SLD_UPDATE_REPO='$root'|" "$config" > "$config.tmp"
      sed "s/^SLD_AUTO_UPDATE=1$/SLD_AUTO_UPDATE=0/" "$config.tmp" > "$config.tmp.auto"
      mv -f "$config.tmp.auto" "$config.tmp"
      mv -f "$config.tmp" "$config"
      printf 'Created %s with defaults.\n' "$config"
    fi
  else
    printf 'Preserved %s.\n' "$config"
  fi
  load_defaults
  install -D -m 0755 "$root/bin/server-login-dashboard" "$(target /usr/local/sbin/server-login-dashboard)"
  install -D -m 0755 "$root/bin/server-login-dashboard-update" "$(target /usr/local/sbin/server-login-dashboard-update)"
  install -D -m 0644 "$root/profile.d/server-login-dashboard.sh" "$(target /etc/profile.d/server-login-dashboard.sh)"
  install -D -m 0644 "$root/systemd/server-login-dashboard-update.service" "$(target /etc/systemd/system/server-login-dashboard-update.service)"
  install -D -m 0644 "$root/systemd/server-login-dashboard-update.timer" "$(target /etc/systemd/system/server-login-dashboard-update.timer)"
  mkdir -p "$(target "$SLD_UPDATE_STATE_DIR")"
  if [ -z "$prefix" ] && [ "${SLD_SKIP_SYSTEMD:-0}" != 1 ]; then
    systemctl daemon-reload
    if [ "$SLD_AUTO_UPDATE" = 1 ]; then systemctl enable --now server-login-dashboard-update.timer
    else systemctl disable --now server-login-dashboard-update.timer 2>/dev/null || true; fi
  fi
  if [ "$SLD_ONLY_USER" = root ]; then
    mkdir -p "$(target /root)"
    touch "$(target /root/.hushlogin)"
  fi
  validate
  printf '%s\n' 'Installed. Start a new interactive SSH session to verify it.'
}
status() {
  load_defaults
  printf 'Checkout: %s\nRemote:   %s/%s\n' "$SLD_UPDATE_REPO" "$SLD_UPDATE_REMOTE" "$SLD_UPDATE_BRANCH"
  if [ -d "$SLD_UPDATE_REPO/.git" ]; then
    printf 'Revision: %s\n' "$(git -C "$SLD_UPDATE_REPO" rev-parse --short HEAD)"
    git -C "$SLD_UPDATE_REPO" status --short --branch
  fi
  if [ -z "$prefix" ] && [ "${SLD_SKIP_SYSTEMD:-0}" != 1 ]; then systemctl status server-login-dashboard-update.timer --no-pager || true; fi
  event="${SLD_STATE_DIR:-$SLD_UPDATE_STATE_DIR}/update-event"
  [ ! -r "$event" ] || { printf '%s\n' 'Pending login notice:'; sed -n '1p' "$event"; }
}
uninstall_files() { "$root/uninstall.sh"; }
update_now() {
  load_defaults
  updater=$(target /usr/local/sbin/server-login-dashboard-update)
  [ -x "$updater" ] || updater="$root/bin/server-login-dashboard-update"
  "$updater" --manual
}
menu() {
  printf '%s\n' 'Server Login Dashboard' '  1) Install or refresh files' '  2) Review configuration' '  3) Validate installation' '  4) Check for updates now' '  5) Show status' '  6) Uninstall'
  printf 'Choose an action [1]: '
  read -r choice
  case ${choice:-1} in 1) install_files;; 2) configure;; 3) validate;; 4) update_now;; 5) status;; 6) uninstall_files;; *) printf '%s\n' 'Invalid choice.' >&2; exit 2;; esac
}

if [ -z "$command_name" ]; then
  if [ "$noninteractive" -eq 0 ] && [ -t 0 ]; then menu
  else printf '%s\n' 'Specify install, configure, validate, update, status, or uninstall.' >&2; exit 2; fi
else
  case $command_name in
    install) install_files;; configure) configure;; validate) validate;; update) update_now;; status) status;; uninstall) uninstall_files;;
  esac
fi
