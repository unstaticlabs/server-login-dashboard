# Server Login Dashboard

A compact, attention-oriented SSH login dashboard for Debian-family production
servers. Normal metrics stay quiet; exceptional conditions and actionable
notices appear only when attention is required.

## Documentation

- [`AGENTS.md`](AGENTS.md): self-contained context and safety rules for coding
  agents entering the repository with no prior project knowledge
- [`CONTRIBUTING.md`](CONTRIBUTING.md): development workflow, validation levels,
  and review checklist
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md): runtime flows, update
  transaction, configuration contract, tests, and trust boundaries

## What it shows

- A bold production warning and configurable stack name
- Host, OS/kernel, uptime, load, local disks, memory, swap, health, and IP addresses
- Resource metrics use yellow `WARNING` and red `ERROR` thresholds
- Previous SSH identity and other active interactive SSH sessions
- Pending OS package updates, review/apply commands, and reboot requirements
  only when applicable. The dashboard reports OS updates but does not install
  them; the server's separately configured unattended-upgrade policy is
  unaffected.
- One-time success or failure results from background dashboard updates

## Install

```sh
sudo git clone https://github.com/unstaticlabs/server-login-dashboard.git /opt/server-login-dashboard
cd /opt/server-login-dashboard
sudo ./install.sh
```

With an interactive terminal, the installer presents a management menu and
guides first-time configuration. Existing `/etc/server-login-dashboard.conf`
settings are never overwritten unless **Review configuration** is selected.

Direct commands are also available:

```sh
sudo ./install.sh install
sudo ./install.sh configure
sudo ./install.sh validate
sudo ./install.sh update
sudo ./install.sh status
sudo ./install.sh uninstall
sudo ./install.sh --non-interactive install
```

## Automatic updates

When `SLD_AUTO_UPDATE=1`, a systemd timer fetches `origin/main` once daily with
up to two hours of randomized delay. It never contacts GitHub during login.
Only clean, fast-forward updates are considered. A detached candidate is
validated before installation, and failed installations restore the previous
revision and deployed files.

**Trust warning:** servers tracking `main` automatically execute eligible
commits as root. Protect repository write access and branch administration as
production credentials.

Useful operations:

```sh
sudo systemctl list-timers server-login-dashboard-update.timer
sudo journalctl -u server-login-dashboard-update.service
sudo systemctl disable --now server-login-dashboard-update.timer
sudo ./install.sh update
sudo ./install.sh status
```

Transient network failures are logged but do not create login warnings.
Successful updates and actionable failures create a notice that is consumed by
the next interactive dashboard display.

## Configuration

Configuration lives at `/etc/server-login-dashboard.conf`. See
[`etc/server-login-dashboard.conf.example`](etc/server-login-dashboard.conf.example)
for all values. Existing configurations remain compatible; omitted update
settings receive these defaults:

```sh
SLD_AUTO_UPDATE=1
SLD_UPDATE_REPO='/opt/server-login-dashboard'
SLD_UPDATE_REMOTE='origin'
SLD_UPDATE_BRANCH='main'
SLD_UPDATE_STATE_DIR='/var/lib/server-login-dashboard'
```

The SSH identity is derived from the comment on the matching public key in the
login user's `authorized_keys`. Use meaningful comments such as
`alice@work-laptop`.

Resource severity defaults are:

| Metric | Warning (yellow) | Error (red) |
| --- | ---: | ---: |
| Load (1 minute) | 1× online CPUs | 2× online CPUs |
| Disk | 80% | 95% |
| Memory | 85% | 95% |
| Swap | 50% | 80% |

The disk row automatically reports root and each unique local device-backed
filesystem, excluding boot, loop, duplicate bind, and container overlay mounts.
Its severity reflects the fullest displayed filesystem. Disk, memory, and swap
limits are configurable in `/etc/server-login-dashboard.conf`. Missing error
settings retain the defaults above, so existing configurations remain compatible.

## Requirements and validation

Ubuntu or Debian with systemd, Git, procps, iproute2, util-linux, coreutils, and
OpenSSH client utilities are required. Tailscale and Ubuntu's
`update-notifier-common` are optional and detected automatically.

```sh
sudo ./install.sh validate
./tests/run.sh
```

Previous-login and session attribution require access to the SSH journal; the
default root-only setup has it. Ubuntu's standard MOTD is suppressed for root
with `/root/.hushlogin`.

## Recovery and uninstall

If an update is refused, inspect the checkout and service log, resolve local
changes or divergence, then run `sudo ./install.sh update`. The updater will
not discard local work.

Uninstalling removes the executable, profile hook, and timer. It deliberately
preserves `/etc/server-login-dashboard.conf`, update state, and `.hushlogin`.
