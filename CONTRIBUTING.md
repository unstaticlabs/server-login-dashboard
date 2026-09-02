# Contributing

This is a small shell project with an unusually sensitive deployment model:
enrolled servers can execute eligible commits from `main` as root. Keep changes
focused, reviewable, and covered by the same checks used in CI.

## Development environment

The runtime targets Ubuntu and Debian with systemd. Required commands are listed
by `install.sh`; development additionally uses Git and ShellCheck. macOS can run
package-level syntax checks, but the full test suite requires Linux utilities such
as `free`, `systemctl`, `journalctl`, and `flock`.

Start with:

```sh
git status --short --branch
./tests/run.sh package
```

## Validation levels

Run ShellCheck after changing any shell file:

```sh
shellcheck -s sh install.sh uninstall.sh \
  bin/server-login-dashboard bin/server-login-dashboard-update \
  bin/server-login-dashboard-validate profile.d/server-login-dashboard.sh \
  tests/run.sh
```

Run the full behavioral suite on Ubuntu or Debian:

```sh
./tests/run.sh
```

It exercises repeat installation, configuration preservation, one-time notices,
update no-ops, lock contention, clean fast-forward updates, dirty-checkout
refusal, validation failure, and rollback. CI runs it in both `ubuntu:latest` and
`debian:stable`; `.github/workflows/test.yml` is the canonical environment recipe.

When changing a systemd unit, also run:

```sh
sudo install -m 0755 bin/server-login-dashboard-update \
  /usr/local/sbin/server-login-dashboard-update
systemd-analyze verify systemd/server-login-dashboard-update.service \
  systemd/server-login-dashboard-update.timer
```

Use a disposable container or VM for that command if installing the validation
stub on the development host is undesirable.

## Making changes

- Dashboard output: preserve a quiet success path, keep warnings concise, and test
  exact user-facing text or layout where it matters.
- Configuration: add a safe default so old configuration files remain valid, then
  update the example, interactive prompt/writer, validation, and documentation.
- Installer: test first install and repeat install. A repeat install must not alter
  the configuration checksum.
- Updater: cover both the successful transaction and every new refusal or rollback
  path. Never solve divergence by resetting user work.
- Systemd: keep checks out of SSH login and preserve daily randomized, persistent
  scheduling unless a deliberate behavior change is documented.

Do not commit real server identifiers, addresses, SSH output, credentials, or
configuration copied from `/etc`.

## Review checklist

- The code remains POSIX `/bin/sh` and passes ShellCheck.
- Changed behavior has a regression test.
- Login performs no network or Git operation.
- Noninteractive SSH remains silent.
- Existing configuration remains valid and preserved.
- Update locking, validation, fast-forward-only behavior, and rollback still hold.
- README and architecture documentation match user-visible behavior.
- The diff contains no secrets or production-specific data.

Do not deploy from a contributor checkout. Installation, pushing to `main`, and
production verification are separate, explicitly authorized operational actions.
