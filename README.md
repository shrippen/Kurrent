<p align="center">
  <img src="icons/kurrent-mark.png" width="128" height="128" alt="Kurrent">
</p>

<h1 align="center">Kurrent</h1>

<p align="center">
  A KDE Plasma 6 task manager plasmoid powered by <strong>Akonadi</strong> and Nextcloud CalDAV.
</p>

<p align="center">
  <a href="https://github.com/shrippen/Kurrent/releases/tag/v0.1.0"><img alt="Version" src="https://img.shields.io/badge/version-0.1.0-e8dcc4?labelColor=1c1c20"></a>
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

From source (widget + Akonadi QML plugin):

```bash
./install.sh
```

Then add the **Kurrent** widget to your panel or desktop.

Each GitHub Release includes a `.plasmoid` package for the [KDE Store](https://store.kde.org/) and for installing the widget UI with:

```bash
kpackagetool6 -t Plasma/Applet -i com.github.shrippen.kurrent-0.1.0.plasmoid
```

The Akonadi backend is a compiled QML plugin. The `.plasmoid` contains the widget, translations, and metadata; full task access still needs `./install.sh` (or a distro package) so the plugin is on the QML import path.

## Features

- Panel and desktop widget (compact icon + full view)
- Reads todos from existing Akonadi collections
- Views: Inbox, Today, Tomorrow, Scheduled, Anytime, Recurring, Unlabeled, Completed
- Create, edit, complete, and delete tasks; subtasks, labels, and priorities
- Shared configuration between desktop and panel instances
- Optional blurred wallpaper background via Plasma
- Manual sync via toolbar button

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
