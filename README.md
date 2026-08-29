> **Note:** This is completely vibe coded from start to finish. This is simply something I wanted for myself but might as well share here.

<p align="center">
  <img src="icons/kurrent-mark.png" width="128" height="128" alt="Kurrent">
</p>

<h1 align="center">Kurrent</h1>

<p align="center">
  A KDE Plasma 6 task manager plasmoid powered by <strong>Akonadi</strong> and Nextcloud CalDAV.
</p>

<p align="center">
  <a href="https://github.com/shrippen/Kurrent/releases/tag/v0.3.1"><img alt="Version" src="https://img.shields.io/badge/version-0.3.1-e8dcc4?labelColor=1c1c20"></a>
  <img alt="Plasma 6" src="https://img.shields.io/badge/Plasma-6-3daee9?labelColor=1c1c20">
  <img alt="License" src="https://img.shields.io/badge/license-GPL--3.0--or--later-lightgrey?labelColor=1c1c20">
</p>

Inbox, Today, Scheduled, Projects, and Labels with a native Plasma / Kirigami UI. No separate CalDAV login — Kurrent uses your existing KDE PIM setup.

## Prerequisites

- KDE Plasma 6
- Akonadi running with a configured DAV groupware resource (KOrganizer or Merkuro)
- Build dependencies on Arch Linux:

```bash
sudo pacman -S cmake extra-cmake-modules qt6-declarative \
    kcalendarcore akonadi akonadi-calendar kirigami plasma-workspace
```

## Setup CalDAV / Nextcloud

Configure your account in **KOrganizer** or **Merkuro**:

1. Add Calendar → **DAV groupware resource**
2. Choose **Nextcloud**, enter server URL, username, and app password
3. Enable task (VTODO) collections

Verify Akonadi is running:

```bash
akonadictl status
```

## Install

Until AUR and COPR packages exist, the supported install is this one-liner. It downloads the prebuilt plugin from the latest GitHub Release (plus the `.plasmoid` UI) into `~/.local`:

```bash
curl -fsSL https://github.com/shrippen/Kurrent/releases/latest/download/install-linux.sh | sudo bash
```

`sudo` is only for distro packages. The widget is installed as your user (`SUDO_USER`). Without sudo, use `bash <(curl -fsSL https://github.com/shrippen/Kurrent/releases/latest/download/install-linux.sh)` so a password prompt can use the terminal. Pin a release with `| bash -s -- --tag v0.3`. Compile instead of using the Arch-built `.so`: `| bash -s -- --from-source`.

The installer checks for **Plasma 6 / Qt 6 / KF6** before proceeding and exits if the desktop stack is too old. Package lists cover Arch, Fedora/RHEL, Debian/Ubuntu, and openSUSE; on other distros you get a warning and an interactive **Continue anyway?** prompt (skipped in CI or without a TTY).

### Immutable / atomic distros (Silverblue, Kinoite, MicroOS, …)

The one-liner uses the host package manager (`dnf`, `apt`, …). On **rpm-ostree** (Fedora Silverblue, Kinoite, Universal Blue, …) and **transactional** systems (openSUSE MicroOS, Aeon), that does not modify the running root — plain `sudo dnf install` inside the script will usually fail.

**Fedora Atomic:** layer dependencies with `rpm-ostree install …`, reboot, then re-run with `--no-deps` (add `--from-source` for a local build). Or run the installer inside **Toolbx/Distrobox**. Example runtime layer:

```bash
rpm-ostree install plasma-workspace kf6-kcalendarcore kf6-ki18n kf6-kconfig \
  kf6-knotifications kf6-kglobalaccel kf6-kirigami akonadi-server akonadi-calendar
# reboot, then:
curl -fsSL https://github.com/shrippen/Kurrent/releases/latest/download/install-linux.sh | bash -s -- --no-deps
```

**openSUSE MicroOS:** use `transactional-update pkg install …`, reboot, then `--no-deps` — or build inside Distrobox/Podman.

Kurrent itself installs under `~/.local`, which persists across reboots and container workflows. The installer detects immutable systems and prints these hints before asking **Continue on this immutable system anyway?**

From a git checkout (widget + Akonadi QML plugin):

```bash
./install.sh
```

Then add the **Kurrent** widget to your panel or desktop.

Each GitHub Release includes:

- a `.plasmoid` zip for the [KDE Store](https://store.kde.org/) (widget UI only)
- `kurrent-linux-x86_64.tar.gz` — compiled Akonadi QML plugin + plasmoid for `~/.local` (built on Arch Linux)
- `install-linux.sh` — the one-liner above

```bash
kpackagetool6 -t Plasma/Applet -i com.github.shrippen.kurrent-0.3.plasmoid
```

The Akonadi backend is a compiled QML plugin. The `.plasmoid` from the KDE Store is only the widget UI — if you install that alone, Kurrent shows how to get the plugin instead of a QML error. Full task access needs the one-liner, `./install.sh`, or a distro package so `libkurrentplugin.so` is on the QML import path. The prebuilt tarball is linked against Arch’s Plasma 6 / KDE PIM; on other distros the installer falls back to compiling from source.

## Features

- Panel and desktop widget (compact icon + full view)
- Reads todos from existing Akonadi collections
- Views: Inbox, Today, Tomorrow, Scheduled, Anytime, Recurring, Unlabeled, Completed
- Create, edit, complete, and delete tasks; subtasks, labels, and priorities
- Shared configuration between desktop and panel instances
- Optional blurred wallpaper background via Plasma
- Manual sync via toolbar button

## Roadmap

See [ROADMAP.md](ROADMAP.md) for the remaining path to 1.0 (AUR + COPR, then OBS / Debian if cheap, and the rest of the 0.3/0.4 catalog).

## Configuration

Right-click the widget → **Configure Kurrent**:

- Default view, completed tasks, appearance (blur)
- Sidebar row size and default project for new tasks
- Which calendars/projects and labels are enabled or hidden

Settings are stored in `~/.config/com.github.shrippen.kurrent/kurrentrc` and apply to every Kurrent instance.

## Development

```bash
cmake -S . -B build -DCMAKE_INSTALL_PREFIX=$HOME/.local \
    -DKDE_INSTALL_USE_QT_SYS_PATHS=ON -DKURRENT_DEV_BUILD=ON
cmake --build build
cmake --install build
kpackagetool6 -t Plasma/Applet -i plasmoid/com.github.shrippen.kurrent
```

`./install.sh` keeps the developer build label (`Build N`) on. Release builds default `KURRENT_DEV_BUILD` to off.

Regenerate translations after UI string changes:

```bash
python3 po/generate_po.py
```

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).
