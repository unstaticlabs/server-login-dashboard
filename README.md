# Server Login Dashboard

A compact, attention-oriented SSH login dashboard for Linux production servers.
Normal metrics stay quiet; exceptional conditions are highlighted, and update,
reboot, and concurrent-session messages appear only when action is required.

## What it shows

- A bold production warning and configurable stack name
- Host, time, OS/kernel, uptime, load, disk, memory, and swap
- Zombie processes and failed systemd units
- Public IPs and, when installed, Tailscale IPs
- The previous SSH key identity and source host
- Pending Ubuntu updates and reboot requirements, only when applicable
- Other active interactive SSH sessions, grouped by identity and host

The SSH identity is the comment attached to the matching public key in the
login user's `authorized_keys` file. Use meaningful key comments such as
`alice@work-laptop` for useful output.

## Install

```sh
git clone <repository-url> server-login-dashboard
cd server-login-dashboard
sudo ./install.sh
sudoedit /etc/server-login-dashboard.conf
```

The installer creates the configuration only if it does not already exist, so
future `git pull && sudo ./install.sh` upgrades preserve local server settings.

Ubuntu's standard MOTD is suppressed for root with `/root/.hushlogin`. Remove
that file if you want the distribution MOTD as well as this dashboard.

## Configure

Start with [`etc/server-login-dashboard.conf.example`](etc/server-login-dashboard.conf.example).
Each server needs only a short identity and threshold configuration:

```sh
SLD_ENVIRONMENT='PRODUCTION'
SLD_STACK='ODOO STACK'
SLD_ONLY_USER='root'
SLD_DISK_WARN_PERCENT=80
SLD_MEMORY_WARN_PERCENT=85
SLD_SWAP_WARN_PERCENT=50
SLD_TAILSCALE='auto'
```

Values are shell assignments loaded by the dashboard and the configuration
must therefore be writable only by root.

## Requirements

The core dashboard expects Linux `/proc`, `ip`, `ps`, `df`, `free`, `systemctl`,
`journalctl`, and OpenSSH. Tailscale and Ubuntu's `update-notifier-common` are
optional and detected automatically.

Previous-login and session attribution require permission to read the SSH
journal; the default root-only setup has that permission.

## Validate without logging in

```sh
sudo SLD_CONFIG=/etc/server-login-dashboard.conf ./bin/server-login-dashboard
```

Color is enabled automatically when standard output is a terminal.

## Uninstall

```sh
sudo ./uninstall.sh
```

The uninstaller deliberately preserves the local configuration and
`/root/.hushlogin`.
