# Agent guide

## Mission and trust model

This repository installs a compact dashboard in interactive SSH login shells on
Debian-family production servers. It also installs a root-owned systemd updater.
The project is intentionally dependency-light and implemented in POSIX shell.

Treat every change as production-sensitive. Enrolled servers may fast-forward
from `origin/main` and execute the resulting installer as root. A harmless-looking
change to tests, installation, configuration, or update behavior can therefore
affect live hosts.

## Start here

An agent should be able to work from this repository alone. Before editing:

1. Run `git status --short --branch`; preserve unrelated work.
2. Read `README.md`, `docs/ARCHITECTURE.md`, and the relevant scripts.
3. Read `etc/server-login-dashboard.conf.example` before changing configuration.
4. Inspect `.github/workflows/test.yml` and `tests/run.sh` before changing tests or
   validation behavior.

Do not assume access to any enrolled server, private network, SSH alias, secret,
or external deployment system. Never add real host addresses, credentials, SSH
keys, user identities, or production output to the repository.

## Repository map

- `bin/server-login-dashboard`: read-only login-time data collection and output.
- `bin/server-login-dashboard-update`: locked, defensive Git update transaction.
- `bin/server-login-dashboard-validate`: package structure and syntax checks.
- `install.sh`: interactive management command and noninteractive installer.
- `uninstall.sh`: removes deployed code while preserving configuration and state.
- `etc/server-login-dashboard.conf.example`: documented configuration contract.
- `profile.d/server-login-dashboard.sh`: interactive-shell entry point.
- `systemd/`: daily root updater service and timer.
- `tests/run.sh`: package, installation, event, locking, update, and rollback tests.
- `.github/workflows/test.yml`: Ubuntu and Debian CI definition.

## Non-negotiable behavior

- Noninteractive SSH must produce no dashboard output.
- Login rendering must not perform Git operations or network requests.
- Normal conditions stay compact; actionable conditions receive visual emphasis.
- Multiple notices are separate blocks. One-time update events are consumed once.
- Existing `/etc/server-login-dashboard.conf` is preserved unless configuration is
  explicitly reviewed.
- Missing configuration keys retain backward-compatible defaults.
- Automatic updates accept only a clean, fast-forward checkout.
- Candidates are validated in a temporary worktree before the canonical checkout
  moves.
- Scheduled and manual updates share a nonblocking `flock` lock.
- Transient network failure is logged and silent at login. Local changes,
  divergence, validation failure, and installation failure are actionable.
- Installation failure restores both the previous Git revision and deployed files.
- Uninstall preserves configuration, update state, and `.hushlogin` by design.

If a requested change conflicts with one of these properties, call it out rather
than silently weakening it.

## Shell conventions

- Write portable `/bin/sh`; do not add Bash syntax such as arrays, `[[ ... ]]`, or
  process substitution.
- Keep scripts compatible with `set -eu`. Quote expansions unless intentional word
  splitting is evident and safe.
- Prefer standard Debian/Ubuntu utilities already listed in `install.sh`. Do not add
  a required package, network call, or daemon without updating validation,
  installation guidance, tests, and documentation.
- Keep login work bounded and local. Avoid slow commands and suppress expected
  failures where a metric is optional.
- Use temporary files plus atomic `mv` for state consumed by another process.
- Preserve test seams (`SLD_ROOT`, `SLD_CONFIG`, `SLD_STATE_DIR`, and the explicit
  skip/allow variables); they keep tests isolated from the host.
- Update `etc/server-login-dashboard.conf.example`, `load_defaults`, configuration
  writing/prompts, and README documentation together when adding a public setting.

## Validation

For documentation-only changes, run at least:

```sh
./tests/run.sh package
```

For shell, installer, updater, configuration, or systemd changes, run the complete
Linux checks described in `CONTRIBUTING.md` and represented by CI:

```sh
shellcheck -s sh install.sh uninstall.sh bin/server-login-dashboard \
  bin/server-login-dashboard-update bin/server-login-dashboard-validate \
  profile.d/server-login-dashboard.sh tests/run.sh
./tests/run.sh
```

Also run `systemd-analyze verify` when either systemd unit changes. Add or update a
test for behavior changes. macOS lacks several required Linux commands, so use an
Ubuntu or Debian container for the full suite rather than weakening platform
checks.

## Change and release safety

- Do not push, merge, publish a release, run an installer, or connect to a server
  unless the user explicitly asks for that external action.
- Keep commits focused and explain user-visible behavior in `README.md`.
- Review diffs for leaked operational data and for changes that could execute as
  root.
- Do not rewrite, discard, or clean a dirty checkout to make the updater pass.
- Before declaring a production-affecting change ready, ensure the Ubuntu and
  Debian test paths pass and the working tree contains only intended changes.

## Code review rules

Flag changes that introduce login-time networking, noninteractive output,
configuration overwrite, unsafe Git reconciliation, an update race, loss of
rollback coverage, secrets, or unvalidated root execution. Suggest the safe path
described by the invariants above, not merely the problem.
