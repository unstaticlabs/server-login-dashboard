# Architecture

## Overview

Server Login Dashboard has two deliberately separate execution paths:

1. A read-only, local login path renders current host state.
2. A root-owned background path checks, validates, and installs repository updates.

The separation ensures an SSH login never waits for GitHub or changes system
state beyond atomically consuming a one-time update notice.

## Components

| Source | Installed location | Responsibility |
| --- | --- | --- |
| `bin/server-login-dashboard` | `/usr/local/sbin/server-login-dashboard` | Collect and render login information |
| `profile.d/server-login-dashboard.sh` | `/etc/profile.d/server-login-dashboard.sh` | Invoke the dashboard only for interactive shells |
| `bin/server-login-dashboard-update` | `/usr/local/sbin/server-login-dashboard-update` | Perform the guarded update transaction |
| `systemd/server-login-dashboard-update.*` | `/etc/systemd/system/` | Schedule daily background checks as root |
| `etc/server-login-dashboard.conf.example` | `/etc/server-login-dashboard.conf` | Define server-specific settings |
| `install.sh` | Not copied | Install, configure, validate, update, inspect, or uninstall |

Runtime state lives under `/var/lib/server-login-dashboard` by default. The Git
checkout defaults to `/opt/server-login-dashboard`. Both paths are configurable.

## Login path

The profile hook checks the shell's interactive flag before invoking the renderer.
The renderer then:

1. Loads configuration and backward-compatible defaults.
2. Exits unless the current user matches `SLD_ONLY_USER`.
3. Reads local kernel, process, filesystem, memory, networking, systemd, SSH
   journal, Tailscale, and APT metadata where available.
4. Maps accepted SSH key fingerprints to comments in `authorized_keys`.
5. Renders the production warning and compact metrics.
6. Atomically renames and reads `update-event`, so only one concurrent login can
   display that result.
7. Renders conditional OS-update, reboot, dashboard-update, and concurrent-session
   notice blocks.

The APT integration calls Ubuntu's local `apt-check` cache. It does not refresh
package indexes or install packages. Tailscale commands query the local daemon.
No login-time step performs an external network request or Git operation.

## Update transaction

The timer uses `OnCalendar=daily`, a two-hour randomized delay, and
`Persistent=true`. Its oneshot service runs the installed updater as root after
`network-online.target`.

The updater follows this transaction:

1. Acquire a nonblocking `flock` shared by scheduled and manual runs.
2. Verify the checkout and configured remote exist.
3. Refuse a checkout with tracked or untracked local changes.
4. Fetch the configured remote and branch. A network failure is logged as a
   transient no-op and does not create a login warning.
5. Return silently when already current; otherwise require the remote revision to
   descend from the installed revision.
6. Add the candidate revision as a detached temporary worktree.
7. Run package validation and package tests inside that worktree.
8. Back up deployed executables, profile hook, and systemd units.
9. Fast-forward the canonical checkout, reinstall noninteractively, and validate.
10. On failure, restore the old Git revision and deployed files. On success, record
    the installed revision.
11. Atomically write a success or actionable-failure event for one login to show.

The update event is a root-owned, pipe-delimited internal record:

```text
kind|old-short-revision|new-short-revision|message
```

It is not a durable audit log. Detailed history belongs in the systemd journal.

## Configuration contract

`/etc/server-login-dashboard.conf` is shell syntax sourced by the installed
commands. The installer owns the initial creation and explicit interactive
reconfiguration of this file. Routine installation and automatic updates preserve
it byte-for-byte.

Every shipped configuration key must have a safe default in the consuming script
so installations created by older releases remain valid. Inputs written by the
interactive configurator are single-quote escaped before being persisted.

## Test isolation

The tests redirect installation and state into temporary directories:

- `SLD_ROOT` prefixes deployed filesystem paths.
- `SLD_CONFIG` selects a fixture configuration.
- `SLD_STATE_DIR` and `SLD_UPDATE_LOCK_FILE` isolate updater state.
- `SLD_ALLOW_NON_ROOT`, `SLD_SKIP_PLATFORM_CHECK`, and `SLD_SKIP_SYSTEMD` disable
  only host-specific constraints in fixtures.

A temporary bare Git repository models the remote, while publisher and enrolled
clones exercise fast-forward updates and rollback without GitHub access.

## Security boundaries

The configured Git branch is a release channel, not merely source control. With
automatic updates enabled, an eligible commit can become root-executed code on
every enrolled server. Protect repository write access and branch rules as
production infrastructure.

The updater reduces accidental and operational failure; it does not provide
cryptographic release signing or defend against a compromised trusted remote.
Changes to `install.sh`, updater validation, CI, the tracked branch, or remote
configuration deserve security-sensitive review.
