#!/bin/sh
set -eu

mode=${1:-all}
tree=${2:-$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)}

package_tests() {
  "$tree/bin/server-login-dashboard-validate" "$tree" >/dev/null
  grep -q "SLD_AUTO_UPDATE=1" "$tree/etc/server-login-dashboard.conf.example"
  grep -q 'SLD_DISK_ERROR_PERCENT=95' "$tree/etc/server-login-dashboard.conf.example"
  grep -q 'server-login-dashboard-update.timer' "$tree/install.sh"
  printf '%s\n' 'Package tests passed.'
}

[ "$mode" = package ] && { package_tests; exit 0; }
package_tests

fixture=$(mktemp -d "${TMPDIR:-/tmp}/sld-tests.XXXXXX")
trap 'rm -rf "$fixture"' EXIT HUP INT TERM
rootfs="$fixture/root"
mkdir -p "$rootfs/etc" "$rootfs/opt"
printf 'ID=debian\n' > "$rootfs/etc/os-release"

SLD_ROOT="$rootfs" SLD_CONFIG="$rootfs/etc/server-login-dashboard.conf" SLD_ALLOW_NON_ROOT=1 SLD_SKIP_PLATFORM_CHECK=1 SLD_SKIP_SYSTEMD=1 \
  "$tree/install.sh" --non-interactive install >/dev/null
test -x "$rootfs/usr/local/sbin/server-login-dashboard"
test -x "$rootfs/usr/local/sbin/server-login-dashboard-update"
test -f "$rootfs/etc/systemd/system/server-login-dashboard-update.timer"
checksum=$(cksum "$rootfs/etc/server-login-dashboard.conf")
SLD_ROOT="$rootfs" SLD_CONFIG="$rootfs/etc/server-login-dashboard.conf" SLD_ALLOW_NON_ROOT=1 SLD_SKIP_PLATFORM_CHECK=1 SLD_SKIP_SYSTEMD=1 \
  "$tree/install.sh" --non-interactive install >/dev/null
test "$checksum" = "$(cksum "$rootfs/etc/server-login-dashboard.conf")"

state="$fixture/state"
mkdir -p "$state"
printf 'success|abc1234|def5678|installed\n' > "$state/update-event"
apt_check="$fixture/apt-check"
printf '#!/bin/sh\nprintf "1;0\\n"\n' > "$apt_check"
chmod +x "$apt_check"
dashboard_output=$(SLD_STATE_DIR="$state" SLD_CONFIG="$rootfs/etc/server-login-dashboard.conf" SLD_ONLY_USER='' \
  SLD_APT_UPDATES=1 _SLD_APT_CHECK_COMMAND="$apt_check" "$tree/bin/server-login-dashboard")
test ! -e "$state/update-event"
printf '%s\n' "$dashboard_output" | grep -q 'NOTICE: 1 OS PACKAGE UPDATE PENDING'
printf '%s\n' "$dashboard_output" | grep -q 'Review: apt list --upgradable'
printf '%s\n' "$dashboard_output" | grep -q 'Apply:  sudo apt update && sudo apt upgrade'
printf '%s\n' "$dashboard_output" | awk '
  /Apply:  sudo apt update && sudo apt upgrade/ { update_end=NR }
  /INFO: LOGIN DASHBOARD UPDATED/ { if (NR != update_end + 2) exit 1; found=1 }
  END { if (!found) exit 1 }
'

# Resource rows use yellow WARNING and red ERROR levels in a terminal.
color_config="$fixture/color.conf"
{
  printf "SLD_ONLY_USER=''\n"
  printf 'SLD_DISK_WARN_PERCENT=0\n'
  printf 'SLD_DISK_ERROR_PERCENT=101\n'
  printf 'SLD_MEMORY_WARN_PERCENT=0\n'
  printf 'SLD_MEMORY_ERROR_PERCENT=101\n'
  printf 'SLD_SWAP_WARN_PERCENT=0\n'
  printf 'SLD_SWAP_ERROR_PERCENT=101\n'
  printf "SLD_TAILSCALE='0'\n"
  printf "SLD_APT_UPDATES='0'\n"
} > "$color_config"
color_output=$(script -qec "SLD_CONFIG='$color_config' '$tree/bin/server-login-dashboard'" /dev/null)
red=$(printf '\033[1;31m')
yellow=$(printf '\033[1;33m')
for label in 'Disk /' Memory Swap; do
  printf '%s\n' "$color_output" | grep -F "$label" | grep -F "$yellow" | grep -F WARNING >/dev/null
done

sed 's/ERROR_PERCENT=101/ERROR_PERCENT=0/' "$color_config" > "$color_config.error"
color_output=$(script -qec "SLD_CONFIG='$color_config.error' '$tree/bin/server-login-dashboard'" /dev/null)
for label in 'Disk /' Memory Swap; do
  printf '%s\n' "$color_output" | grep -F "$label" | grep -F "$red" | grep -F ERROR >/dev/null
done

printf '%s\n' 'Installation, dashboard color, and one-time notice tests passed.'

# Exercise the updater against a local bare remote.
remote="$fixture/remote.git"
enrolled="$fixture/enrolled"
publisher="$fixture/publisher"
git clone --quiet --bare "$tree" "$remote"
git clone --quiet "$remote" "$enrolled"
git clone --quiet "$remote" "$publisher"
git -C "$publisher" config user.name 'Dashboard tests'
git -C "$publisher" config user.email 'dashboard-tests@example.invalid'
update_root="$fixture/update-root"
update_state="$fixture/update-state"
update_config="$fixture/update.conf"
mkdir -p "$update_root/etc" "$update_state"
{
  printf "SLD_ONLY_USER=''\n"
  printf 'SLD_AUTO_UPDATE=1\n'
  printf "SLD_UPDATE_REPO='%s'\n" "$enrolled"
  printf "SLD_UPDATE_REMOTE='origin'\n"
  printf "SLD_UPDATE_BRANCH='main'\n"
  printf "SLD_UPDATE_STATE_DIR='%s'\n" "$update_state"
} > "$update_config"
run_update() {
  env SLD_ROOT="$update_root" SLD_CONFIG="$update_config" SLD_STATE_DIR="$update_state" \
    SLD_UPDATE_LOCK_FILE="$fixture/update.lock" SLD_ALLOW_NON_ROOT=1 \
    SLD_SKIP_PLATFORM_CHECK=1 SLD_SKIP_SYSTEMD=1 \
    "$enrolled/bin/server-login-dashboard-update" --manual
}

# A current checkout is a silent no-op.
run_update >/dev/null
test ! -e "$update_state/update-event"

# Lock contention exits successfully without fetching or creating an event.
flock "$fixture/update.lock" sleep 2 &
lock_pid=$!
run_update >/dev/null
wait "$lock_pid"
test ! -e "$update_state/update-event"

# A fast-forward commit is validated, installed, and recorded.
printf '\nUpdater test.\n' >> "$publisher/README.md"
git -C "$publisher" add README.md
git -C "$publisher" commit --quiet -m 'Test successful update'
git -C "$publisher" push --quiet origin main
old_revision=$(git -C "$enrolled" rev-parse HEAD)
run_update >/dev/null
test "$old_revision" != "$(git -C "$enrolled" rev-parse HEAD)"
grep -q '^success|' "$update_state/update-event"
rm -f "$update_state/update-event"

# A dirty checkout is refused and produces an actionable event.
printf 'dirty\n' > "$enrolled/local-change"
if run_update >/dev/null 2>&1; then exit 1; fi
grep -q '^failure|' "$update_state/update-event"
rm -f "$enrolled/local-change" "$update_state/update-event"

# A syntactically valid candidate whose installer fails is rolled back.
sed '2i exit 42' "$publisher/install.sh" > "$publisher/install.sh.new"
mv "$publisher/install.sh.new" "$publisher/install.sh"
chmod +x "$publisher/install.sh"
git -C "$publisher" add install.sh
git -C "$publisher" commit --quiet -m 'Test rollback'
git -C "$publisher" push --quiet origin main
rollback_revision=$(git -C "$enrolled" rev-parse HEAD)
if run_update >/dev/null 2>&1; then exit 1; fi
test "$rollback_revision" = "$(git -C "$enrolled" rev-parse HEAD)"
grep -q '^failure|' "$update_state/update-event"

printf '%s\n' 'Updater no-op, lock, fast-forward, dirty-checkout, and rollback tests passed.'
